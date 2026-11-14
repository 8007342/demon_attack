package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

var familyFiles = []string{"ground-fleet.json", "ground-host.json", "ground-infantry.json"}

type Project struct {
	Fams  map[string]*Family
	Rigs  map[string]*Rig
	Pals  map[string]*Palette // by faction
	Cams  map[string]*Family  // faction -> vehicle family (camera)
	mu    sync.Mutex
	cells map[string][]Cell
	bs    map[string]*Builder
}

func loadProject() *Project {
	p := &Project{Fams: map[string]*Family{}, Pals: map[string]*Palette{}, Cams: map[string]*Family{}, cells: map[string][]Cell{}, bs: map[string]*Builder{}}
	rigs, err := loadRigs(filepath.Join(root, "art/families/rigs"))
	must(err)
	p.Rigs = rigs
	for _, f := range familyFiles {
		fam, err := loadFamily(filepath.Join(root, "art/families", f))
		must(err)
		p.Fams[f] = fam
		if fam.Faction != "mixed" {
			p.Pals[fam.Faction] = fam.palette()
			p.Cams[fam.Faction] = fam
		}
	}
	return p
}

func (p *Project) validate() []string {
	var errs []string
	for _, f := range familyFiles {
		errs = append(errs, p.Fams[f].validate(p.Rigs, p.Fams)...)
	}
	listed := map[string]bool{}
	for _, f := range p.Fams {
		for _, u := range f.Units {
			listed[u.ID] = true
		}
	}
	for id := range p.Rigs {
		if !listed[id] {
			errs = append(errs, fmt.Sprintf("rig %s is in no family", id))
		}
	}
	sort.Strings(errs)
	return errs
}

func cmdValidate() {
	p := loadProject()
	errs := p.validate()
	for _, e := range errs {
		fmt.Println(e)
	}
	if len(errs) > 0 {
		os.Exit(1)
	}
	n := 0
	for _, f := range p.Fams {
		n += len(f.Units)
	}
	fmt.Printf("ok: %d families, %d units, %d rigs\n", len(p.Fams), n, len(p.Rigs))
}

type unitRef struct {
	Fam  *Family
	Spec *UnitSpec
}

func (p *Project) units() []unitRef {
	var out []unitRef
	for _, f := range familyFiles {
		fam := p.Fams[f]
		for i := range fam.Units {
			out = append(out, unitRef{fam, &fam.Units[i]})
		}
	}
	return out
}

func (u unitRef) faction() string {
	if u.Spec.Faction != "" {
		return u.Spec.Faction
	}
	return u.Fam.Faction
}

func (p *Project) builder(u unitRef) *Builder {
	p.mu.Lock()
	defer p.mu.Unlock()
	if b := p.bs[u.Spec.ID]; b != nil {
		return b
	}
	fac := u.faction()
	cw, ch := u.Fam.Atlas.Cell[0], u.Fam.Atlas.Cell[1]
	if u.Spec.Block == "K" {
		ch *= 2
	}
	b := newBuilder(u.Spec, p.Rigs[u.Spec.ID], p.Cams[fac], p.Pals[fac], cw, ch)
	p.bs[u.Spec.ID] = b
	return b
}

// cellsOf builds (once) every master cell of a unit.
func (p *Project) cellsOf(u unitRef) []Cell {
	p.mu.Lock()
	c, ok := p.cells[u.Spec.ID]
	p.mu.Unlock()
	if ok {
		return c
	}
	b := p.builder(u)
	c = b.build()
	p.mu.Lock()
	p.cells[u.Spec.ID] = c
	p.mu.Unlock()
	return c
}

// buildAll renders every unit in parallel (one goroutine per unit, bounded).
func (p *Project) buildAll() {
	us := p.units()
	sem := make(chan struct{}, 4)
	var wg sync.WaitGroup
	for _, u := range us {
		wg.Add(1)
		sem <- struct{}{}
		go func(u unitRef) {
			defer wg.Done()
			p.cellsOf(u)
			<-sem
		}(u)
	}
	wg.Wait()
}

func blockRows(block string) int {
	switch block {
	case "V":
		return 4
	case "W":
		return 5
	case "K":
		return 8
	}
	return 2
}

func (p *Project) unit(id string) unitRef {
	for _, u := range p.units() {
		if u.Spec.ID == id {
			return u
		}
	}
	fail(fmt.Errorf("no unit %s", id))
	return unitRef{}
}

func atlasPath(f *Family, sector string) string {
	return strings.ReplaceAll(f.Atlas.File, "{sector}", sector)
}
