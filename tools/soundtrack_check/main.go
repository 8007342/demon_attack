// soundtrack_check measures and cuts generated music takes for the adaptive
// soundtrack (openspec/changes/adaptive-soundtrack, design §7).
//
// It needs only ffmpeg (decode, EBU R128 scan). Everything else is plain Go:
// an onset envelope (spectral flux, 10 ms hop), a tempo fit near the asked
// tempo, a downbeat phase, a Krumhansl-Schmuckler key estimate from a chroma
// profile, the energy share above 12 and 16 kHz, and a bar-aligned window
// pick for loops (the bar after the window must sound like its first bar),
// bridges (rising energy into a strong downbeat) and tails.
//
//	soundtrack_check analyze -bar 60632 -key "F minor" take.flac        # JSON on stdout
//	soundtrack_check cut -bar 60632 -bars 8 -kind loop -out x.wav take.flac
//	soundtrack_check check -bar 60632 -loop x.wav       # seam, clicks, clipping
//
// cut resamples the take onto the exact grid (speed, at most a few tenths
// of a percent), picks the window and writes 48 kHz stereo 16-bit WAV. A
// loop's first 120 ms crossfade from the audio that really followed its
// last bar, so the wrap is the take's own continuation.
package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"math/cmplx"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

const sr = 48000

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: soundtrack_check analyze|cut [flags] file")
		os.Exit(2)
	}
	cmd := os.Args[1]
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	bar := fs.Int("bar", 60632, "samples per 4/4 bar at 48 kHz")
	key := fs.String("key", "", "expected key, e.g. \"F minor\"")
	bars := fs.Int("bars", 8, "window length in bars (cut)")
	kind := fs.String("kind", "loop", "loop | bridge | tail (cut)")
	out := fs.String("out", "", "output WAV (cut)")
	startBar := fs.Int("start", -1, "force the window's first bar (cut)")
	loop := fs.Bool("loop", false, "check the loop wrap (check)")
	fs.Parse(os.Args[2:])
	if fs.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "one input file")
		os.Exit(2)
	}
	in := fs.Arg(0)
	switch cmd {
	case "analyze":
		r := analyze(in, *bar, *key)
		emit(r)
	case "cut":
		if *out == "" {
			fmt.Fprintln(os.Stderr, "-out required")
			os.Exit(2)
		}
		r := cut(in, *bar, *bars, *kind, *out, *startBar)
		emit(r)
	case "check":
		emit(check(in, *bar, *loop))
	default:
		fmt.Fprintln(os.Stderr, "unknown command", cmd)
		os.Exit(2)
	}
}

func emit(v any) {
	b, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(b))
}

// ---- decoding -------------------------------------------------------------

func decode(path string, rate float64) (l, r []float64) {
	args := []string{"-v", "error", "-i", path}
	if math.Abs(rate-1) > 1e-6 {
		// Speed change by resampling: at most a few tenths of a percent,
		// so the pitch moves by a few cents at most.
		args = append(args, "-af", fmt.Sprintf("asetrate=%.4f,aresample=%d:filter_size=64:phase_shift=10:cutoff=0.97", sr*rate, sr))
	}
	args = append(args, "-f", "f32le", "-ac", "2", "-ar", strconv.Itoa(sr), "-")
	cmd := exec.Command("ffmpeg", args...)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "ffmpeg:", err)
		os.Exit(1)
	}
	n := buf.Len() / 8
	l = make([]float64, n)
	r = make([]float64, n)
	raw := buf.Bytes()
	for i := 0; i < n; i++ {
		l[i] = float64(math.Float32frombits(binary.LittleEndian.Uint32(raw[i*8:])))
		r[i] = float64(math.Float32frombits(binary.LittleEndian.Uint32(raw[i*8+4:])))
	}
	return
}

func mono(l, r []float64) []float64 {
	m := make([]float64, len(l))
	for i := range l {
		m[i] = 0.5 * (l[i] + r[i])
	}
	return m
}

// ---- FFT ------------------------------------------------------------------

func fft(a []complex128) {
	n := len(a)
	for i, j := 1, 0; i < n; i++ {
		bit := n >> 1
		for ; j&bit != 0; bit >>= 1 {
			j ^= bit
		}
		j ^= bit
		if i < j {
			a[i], a[j] = a[j], a[i]
		}
	}
	for size := 2; size <= n; size <<= 1 {
		w := cmplx.Exp(complex(0, -2*math.Pi/float64(size)))
		for start := 0; start < n; start += size {
			wk := complex(1, 0)
			for k := 0; k < size/2; k++ {
				u := a[start+k]
				v := a[start+k+size/2] * wk
				a[start+k] = u + v
				a[start+k+size/2] = u - v
				wk *= w
			}
		}
	}
}

