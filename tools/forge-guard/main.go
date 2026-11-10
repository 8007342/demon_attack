// forge-guard keeps heavy local jobs from stalling a shared Tillandsias forge.
//
// The forge cgroup has a soft memory.high limit. Crossing it does not kill
// anything: the kernel reclaims forever and every process stalls silently.
// forge-guard turns that into a loud, early failure, and serialises heavy
// jobs across every agent in the forge.
//
//	forge-guard run [flags] -- cmd args...   run one heavy job under the guard
//	forge-guard wait --pid N | --file PATH   wait for a job without pgrep -f
//	forge-guard status                       memory, pressure and lock holder
//
// run:
//   - takes an exclusive flock (--lock, default "heavy"), so heavy jobs queue
//     instead of piling up;
//   - waits until anon+shmem leaves --need GiB under memory.high;
//   - runs the command in its own process group, with OMP/torch/numexpr
//     threads capped (--threads);
//   - kills the whole group (TERM, then KILL) when anon+shmem stays above
//     --kill-at GiB, or the memory.high event rate stays above --max-events
//     per second, for --grace seconds. Exit status 137, with the reason.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const cg = "/sys/fs/cgroup"
const gib = 1 << 30

func readInt(path string) (int64, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	s := strings.TrimSpace(string(b))
	if s == "max" {
		return -1, nil
	}
	return strconv.ParseInt(s, 10, 64)
}

func keyed(path, key string) int64 {
	f, err := os.Open(path)
	if err != nil {
		return 0
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		parts := strings.Fields(sc.Text())
		if len(parts) == 2 && parts[0] == key {
			v, _ := strconv.ParseInt(parts[1], 10, 64)
			return v
		}
	}
	return 0
}

// pinned is the memory the kernel cannot drop: anonymous memory plus shmem,
// which includes tmpfs files such as /home/forge/src.
func pinned() int64 {
	return keyed(cg+"/memory.stat", "anon") + keyed(cg+"/memory.stat", "shmem")
}

func high() int64 {
	v, err := readInt(cg + "/memory.high")
	if err != nil || v < 0 {
		if m, err := readInt(cg + "/memory.max"); err == nil && m > 0 {
			return m
		}
		return 0
	}
	return v
}

func highEvents() int64 { return keyed(cg+"/memory.events", "high") }

func gb(v int64) string { return fmt.Sprintf("%.1f GiB", float64(v)/gib) }

func lockDir() string {
	if d := os.Getenv("FORGE_GUARD_DIR"); d != "" {
		return d
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache", "tillandsias-project", "forge-guard")
}

func logf(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "forge-guard: "+format+"\n", a...)
}

func status() {
	h := high()
	cur, _ := readInt(cg + "/memory.current")
	fmt.Printf("memory.current %s, pinned (anon+shmem) %s, memory.high %s, high events %d\n",
		gb(cur), gb(pinned()), gb(h), highEvents())
	entries, _ := filepath.Glob(filepath.Join(lockDir(), "*.owner"))
	for _, e := range entries {
		b, _ := os.ReadFile(e)
		fmt.Printf("lock %s: %s", strings.TrimSuffix(filepath.Base(e), ".owner"), string(b))
	}
}

