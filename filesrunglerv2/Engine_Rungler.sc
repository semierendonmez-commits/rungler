// lib/Engine_Rungler.sc
// ─────────────────────────────────────────────────────────────
// Engine_Rungler v2: circuit-bent chaotic synth for norns
// inspired by Rob Hordijk's Benjolin & Blippoo Box
//
// v2 additions:
//   - gate sequencer (rungler-driven rhythmic envelope)
//   - twin peak filter (dual BPF à la Blippoo Box)
//   - 4 stereo pan modes (manual / rungler / random / LFO)
//   - stereo width via Haas-effect micro-delay
//   - control bus polls for attractor plot visualization
//
// NO sc3-plugins required. vanilla SuperCollider UGens only.
// ─────────────────────────────────────────────────────────────

Engine_Rungler : CroneEngine {

  var <synth;
  var pg;
  var rungBus, gateBus;

  *new { |context, doneCallback|
    ^super.new(context, doneCallback);
  }

  alloc {
    // ── control buses for polls ─────────────────────────────
    rungBus = Bus.control(context.server, 1);
    gateBus = Bus.control(context.server, 1);

    pg = Dictionary.newFrom([
      // oscillators
      \freq_a,       80.0,
      \freq_b,       3.0,
      \xmod_a,       0.0,
      \xmod_b,       0.0,
      \xmod_filt,    0.0,
      // rungler
      \chaos,        0.5,
      \loop_len,     8,
      \output_mode,  0,
      // gate
      \gate_mode,    0,
      \gate_thresh,  0.3,
      \gate_attack,  0.005,
      \gate_release, 0.3,
      // filter
      \filter_freq,  1200.0,
      \filter_res,   0.5,
      \filter_type,  0,
      \peak_spread,  1.5,
      // fx
      \fold_amt,     0.0,
      \crush_bits,   24,
      \crush_rate,   48000,
      \delay_time,   0.0,
      \delay_fb,     0.0,
      // space
      \pan,          0.0,
      \pan_mode,     0,
      \pan_depth,    0.5,
      \stereo_width, 0.0,
      // master
      \amp,          0.5
    ]);

    // ── main voice ──────────────────────────────────────────
    SynthDef(\rungler_voice, {
      arg freq_a=80, freq_b=3,
          xmod_a=0, xmod_b=0, xmod_filt=0,
          chaos=0.5, loop_len=8, output_mode=0,
          gate_mode=0, gate_thresh=0.3,
          gate_attack=0.005, gate_release=0.3,
          filter_freq=1200, filter_res=0.5,
          filter_type=0, peak_spread=1.5,
          fold_amt=0, crush_bits=24, crush_rate=48000,
          delay_time=0, delay_fb=0,
          pan=0, pan_mode=0, pan_depth=0.5,
          stereo_width=0, amp=0.5,
          rung_bus=0, gate_bus=0;

      var tri_a, tri_b, pulse_a, pulse_b;
      var sh0, sh1, sh2, sh3, sh4, sh5, sh6, sh7;
      var data_bit, xor_bit, rungler_cv, rung;
      var pwm_sig, filt_in, filt_sig;
      var lp, bp, hp, twin;
      var folded, crushed, delayed, output;
      var fb, prev_rung, prev_last;
      var trig;
      var freq_a_mod, freq_b_mod, filt_freq_mod;
      var gate_env, gate_trig;
      var pan_pos, out_l, out_r, panned;
      var mono_out;

      // ── 1. feedback path ──────────────────────────────────
      fb        = LocalIn.ar(2, 0);
      prev_rung = fb[0];
      prev_last = fb[1];

      // ── 2. oscillators with cross-modulation ──────────────
      freq_a_mod = (freq_a + (prev_rung * xmod_a * freq_a))
                   .clip(0.1, 20000);
      freq_b_mod = (freq_b + (prev_rung * xmod_b * freq_b))
                   .clip(0.1, 20000);

      tri_a   = LFTri.ar(freq_a_mod);
      pulse_a = LFPulse.ar(freq_a_mod, 0, 0.5);
      tri_b   = LFTri.ar(freq_b_mod);
      pulse_b = LFPulse.ar(freq_b_mod, 0, 0.5);

      // ── 3. rungler ────────────────────────────────────────
      // clock from osc_b rising edge
      trig     = Trig1.ar(pulse_b - 0.5, SampleDur.ir);
      data_bit = pulse_a;

      // audio-rate XOR: a + b - 2ab for binary {0,1}
      xor_bit = (data_bit + prev_last) - (2 * data_bit * prev_last);

      // chaos: smooth crossfade recycle ↔ XOR
      sh0 = ((1 - chaos) * data_bit) + (chaos * xor_bit);
      sh0 = (sh0 > 0.5);

      // 8-stage shift register
      sh1 = Latch.ar(sh0,            trig);
      sh2 = Latch.ar(Delay1.ar(sh1), trig);
      sh3 = Latch.ar(Delay1.ar(sh2), trig);
      sh4 = Latch.ar(Delay1.ar(sh3), trig);
      sh5 = Latch.ar(Delay1.ar(sh4), trig);
      sh6 = Latch.ar(Delay1.ar(sh5), trig);
      sh7 = Latch.ar(Delay1.ar(sh6), trig);

      // 3-bit DAC from last 3 active stages
      rungler_cv = Select.ar(loop_len.clip(3, 8).round - 3, [
        (sh1 * 0.25) + (sh2 * 0.5) + (sh3 * 1.0),
        (sh2 * 0.25) + (sh3 * 0.5) + (sh4 * 1.0),
        (sh3 * 0.25) + (sh4 * 0.5) + (sh5 * 1.0),
        (sh4 * 0.25) + (sh5 * 0.5) + (sh6 * 1.0),
        (sh5 * 0.25) + (sh6 * 0.5) + (sh7 * 1.0),
        (sh6 * 0.25) + (sh7 * 0.5) + (sh1 * 1.0),
      ]);

      // normalize to bipolar -1..+1
      rung = (rungler_cv / 1.75) * 2 - 1;

      // send feedback
      LocalOut.ar([rung, sh7]);

      // ── 4. gate envelope ──────────────────────────────────
      // in gate mode: on each clock, open gate only if
      // rungler DAC exceeds threshold
      gate_trig = trig * (rung.abs > gate_thresh);
      gate_env = Select.ar(gate_mode.round.clip(0, 1), [
        // mode 0: free — always on
        DC.ar(1),
        // mode 1: gated by rungler threshold
        Decay2.ar(gate_trig, gate_attack.max(0.001), gate_release.max(0.01))
          .clip(0, 1)
      ]);

      // ── 5. PWM + filter source ────────────────────────────
      pwm_sig = (tri_a - tri_b).sign;
      filt_in = (pwm_sig * 0.5)
              + ((pulse_a * 2 - 1) * 0.25)
              + ((pulse_b * 2 - 1) * 0.25);

      // ── 6. filters ────────────────────────────────────────
      filt_freq_mod = (filter_freq
        + (rung * xmod_filt * filter_freq)).clip(20, 20000);

      lp = RLPF.ar(filt_in, filt_freq_mod,
                    filter_res.clip(0.05, 2.0));
      bp = BPF.ar(filt_in, filt_freq_mod,
                   filter_res.clip(0.05, 2.0));
      hp = HPF.ar(filt_in, filt_freq_mod);

      // twin peak: two parallel BPFs with spread
      // inspired by Hordijk's Blippoo Box resonator
      twin = BPF.ar(filt_in,
               (filt_freq_mod / peak_spread.max(1.01)).clip(20, 20000),
               filter_res.clip(0.05, 2.0))
           + BPF.ar(filt_in,
               (filt_freq_mod * peak_spread.max(1.01)).clip(20, 20000),
               filter_res.clip(0.05, 2.0));
      twin = twin * 0.7;  // normalize

      filt_sig = Select.ar(filter_type.round.clip(0, 3),
                           [lp, bp, hp, twin]);

      // ── 7. output select ──────────────────────────────────
      output = Select.ar(output_mode.round.clip(0, 5), [
        filt_sig,
        tri_a,
        tri_b,
        (pulse_a * 2 - 1) * (pulse_b * 2 - 1),
        pwm_sig,
        rung,
      ]);

      // ── 8. wavefolder ─────────────────────────────────────
      folded = Select.ar((fold_amt > 0.01), [
        output,
        (output * (1 + (fold_amt * 10))).fold(-1, 1)
      ]);

      // ── 9. bit crusher ────────────────────────────────────
      crushed = Select.ar((crush_bits < 23), [
        folded,
        Latch.ar(
          (folded * 2.pow(crush_bits)).round / 2.pow(crush_bits),
          Impulse.ar(crush_rate)
        )
      ]);

      // ── 10. feedback delay ────────────────────────────────
      delayed = Select.ar((delay_time > 0.001), [
        crushed,
        crushed + (CombC.ar(
          crushed, 2.0,
          delay_time.clip(0.001, 2.0),
          delay_fb.clip(0, 0.95) * 6
        ) * 0.35)
      ]);

      // ── 11. gate + limiter ────────────────────────────────
      mono_out = LeakDC.ar(delayed * gate_env);
      mono_out = Limiter.ar(mono_out * amp, 0.95, 0.01);

      // ── 12. stereo panning ────────────────────────────────
      pan_pos = Select.ar(pan_mode.round.clip(0, 3), [
        // 0: manual
        DC.ar(pan),
        // 1: rungler-driven
        (rung * pan_depth).clip(-1, 1),
        // 2: random per gate trigger
        (Latch.ar(WhiteNoise.ar, trig) * pan_depth).clip(-1, 1),
        // 3: osc_b triangle LFO
        (tri_b * pan_depth).clip(-1, 1),
      ]);

      panned = Pan2.ar(mono_out, pan_pos);
      out_l = panned[0];
      out_r = panned[1];

      // ── 13. stereo width (Haas effect) ────────────────────
      out_r = Select.ar((stereo_width > 0.005), [
        out_r,
        DelayC.ar(out_r, 0.02, stereo_width.clip(0, 1) * 0.012)
      ]);

      Out.ar(0, [out_l, out_r]);

      // ── 14. control bus output for polls ──────────────────
      Out.kr(rung_bus, A2K.kr(rung));
      Out.kr(gate_bus, A2K.kr(gate_env));
    }).add;

    context.server.sync;

    // ── instantiate voice ───────────────────────────────────
    synth = Synth.new(\rungler_voice, [
      \freq_a,       pg[\freq_a],
      \freq_b,       pg[\freq_b],
      \xmod_a,       pg[\xmod_a],
      \xmod_b,       pg[\xmod_b],
      \xmod_filt,    pg[\xmod_filt],
      \chaos,        pg[\chaos],
      \loop_len,     pg[\loop_len],
      \output_mode,  pg[\output_mode],
      \gate_mode,    pg[\gate_mode],
      \gate_thresh,  pg[\gate_thresh],
      \gate_attack,  pg[\gate_attack],
      \gate_release, pg[\gate_release],
      \filter_freq,  pg[\filter_freq],
      \filter_res,   pg[\filter_res],
      \filter_type,  pg[\filter_type],
      \peak_spread,  pg[\peak_spread],
      \fold_amt,     pg[\fold_amt],
      \crush_bits,   pg[\crush_bits],
      \crush_rate,   pg[\crush_rate],
      \delay_time,   pg[\delay_time],
      \delay_fb,     pg[\delay_fb],
      \pan,          pg[\pan],
      \pan_mode,     pg[\pan_mode],
      \pan_depth,    pg[\pan_depth],
      \stereo_width, pg[\stereo_width],
      \amp,          pg[\amp],
      \rung_bus,     rungBus.index,
      \gate_bus,     gateBus.index,
    ], target: context.xg);

    // ── commands: float ─────────────────────────────────────
    [\freq_a, \freq_b, \xmod_a, \xmod_b, \xmod_filt,
     \chaos, \filter_freq, \filter_res, \fold_amt,
     \crush_rate, \delay_time, \delay_fb, \amp, \pan,
     \gate_thresh, \gate_attack, \gate_release,
     \peak_spread, \pan_depth, \stereo_width].do({ |key|
      this.addCommand(key, "f", { |msg|
        pg[key] = msg[1];
        synth.set(key, msg[1]);
      });
    });

    // ── commands: integer ───────────────────────────────────
    [\loop_len, \filter_type, \crush_bits, \output_mode,
     \gate_mode, \pan_mode].do({ |key|
      this.addCommand(key, "i", { |msg|
        pg[key] = msg[1];
        synth.set(key, msg[1]);
      });
    });

    // ── polls ───────────────────────────────────────────────
    this.addPoll(\rung_cv, {
      rungBus.getSynchronous ? 0
    });
    this.addPoll(\gate_state, {
      gateBus.getSynchronous ? 0
    });
  }

  free {
    if (synth.notNil)    { synth.free;    synth    = nil; };
    if (rungBus.notNil)  { rungBus.free;  rungBus  = nil; };
    if (gateBus.notNil)  { gateBus.free;  gateBus  = nil; };
  }
}
