# rungler

*bent by design*

---

two oscillators meet inside a shift register. what comes out is neither random nor predictable — it is chaotic. the register feeds itself through XOR logic, creating stepped voltages that modulate everything: pitch, timbre, filter, rhythm, space.

a gate sequencer turns chaos into rhythm. a twin peak resonator turns noise into vowels. four panning modes spread the signal across a stereo field that follows the rungler's logic. hold K1 and watch the chaotic attractor emerge on screen.

a norns instrument inspired by Rob Hordijk's Benjolin & Blippoo Box.

---

### requirements

- norns (shield / standard / fates)
- no additional libraries or sc3-plugins

### install

`;install https://github.com/semi/rungler`

---

### the instrument

**the rungler** is an 8-bit shift register clocked by oscillator B. oscillator A provides data. the last bit feeds back through XOR into the first stage. a 3-bit DAC turns the register state into a stepped control voltage. the chaos knob crossfades between looping and XOR feedback.

**the gate sequencer** opens an envelope only when the rungler CV exceeds a threshold on each clock tick. this turns the chaotic output into rhythmic patterns — the density determined by the threshold, the tempo by oscillator B's frequency.

**the twin peak filter** runs two bandpass filters in parallel with offset frequencies, inspired by the Blippoo Box resonator. the interaction between two resonant peaks creates vowel-like formants.

**four stereo modes** — manual position, rungler-driven panning, random pan per gate trigger, or osc B triangle LFO. stereo width adds Haas-effect micro-delay.

**the attractor plot** (hold K1) shows a return map: rung(t) vs rung(t-1). watch discrete loops bifurcate into full chaotic attractors as you adjust chaos.

the engine uses only vanilla SuperCollider UGens — no sc3-plugins dependency.

---

### controls

six pages, navigated with E1. K2 toggles alt params.

**page 1 — OSC**
E2: osc A freq / E3: osc B freq
alt: rung→A depth / rung→B depth

**page 2 — RUNGLER**
E2: chaos / E3: rung→filter
alt: register length / output select

**page 3 — GATE**
E2: threshold / E3: release
alt: attack / mode (free/gated)

**page 4 — FILTER**
E2: cutoff / E3: resonance
alt: type (LP/BP/HP/Twin) / peak spread

**page 5 — FX**
E2: wavefold / E3: delay time
alt: bit crush / delay feedback

**page 6 — SPACE**
E2: auto-pan depth / E3: stereo width
alt: pan mode / volume

K1 held: attractor plot
K3: randomize page / K1+K3: reset all

---

### starting points

1. **slow drift**: A=80Hz, B=0.5Hz, chaos=0.3, rung→A=0.4. long evolving patterns.
2. **kaotik ritim**: A=200Hz, B=8Hz, gate mode on, threshold=0.4, twin peak filter. rhythmic vowels.
3. **broken radio**: A=440Hz, B=3Hz, crush=6bit, delay=0.3s, fb=0.7, pan=rungler.
4. **drone**: A=40Hz, B=0.1Hz, chaos=0.1, LP filter, res=1.5, rung→filter=1.0, width=0.7.
5. **percussion**: A=800Hz, B=12Hz, gate mode, threshold=0.6, fold=0.8, crush=8bit, release=0.05.

---

### acknowledgments

- Rob Hordijk for the Benjolin, Blippoo Box, and "bent by design" philosophy
- Alejandro Olarte for the [SC Benjolin](https://scsynth.org/t/benjolin-inspired-instrument/1074)
- @scazan for [benjolis](https://llllllll.co/t/benjolis/28061)
- Derek Holzer for [PD Benjolin docs](https://github.com/macumbista/benjolin)

---

source: https://github.com/semi/rungler
