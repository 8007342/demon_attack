package main

import (
	"fmt"
	"math"
	"sort"
)

// The check command measures what a listener hears at a loop's wrap,
// without the host audio studio: the sample step across the wrap against
// the file's own 99.9th-percentile step, and the spectral flux at the wrap
// against the median flux at the loop's own bar lines. It also counts clipped
// samples and isolated step spikes (clicks), and whether a loop is a whole
// number of bars.

type checkResult struct {
	File        string   `json:"file"`
	Seconds     float64  `json:"seconds"`
	WholeBars   float64  `json:"bars"`
	SeamJump    float64  `json:"seamJumpRatio,omitempty"`
	SeamFlux    float64  `json:"seamFluxRatio,omitempty"`
	Clipped     int      `json:"clippedSamples"`
	ClickFrames int      `json:"clicks"`
	Findings    []string `json:"findings"`
}

func check(path string, bar int, loop bool) checkResult {
	l, r := decode(path, 1)
	x := mono(l, r)
	n := len(x)
	res := checkResult{File: path, Seconds: round3(float64(n) / sr), WholeBars: round3(float64(n) / float64(bar))}
	steps := make([]float64, n-1)
	for i := 1; i < n; i++ {
		steps[i-1] = math.Abs(x[i] - x[i-1])
	}
	sorted := append([]float64(nil), steps...)
	sort.Float64s(sorted)
	p999 := sorted[len(sorted)*999/1000] + 1e-9
	for i := range l {
		if math.Abs(l[i]) >= 0.999 || math.Abs(r[i]) >= 0.999 {
			res.Clipped++
		}
	}
	// a click: one step above 4× p99.9 with every other step within ±2 ms
	// below p99.9
	const w = 96
	for i := w; i < len(steps)-w; i++ {
		if steps[i] <= 4*p999 {
			continue
		}
		quiet := true
		for j := i - w; j <= i+w; j++ {
			if j != i && steps[j] > p999 {
				quiet = false
				break
			}
		}
		if quiet {
			res.ClickFrames++
		}
	}
	if loop {
		res.SeamJump = round3(math.Abs(x[0]-x[n-1]) / p999)
		h := sr / 2
		splice := append(append([]float64(nil), x[n-h:]...), x[:h]...)
		f, _ := onsets(splice)
		fa, _ := onsets(x)
		// The wrap is a bar line, so compare it with the loop's own bar
		// lines (each has its downbeat onset), not with the average frame.
		near := func(o []float64, c int) float64 {
			p := 0.0
			for i := c - 2; i <= c+2; i++ {
				if i >= 0 && i < len(o) {
					p = math.Max(p, o[i])
				}
			}
			return p
		}
		var lines []float64
		for b := 1; b*bar < n; b++ {
			lines = append(lines, near(fa, b*bar/hop))
		}
		sort.Float64s(lines)
		ref := 1e-9
		if len(lines) > 0 {
			ref += lines[len(lines)/2]
		}
		res.SeamFlux = round3(near(f, h/hop) / ref)
		if res.SeamJump > 1 {
			res.Findings = append(res.Findings, "seam: sample step above the file's 99.9th percentile")
		}
		if res.SeamFlux > 1.5 {
			res.Findings = append(res.Findings, "seam: spectral jump at the wrap")
		}
		if math.Abs(res.WholeBars-math.Round(res.WholeBars)) > 1e-3 {
			res.Findings = append(res.Findings, "length is not a whole number of bars")
		}
	}
	if res.Clipped > 0 {
		res.Findings = append(res.Findings, fmt.Sprintf("%d clipped samples", res.Clipped))
	}
	if res.ClickFrames > 0 {
		res.Findings = append(res.Findings, fmt.Sprintf("%d isolated clicks", res.ClickFrames))
	}
	return res
}