// spectra returns magnitude spectra of hann-windowed frames.
func spectra(x []float64, size, hop int) [][]float64 {
	win := make([]float64, size)
	for i := range win {
		win[i] = 0.5 - 0.5*math.Cos(2*math.Pi*float64(i)/float64(size))
	}
	var out [][]float64
	buf := make([]complex128, size)
	for s := 0; s+size <= len(x); s += hop {
		for i := 0; i < size; i++ {
			buf[i] = complex(x[s+i]*win[i], 0)
		}
		fft(buf)
		m := make([]float64, size/2)
		for i := range m {
			m[i] = cmplx.Abs(buf[i])
		}
		out = append(out, m)
	}
	return out
}

// ---- features -------------------------------------------------------------

const hop = 480 // 10 ms

// onsets: half-wave rectified log spectral flux, full band and low band
// (< 150 Hz, kick) at 100 frames per second.
func onsets(x []float64) (full, low []float64) {
	sp := spectra(x, 2048, hop)
	lowBinF := 150.0 / (float64(sr) / 2048.0)
	lowBin := int(lowBinF)
	full = make([]float64, len(sp))
	low = make([]float64, len(sp))
	for t := 1; t < len(sp); t++ {
		var f, lo float64
		for k := 1; k < len(sp[t]); k++ {
			d := math.Log1p(sp[t][k]) - math.Log1p(sp[t-1][k])
			if d > 0 {
				f += d
				if k <= lowBin {
					lo += d
				}
			}
		}
		full[t] = f
		low[t] = lo
	}
	return
}

// interp reads a frame series at a fractional index.
func interp(o []float64, x float64) float64 {
	i := int(x)
	if i < 0 || i+1 >= len(o) {
		return 0
	}
	f := x - float64(i)
	return o[i]*(1-f) + o[i+1]*f
}

// tempoFit searches beat periods within ±4 % of the asked tempo (and its
// double and half, reported separately) and returns the best BPM and the
// comb score ratio against the asked tempo's neighbourhood.
func tempoFit(o []float64, bpm float64) (best float64, score float64) {
	mean := 0.0
	for _, v := range o {
		mean += v
	}
	mean /= float64(len(o))
	z := make([]float64, len(o))
	for i, v := range o {
		z[i] = v - mean
	}
	ac := func(lag float64) float64 {
		s := 0.0
		for i := 0; i < len(z); i++ {
			s += z[i] * interp(z, float64(i)+lag)
		}
		return s
	}
	bestS := math.Inf(-1)
	for f := 0.96; f <= 1.04; f += 0.0005 {
		b := bpm * f
		p := 6000.0 / b // frames per beat at 100 fps
		s := 0.0
		for k := 1; k <= 16; k++ {
			s += ac(float64(k) * p)
		}
		if s > bestS {
			bestS, best = s, b
		}
	}
	return best, bestS
}

// beatPhase returns the frame offset (0..period) of the beat grid that
// collects the most onset strength, and the downbeat (0..3) whose beats
// carry the most low-band onsets.
func beatPhase(full, low []float64, period float64) (phase float64, down int) {
	bestS := math.Inf(-1)
	for ph := 0.0; ph < period; ph += 0.25 {
		s := 0.0
		for t := ph; t < float64(len(full)); t += period {
			s += interp(full, t) + 0.5*interp(full, t+period/2)
		}
		if s > bestS {
			bestS, phase = s, ph
		}
	}
	var acc [4]float64
	for i, t := 0, phase; t < float64(len(low)); i, t = i+1, t+period {
		acc[i%4] += interp(low, t) + interp(full, t)*0.25
	}
	for i := 1; i < 4; i++ {
		if acc[i] > acc[down] {
			down = i
		}
	}
	return
}

