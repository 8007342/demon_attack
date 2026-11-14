package main

import (
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestKWeightingMatchesReferenceAndGain(t *testing.T) {
	sine := make([]float64, 24000)
	twice := make([]float64, 24000)
	for i := range sine {
		sine[i] = .1 * math.Sin(2*math.Pi*1000*float64(i)/24000)
		twice[i] = 2 * sine[i]
	}
	// Independently measured with the existing scipy BS.1770 implementation.
	if actual := loudness(sine); math.Abs(actual-(-23.26313562307255)) > 1e-7 {
		t.Fatalf("reference LUFS: %.12f", actual)
	}
	if delta := loudness(twice) - loudness(sine); math.Abs(delta-20*math.Log10(2)) > 1e-6 {
		t.Fatalf("gain law: %.9f", delta)
	}
	if actual := loudness(make([]float64, 24000)); actual != -70 {
		t.Fatalf("silence: %f", actual)
	}
}
func TestTimingRejectsSilentMouthAndFlicker(t *testing.T) {
	good := Metadata{Samples: 24000, Mouth: "002222222222200", Open: "003333333333300", Vis: strings.Repeat("-", 15)}
	if err := validateTiming(good); err != nil {
		t.Fatal(err)
	}
	bad := good
	bad.Open = strings.Repeat("0", 15)
	if validateTiming(bad) == nil {
		t.Fatal("silent mouth accepted")
	}
	bad = good
	bad.Mouth = "020222222222200"
	if validateTiming(bad) == nil {
		t.Fatal("flicker accepted")
	}
	bad = good
	bad.Samples = 48000
	if validateTiming(bad) == nil {
		t.Fatal("stale duration accepted")
	}
}
func TestCandidateChecksActualDecodedAudioAndHashes(t *testing.T) {
	ffmpeg := "/home/linuxbrew/.linuxbrew/bin/ffmpeg"
	if _, err := os.Stat(ffmpeg); err != nil {
		t.Skip("ffmpeg fixture tool unavailable")
	}
	root := t.TempDir()
	dir := filepath.Join(root, "test.h0")
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	master := filepath.Join(dir, "baseline.flac")
	command := exec.Command(ffmpeg, "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=24000:duration=1",
		"-af", "loudnorm=I=-18:TP=-4:LRA=11", "-ar", "24000", "-c:a", "flac", master)
	if out, err := command.CombinedOutput(); err != nil {
		t.Fatalf("fixture: %v %s", err, out)
	}
	for _, name := range []string{"expressive", "voice"} {
		if err := copyFile(master, filepath.Join(dir, name+".flac")); err != nil {
			t.Fatal(err)
		}
	}
	command = exec.Command(ffmpeg, "-v", "error", "-i", master, "-c:a", "libopus", "-b:a", "48k", filepath.Join(dir, "radio.ogg"))
	if out, err := command.CombinedOutput(); err != nil {
		t.Fatalf("fixture codec: %v %s", err, out)
	}
	m := Metadata{Schema: "demon-attack.voice-candidate/v1", ID: "test.h0", Speaker: "pilot", Kind: "human", Trigger: "test", Text: "Hold formation!",
		Samples: 24000, Mouth: "002222222222200", Open: "003333333333300", Vis: strings.Repeat("-", 15), Engine: "chatterbox", Masters: map[string]Master{}, Inputs: map[string]string{"source": "current"}}
	for _, name := range []string{"baseline", "expressive", "voice"} {
		d, err := digest(filepath.Join(dir, name+".flac"))
		if err != nil {
			t.Fatal(err)
		}
		m.Masters[name] = Master{SHA: d}
	}
	m.Codec.Name = "opus"
	m.Codec.Bitrate = 48
	m.Codec.SHA, _ = digest(filepath.Join(dir, "radio.ogg"))
	metadata := filepath.Join(dir, "metadata.json")
	if err := writeJSON(metadata, m); err != nil {
		t.Fatal(err)
	}
	want := Expected{"test.h0", "test", "human", "pilot", "Hold formation!"}
	clip, err := validateCandidate(root, want, map[string]string{"source": "current"}, ffmpeg)
	if err != nil {
		t.Fatal(err)
	}
	if clip.DecodedSamples != 24000 || math.Abs(clip.DecodedLUFS+18) > 1.5 {
		t.Fatalf("decoded fixture: %+v", clip)
	}
	if _, err := validateCandidate(root, want, map[string]string{"source": "changed"}, ffmpeg); err == nil {
		t.Fatal("stale source accepted")
	}
	if err := os.WriteFile(filepath.Join(dir, "voice.flac"), []byte("corrupt"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := validateCandidate(root, want, map[string]string{"source": "current"}, ffmpeg); err == nil {
		t.Fatal("corrupt master accepted")
	}
}
