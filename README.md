# rungler

a circuit-bent chaotic synth voice for [norns](https://monome.org/docs/norns/)

two oscillators cross-modulate through an 8-bit shift register. the register feeds back into itself through XOR logic, creating stepped voltage patterns that hover between order and chaos. a twin peak resonator sculpts the output. a gate sequencer turns the rungler into a rhythmic engine. wavefolder, bit crusher and feedback delay bend the circuit further. four stereo panning modes spread the chaos across the field.

inspired by Rob Hordijk's Benjolin & Blippoo Box — "bent by design."

## requirements

- norns (shield, standard, or fates)
- no additional libraries required

## install

from maiden:

```
;install https://github.com/semi/rungler
```

## controls

### navigation

| control | function |
|---------|----------|
| **E1** | page select (6 pages) |
| **K1 held** | show attractor plot |
| **K2** | toggle alt mode |
| **K3** | randomize current page |
| **K1 + K3** | reset all to defaults |

### page 1: OSC

| control | normal | alt |
|---------|--------|-----|
| **E2** | osc A frequency | rungler → osc A depth |
| **E3** | osc B frequency | rungler → osc B depth |

### page 2: RUNGLER

| control | normal | alt |
|---------|--------|-----|
| **E2** | chaos (recycle ↔ XOR) | register length (3–8) |
| **E3** | rungler → filter depth | output select |

output modes: filter / osc a / osc b / xor / pwm / rungler

### page 3: GATE

| control | normal | alt |
|---------|--------|-----|
| **E2** | gate threshold | gate attack |
| **E3** | gate release | gate mode (free/gated) |

the gate sequencer turns the rungler into a rhythm machine. on each clock tick (osc B), the gate opens only if the rungler CV exceeds the threshold. different oscillator frequency ratios and chaos settings produce different rhythmic patterns.

### page 4: FILTER

| control | normal | alt |
|---------|--------|-----|
| **E2** | cutoff frequency | filter type (LP/BP/HP/Twin) |
| **E3** | resonance | peak spread |

**twin peak** mode runs two bandpass filters in parallel with offset frequencies — inspired by the Blippoo Box resonator. the peak spread parameter controls the frequency ratio between the two peaks.

### page 5: FX

| control | normal | alt |
|---------|--------|-----|
| **E2** | wavefold amount | bit crush depth |
| **E3** | delay time | delay feedback |

### page 6: SPACE

| control | normal | alt |
|---------|--------|-----|
| **E2** | auto-pan depth | pan mode |
| **E3** | stereo width | volume |

**pan modes:**
- **manual**: static position
- **rungler**: rungler CV drives panning
- **random**: new random position on each gate trigger
- **lfo**: osc B triangle sweeps the stereo field

**stereo width** adds Haas-effect micro-delay to the right channel, widening the image.

### attractor plot

hold K1 to see the return map: each point plots rungler CV(t) on X against rungler CV(t-1) on Y. at low chaos, you see discrete clusters (looping patterns). at high chaos, a structured cloud emerges — the chaotic attractor.

## architecture

```
rungler/
  rungler.lua                  main entry point
  lib/
    Engine_Rungler.sc          SuperCollider engine
    ui.lua                     screen drawing (6 pages + attractor)
    core.lua                   parameters, polls, state
```

### signal flow

```
                    ┌──────────────────────────────┐
 OSC_A (tri+pulse) ─┤                              ├─► RUNGLER
                    │     cross modulation          │   (8-bit shift register)
 OSC_B (tri+pulse) ─┤                              │       │
                    └──────────────────────────────┘       │
                            ▲                              │
                            │ feedback                     ▼
                            │                         ┌─────────┐
                            └──── 3-bit DAC ◄─────────┤ XOR/loop│
                                     │                └─────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
                    ▼                ▼                ▼
              gate envelope    filter freq      osc freq
                    │                │
                    ▼                ▼
         PWM (triA vs triB) ──► FILTER (LP/BP/HP/Twin Peak)
                                     │
                                wavefolder
                                bit crusher
                                feedback delay
                                     │
                               gate envelope
                                     │
                             stereo pan + width
                                     │
                                     ▼
                                 stereo out
```

### no sc3-plugins required

the engine uses only vanilla SuperCollider UGens. the shift register is built from `Latch.ar` + `Delay1.ar` chains. XOR is computed as `a + b - 2ab` for audio-rate binary signals. the twin peak filter uses two standard `BPF` UGens in parallel.

## tips

- **finding chaos**: start with A=80Hz, B=3Hz, chaos=0.5. slowly turn up rungler→A. the boundary between stable and chaotic is where the music lives.
- **rhythmic patterns**: enable gate mode. threshold determines density. low threshold = many gates = dense. high threshold = sparse. osc B frequency = tempo.
- **twin peak vowels**: set filter type to Twin, resonance high (>1.0), peak spread around 2.0. sweep cutoff slowly. the interaction between the two peaks creates vowel-like timbres.
- **stereo chaos**: set pan mode to "rungler", depth to 0.7, width to 0.5. the signal bounces across the stereo field following the chaotic CV.
- **attractor watching**: hold K1 while adjusting chaos. watch the return map transition from discrete points (loop) through bifurcation to a full chaotic attractor.
- **extreme territory**: osc B at 0.1Hz = glacial evolution. osc B at 2kHz = metallic timbre. fold + crush together = circuit destruction.

## acknowledgments

- Rob Hordijk for the Benjolin design, Blippoo Box twin peak resonator, and "bent by design" philosophy
- Alejandro Olarte for the [SuperCollider Benjolin implementation](https://scsynth.org/t/benjolin-inspired-instrument/1074)
- scazan for the original [norns benjolis script](https://github.com/scazan/benjolis)
- Derek Holzer (macumbista) for [Pure Data Benjolin documentation](https://github.com/macumbista/benjolin)
- the lines community

## license

MIT