var majorProfile = []float64{6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88}
var minorProfile = []float64{6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17}
var names = []string{"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}

func chroma(x []float64) []float64 {
	sp := spectra(x, 8192, 4096)
	c := make([]float64, 12)
	binHz := float64(sr) / 8192
	for _, m := range sp {
		for k := 1; k < len(m); k++ {
			f := float64(k) * binHz
			if f < 55 || f > 4000 {
				continue
			}
			pc := int(math.Round(12*math.Log2(f/440)+69)) % 12
			if pc < 0 {
				pc += 12
			}
			c[pc] += m[k] * m[k]
		}
	}
	for i := range c {
		c[i] = math.Sqrt(c[i])
	}
	return c
}

func corr(a, b []float64) float64 {
	ma, mb := 0.0, 0.0
	for i := range a {
		ma += a[i]
		mb += b[i]
	}
	ma /= float64(len(a))
	mb /= float64(len(b))
	var s, sa, sb float64
	for i := range a {
		s += (a[i] - ma) * (b[i] - mb)
		sa += (a[i] - ma) * (a[i] - ma)
		sb += (b[i] - mb) * (b[i] - mb)
	}
	if sa == 0 || sb == 0 {
		return 0
	}
	return s / math.Sqrt(sa*sb)
}

type keyScore struct {
	Key string  `json:"key"`
	R   float64 `json:"r"`
}

func keys(c []float64) []keyScore {
	var ks []keyScore
	for root := 0; root < 12; root++ {
		for mode, prof := range [][]float64{majorProfile, minorProfile} {
			rot := make([]float64, 12)
			for i := 0; i < 12; i++ {
				rot[(i+root)%12] = prof[i]
			}
			name := names[root] + []string{" major", " minor"}[mode]
			ks = append(ks, keyScore{name, round3(corr(c, rot))})
		}
	}
	sort.Slice(ks, func(i, j int) bool { return ks[i].R > ks[j].R })
	return ks
}

func canonicalKey(k string) string {
	alias := map[string]string{"Db": "C#", "D#": "Eb", "Gb": "F#", "G#": "Ab", "A#": "Bb"}
	parts := strings.Fields(k)
	if len(parts) != 2 {
		return k
	}
	if a, ok := alias[parts[0]]; ok {
		parts[0] = a
	}
	return parts[0] + " " + strings.ToLower(parts[1])
}

// bandShare: energy above f Hz as dB relative to the total.
func bandShares(x []float64) (above12, above16 float64) {
	sp := spectra(x, 4096, 4096)
	binHz := float64(sr) / 4096
	var tot, a12, a16 float64
	for _, m := range sp {
		for k, v := range m {
			e := v * v
			tot += e
			f := float64(k) * binHz
			if f >= 12000 {
				a12 += e
			}
			if f >= 16000 {
				a16 += e
			}
		}
	}
	return round1(10 * math.Log10(a12/tot+1e-12)), round1(10 * math.Log10(a16/tot+1e-12))
}

var reI = regexp.MustCompile(`I:\s+(-?[\d.]+) LUFS`)
var reP = regexp.MustCompile(`Peak:\s+(-?[\d.]+|-inf) dBFS`)

func loudness(path string) (lufs, peak float64) {
	cmd := exec.Command("ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-")
	var e bytes.Buffer
	cmd.Stderr = &e
	_ = cmd.Run()
	s := e.String()
	if i := strings.LastIndex(s, "Summary:"); i >= 0 {
		s = s[i:]
	}
	if m := reI.FindStringSubmatch(s); m != nil {
		lufs, _ = strconv.ParseFloat(m[1], 64)
	}
	if m := reP.FindStringSubmatch(s); m != nil {
		peak, _ = strconv.ParseFloat(m[1], 64)
	}
	return
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }
func round3(v float64) float64 { return math.Round(v*1000) / 1000 }

// ---- analyze --------------------------------------------------------------

type analysis struct {
	File        string     `json:"file"`
	Seconds     float64    `json:"seconds"`
	TargetBPM   float64    `json:"targetBpm"`
	MeasuredBPM float64    `json:"measuredBpm"`
	TempoErrPct float64    `json:"tempoErrPct"`
	HalfOrDbl   string     `json:"halfOrDouble,omitempty"`
	Key         string     `json:"key"`
	KeyR        float64    `json:"keyR"`
	TargetKeyR  float64    `json:"targetKeyR,omitempty"`
	TargetRank  int        `json:"targetKeyRank,omitempty"`
	TopKeys     []keyScore `json:"topKeys"`
	Above12kDb  float64    `json:"above12kDb"`
	Above16kDb  float64    `json:"above16kDb"`
	LUFS        float64    `json:"lufs"`
	PeakDb      float64    `json:"peakDbfs"`
	BarRMSDb    []float64  `json:"barRmsDb"`
	Gate        []string   `json:"gate"`
}

func analyze(path string, bar int, key string) analysis {
	l, r := decode(path, 1)
	x := mono(l, r)
	bpm := 4 * 60 * float64(sr) / float64(bar)
	full, low := onsets(x)
	best, sAsked := tempoFit(full, bpm)
	_, sHalf := tempoFit(full, bpm/2)
	_ = low
	a := analysis{File: path, Seconds: round3(float64(len(x)) / sr), TargetBPM: round3(bpm), MeasuredBPM: round3(best)}
	a.TempoErrPct = round3(100 * (best - bpm) / bpm)
	if sHalf > 1.15*sAsked {
		a.HalfOrDbl = "half-time pulse dominates"
	}
	ks := keys(chroma(x))
	a.Key, a.KeyR, a.TopKeys = ks[0].Key, ks[0].R, ks[:4]
	if key != "" {
		want := canonicalKey(key)
		for i, k := range ks {
			if k.Key == want {
				a.TargetKeyR, a.TargetRank = k.R, i+1
			}
		}
	}
	a.Above12kDb, a.Above16kDb = bandShares(x)
	a.LUFS, a.PeakDb = loudness(path)
	// Per-bar RMS on the measured grid from the first strong beat.
	per := 6000.0 / best
	phase, down := beatPhase(full, low, per)
	start := (phase + float64(down)*per) * hop
	barLen := float64(bar) * bpm / best
	for s := start; s+barLen <= float64(len(x)); s += barLen {
		e := 0.0
		for i := int(s); i < int(s+barLen); i++ {
			e += x[i] * x[i]
		}
		a.BarRMSDb = append(a.BarRMSDb, round1(10*math.Log10(e/barLen+1e-12)))
	}
	// The gate the pilot uses (design §7.3); listening still decides.
	if math.Abs(a.TempoErrPct) > 0.6 {
		a.Gate = append(a.Gate, fmt.Sprintf("tempo %.2f%% off", a.TempoErrPct))
	}
	if key != "" && a.TargetRank > 3 {
		a.Gate = append(a.Gate, fmt.Sprintf("key: %s ranks %d (best %s)", canonicalKey(key), a.TargetRank, a.Key))
	}
	if a.PeakDb > -0.1 {
		a.Gate = append(a.Gate, "clipping risk: peak ≥ -0.1 dBFS")
	}
	if a.Above16kDb < -60 {
		a.Gate = append(a.Gate, "no air: > 60 dB down above 16 kHz")
	}
	return a
}

// ---- cut ------------------------------------------------------------------

type cutResult struct {
	File       string  `json:"file"`
	Out        string  `json:"out"`
	Kind       string  `json:"kind"`
	Rate       float64 `json:"rate"`
	StartBar   int     `json:"startBar"`
	StartSec   float64 `json:"startSec"`
	Bars       int     `json:"bars"`
	Samples    int     `json:"samples"`
	TailSec    float64 `json:"tailSec,omitempty"`
	Score      float64 `json:"score"`
	SeamCorr   float64 `json:"seamCorr,omitempty"`
	Candidates int     `json:"candidates"`
}

// barFeature: a coarse log spectrum (32 bands) of one bar for similarity.
func barFeature(x []float64, s, n int) []float64 {
	if s+n > len(x) {
		n = len(x) - s
	}
	sp := spectra(x[s:s+n], 4096, 2048)
	f := make([]float64, 32)
	for _, m := range sp {
		for k := 1; k < len(m); k++ {
			// log-spaced bands from 40 Hz to 16 kHz
			hz := float64(k) * float64(sr) / 4096
			if hz < 40 || hz > 16000 {
				continue
			}
			b := int(32 * math.Log(hz/40) / math.Log(16000.0/40))
			if b > 31 {
				b = 31
			}
			f[b] += m[k] * m[k]
		}
	}
	for i := range f {
		f[i] = math.Log1p(f[i])
	}
	return f
}

func rmsDb(x []float64, s, n int) float64 {
	e := 0.0
	for i := s; i < s+n && i < len(x); i++ {
		e += x[i] * x[i]
	}
	return 10 * math.Log10(e/float64(n)+1e-12)
}

func cut(path string, bar, bars int, kind, out string, force int) cutResult {
	bpm := 4 * 60 * float64(sr) / float64(bar)
	l0, r0 := decode(path, 1)
	full0, _ := onsets(mono(l0, r0))
	measured, _ := tempoFit(full0, bpm)
	rate := bpm / measured // >1 speeds up
	l, r := decode(path, rate)
	x := mono(l, r)
	full, low := onsets(x)
	per := 6000.0 / bpm
	phase, down := beatPhase(full, low, per)
	first := int(math.Round((phase + float64(down)*per) * hop))
	nb := (len(x) - first) / bar
	barStart := func(b int) int { return first + b*bar }
	feats := make([][]float64, nb)
	rms := make([]float64, nb)
	for b := 0; b < nb; b++ {
		feats[b] = barFeature(x, barStart(b), bar)
		rms[b] = rmsDb(x, barStart(b), bar)
	}
	med := append([]float64(nil), rms...)
	sort.Float64s(med)
	median := med[len(med)/2]
	res := cutResult{File: path, Out: out, Kind: kind, Rate: round3(rate*1e3) / 1e3, Bars: bars}
	bestS, bestB := math.Inf(-1), -1
	// Skip the first bar (generated intros often start soft) and keep room
	// for the continuation the loop seam borrows.
	lo, hi := 1, nb-bars-1
	if kind == "tail" {
		hi = nb - bars
	}
	for b := lo; b <= hi; b++ {
		if force >= 0 && b != force {
			continue
		}
		res.Candidates++
		s := 0.0
		minR := math.Inf(1)
		for i := b; i < b+bars; i++ {
			minR = math.Min(minR, rms[i])
		}
		switch kind {
		case "loop":
			// the bar after the window should sound like its first bar,
			// and no bar may drop out (no breakdown inside a loop)
			s = 4*corr(feats[b], feats[b+bars]) + corr(feats[b+bars-1], feats[b-1])
			if minR < median-6 {
				s -= 3
			}
		case "bridge":
			// energy rises through the window and lands on a loud bar
			slope := rms[b+bars-1] - rms[b]
			// and the bar it lands on jumps above the window's last bar (a hit)
			s = 0.25*slope + 0.5*(rms[b+bars]-rms[b+bars-1]) + 0.1*(rms[b+bars]-median)
			if rms[b+bars-1] > median-1 {
				s -= 3
			}
			if b+bars < nb {
				s += 0.02 * interp(low, float64(barStart(b+bars))/hop)
			}
		case "tail":
			// a strong window late in the take; the take's own decay after it
			s = 0.1*(rms[b]-median) + 0.5*float64(b)/float64(nb)
			if minR < median-9 {
				s -= 2
			}
		}
		if s > bestS {
			bestS, bestB = s, b
		}
	}
	if bestB < 0 {
		fmt.Fprintln(os.Stderr, "no window")
		os.Exit(1)
	}
	res.StartBar, res.Score = bestB, round3(bestS)
	s0 := barStart(bestB)
	n := bars * bar
	res.StartSec = round3(float64(s0) / sr)
	res.Samples = n
	outL := append([]float64(nil), l[s0:s0+n]...)
	outR := append([]float64(nil), r[s0:s0+n]...)
	switch kind {
	case "loop":
		xf := sr * 120 / 1000
		for i := 0; i < xf && s0+n+i < len(l); i++ {
			g := float64(i) / float64(xf)
			fi, fo := math.Sin(g*math.Pi/2), math.Cos(g*math.Pi/2)
			outL[i] = outL[i]*fi + l[s0+n+i]*fo
			outR[i] = outR[i]*fi + r[s0+n+i]*fo
		}
		res.SeamCorr = round3(corr(feats[bestB], feats[bestB+bars]))
	case "tail":
		// keep up to 3 s of what follows, faded over its last second
		ext := 3 * sr
		if s0+n+ext > len(l) {
			ext = len(l) - s0 - n
		}
		for i := 0; i < ext; i++ {
			g := 1.0
			if i > ext-sr {
				g = float64(ext-i) / float64(sr)
			}
			outL = append(outL, l[s0+n+i]*g)
			outR = append(outR, r[s0+n+i]*g)
		}
		res.TailSec = round3(float64(ext) / sr)
	}
	writeWav(out, outL, outR)
	return res
}

func writeWav(path string, l, r []float64) {
	n := len(l)
	var b bytes.Buffer
	w := func(v any) { binary.Write(&b, binary.LittleEndian, v) }
	b.WriteString("RIFF")
	w(uint32(36 + n*4))
	b.WriteString("WAVEfmt ")
	w(uint32(16))
	w(uint16(1))
	w(uint16(2))
	w(uint32(sr))
	w(uint32(sr * 4))
	w(uint16(4))
	w(uint16(16))
	b.WriteString("data")
	w(uint32(n * 4))
	q := func(v float64) int16 {
		v = math.Max(-1, math.Min(1, v))
		return int16(math.Round(v * 32767))
	}
	for i := 0; i < n; i++ {
		w(q(l[i]))
		w(q(r[i]))
	}
	if err := os.WriteFile(path, b.Bytes(), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