func run(args []string) int {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	lock := fs.String("lock", "heavy", "lock name; jobs sharing a name run one at a time (empty = no lock)")
	need := fs.Float64("need", 3, "GiB of headroom under memory.high required before starting")
	killAt := fs.Float64("kill-at", 0, "kill when anon+shmem exceeds this many GiB (default memory.high - 1.5)")
	maxEvents := fs.Float64("max-events", 2000, "kill when memory.high events per second exceed this")
	grace := fs.Int("grace", 20, "seconds a limit must be exceeded before killing")
	threads := fs.Int("threads", 4, "cap for OMP/MKL/torch/numexpr/rayon threads in the job")
	startWait := fs.Int("start-timeout", 1800, "seconds to wait for the lock and headroom before giving up")
	maxRun := fs.Int("timeout", 0, "kill the job after this many seconds of running (0 = no limit); default 1800 for lock \"flutter\"")
	fs.Parse(args)
	cmdArgs := fs.Args()
	if len(cmdArgs) == 0 {
		logf("run needs a command after --")
		return 2
	}
	if *maxRun == 0 && *lock == "flutter" {
		*maxRun = 1800
	}
	h := high()
	if h <= 0 {
		logf("no memory.high/max in %s; running without memory supervision", cg)
	}
	limit := int64(*killAt * gib)
	if limit == 0 && h > 0 {
		limit = h - 3*gib/2
	}
	deadline := time.Now().Add(time.Duration(*startWait) * time.Second)

	if *lock != "" {
		if err := os.MkdirAll(lockDir(), 0o755); err != nil {
			logf("lock dir: %v", err)
			return 1
		}
		path := filepath.Join(lockDir(), *lock+".lock")
		f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
		if err != nil {
			logf("lock: %v", err)
			return 1
		}
		defer f.Close()
		announced := false
		for {
			if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err == nil {
				break
			}
			if !announced {
				b, _ := os.ReadFile(filepath.Join(lockDir(), *lock+".owner"))
				logf("waiting for lock %q held by: %s", *lock, strings.TrimSpace(string(b)))
				announced = true
			}
			if time.Now().After(deadline) {
				logf("gave up waiting for lock %q", *lock)
				return 75
			}
			time.Sleep(2 * time.Second)
		}
		owner := filepath.Join(lockDir(), *lock+".owner")
		os.WriteFile(owner, []byte(fmt.Sprintf("pid %d since %s: %s\n", os.Getpid(),
			time.Now().Format(time.RFC3339), strings.Join(cmdArgs, " "))), 0o644)
		defer os.Remove(owner)
	}

	if h > 0 {
		for h-pinned() < int64(*need*gib) {
			if time.Now().After(deadline) {
				logf("gave up: only %s free under memory.high, need %.1f GiB", gb(h-pinned()), *need)
				return 75
			}
			logf("waiting for headroom: %s free under memory.high, need %.1f GiB", gb(h-pinned()), *need)
			time.Sleep(10 * time.Second)
		}
	}

	cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	t := strconv.Itoa(*threads)
	cmd.Env = append(os.Environ(),
		"OMP_NUM_THREADS="+t, "MKL_NUM_THREADS="+t, "OPENBLAS_NUM_THREADS="+t,
		"NUMEXPR_MAX_THREADS="+t, "TORCH_NUM_THREADS="+t, "RAYON_NUM_THREADS="+t,
		"GOMAXPROCS="+t, "FORGE_GUARD=1")
	if err := cmd.Start(); err != nil {
		logf("start: %v", err)
		return 127
	}
	pgid := cmd.Process.Pid
	killGroup := func(reason string) {
		logf("killing job (pgid %d): %s", pgid, reason)
		syscall.Kill(-pgid, syscall.SIGTERM)
		time.Sleep(10 * time.Second)
		syscall.Kill(-pgid, syscall.SIGKILL)
	}

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	tick := time.NewTicker(2 * time.Second)
	defer tick.Stop()
	var overSince, stormSince time.Time
	lastEvents, lastAt := highEvents(), time.Now()
	killed := ""
	started := time.Now()
	for {
		select {
		case err := <-done:
			if killed != "" {
				logf("job killed: %s", killed)
				return 137
			}
			var ee *exec.ExitError
			if errors.As(err, &ee) {
				return ee.ExitCode()
			}
			if err != nil {
				return 1
			}
			return 0
		case s := <-sigs:
			syscall.Kill(-pgid, s.(syscall.Signal))
		case now := <-tick.C:
			if *maxRun > 0 && killed == "" && now.Sub(started) > time.Duration(*maxRun)*time.Second {
				killed = fmt.Sprintf("ran longer than --timeout %ds (hung job?); lock %q released", *maxRun, *lock)
				go killGroup(killed)
				continue
			}
			if h <= 0 || killed != "" {
				continue
			}
			p := pinned()
			if limit > 0 && p > limit {
				if overSince.IsZero() {
					overSince = now
					logf("warning: pinned memory %s is above %s", gb(p), gb(limit))
				} else if now.Sub(overSince) >= time.Duration(*grace)*time.Second {
					killed = fmt.Sprintf("pinned memory %s stayed above %s for %ds (memory.high %s)", gb(p), gb(limit), *grace, gb(h))
					go killGroup(killed)
				}
			} else {
				overSince = time.Time{}
			}
			ev := highEvents()
			rate := float64(ev-lastEvents) / now.Sub(lastAt).Seconds()
			lastEvents, lastAt = ev, now
			if rate > *maxEvents {
				if stormSince.IsZero() {
					stormSince = now
					logf("warning: memory.high reclaim storm, %.0f events/s", rate)
				} else if now.Sub(stormSince) >= time.Duration(*grace)*time.Second && killed == "" {
					killed = fmt.Sprintf("memory.high reclaim storm (%.0f events/s) for %ds; the forge would stall", rate, *grace)
					go killGroup(killed)
				}
			} else {
				stormSince = time.Time{}
			}
		}
	}
}

func wait(args []string) int {
	fs := flag.NewFlagSet("wait", flag.ExitOnError)
	pid := fs.Int("pid", 0, "wait until this PID exits")
	file := fs.String("file", "", "wait until this file exists")
	timeout := fs.Int("timeout", 0, "give up after this many seconds (0 = never)")
	fs.Parse(args)
	if (*pid == 0) == (*file == "") {
		logf("wait needs exactly one of --pid or --file")
		return 2
	}
	var deadline time.Time
	if *timeout > 0 {
		deadline = time.Now().Add(time.Duration(*timeout) * time.Second)
	}
	for {
		if *pid != 0 {
			if err := syscall.Kill(*pid, 0); errors.Is(err, syscall.ESRCH) {
				return 0
			}
		} else if _, err := os.Stat(*file); err == nil {
			return 0
		}
		if !deadline.IsZero() && time.Now().After(deadline) {
			logf("timed out")
			return 124
		}
		time.Sleep(2 * time.Second)
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: forge-guard run [flags] -- cmd... | wait --pid N|--file P | status")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "run":
		os.Exit(run(os.Args[2:]))
	case "wait":
		os.Exit(wait(os.Args[2:]))
	case "status":
		status()
	default:
		fmt.Fprintln(os.Stderr, "unknown command", os.Args[1])
		os.Exit(2)
	}
}
