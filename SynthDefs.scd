(
// --- Mixer Synths ---

// Fader with control bus
SynthDef(\fader, { |inBus, outBus, ctrlBus|
	var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

	// print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "fader L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "fader R");

	Out.ar(outBus, sig);
}).add;

// Fader with control bus
SynthDef(\groupFader, { |inBus, outBus, ctrlBus|
	var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

	// print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "group fader L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "group fader R");

	Out.ar(outBus, sig);
}).add;

// Fader with control bus
SynthDef(\fxGroupFader, { |inBus, outBus, ctrlBus|
	var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

	// print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "FX group fader L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "FX group fader R");

	Out.ar(outBus, sig);
}).add;

SynthDef(\drySend, { |inBus, outBus, ctrlBus|
	var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

	// print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "dry send L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "dry send R");

	Out.ar(outBus, sig);
}).add;

// Multi-send: tap one input bus, send copies to multiple FX buses
SynthDef(\multiSend, { |inBus, revBus, compBus, delBus, satBus, amp=1|
	var sig = In.ar(inBus, 2) * amp;

	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "multi send tap L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "multi send tap R");

	Out.ar(revBus, sig);
	Out.ar(compBus, sig);
	Out.ar(delBus, sig);
	Out.ar(satBus, sig);
}).add;

// FX reverb
SynthDef(\fxReverb, { |inBus=0, outBus=0, ctrlBus, room=0.9, damp=0.5, mix=1.0|
	var in, sig;
	in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
	sig = FreeVerb2.ar(in[0], in[1], mix, room, damp); // always wet

	// Poll.kr(Impulse.kr(0.2), Amplitude.kr(sig[0]), label: "rev tap L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "rev tap R");

	Out.ar(outBus, sig);
}).add;

// FX compression
SynthDef(\fxComp, { |inBus=0, outBus=0, ctrlBus, thresh=0.4, slopeAbove=0.3, clamp=0.01, relax=0.3|
	var in, sig;
	in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
	sig = Compander.ar(
		in, in,
		thresh,        // threshold
		1,             // slopeBelow (no expansion)
		slopeAbove,    // slopeAbove (compression)
		clamp, relax
	);
	Out.ar(outBus, sig);
}).add;

// FX delay
SynthDef(\fxDelay, { |inBus=0, outBus=0, ctrlBus, maxDelay=2.0, delayTime=0.5, feedback=0.3|
	var in, sig;
	in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
	sig = CombC.ar(in, maxDelay, delayTime, feedback * maxDelay);
	Out.ar(outBus, sig);
}).add;

// FX saturation
SynthDef(\fxSaturator, { |inBus=0, outBus=0, ctrlBus, drive=1.1|
	var in, sig;
	in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
	sig = tanh(in * drive);
	Out.ar(outBus, sig);
}).add;


// Master fader (with final FX)
SynthDef(\masterFader, { |inBus=0, outBus=0, ctrlBus|
	var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

	// Global processing
	sig = Compander.ar(sig, sig, thresh: 0.4, slopeBelow: 1, slopeAbove: 0.3, clampTime: 0.01, relaxTime: 0.3);
	sig = FreeVerb2.ar(sig[0], sig[1], mix: 0.1, room: 0.7, damp: 0.5);
	sig = Limiter.ar(sig, 0.9);

	// Poll.kr(Impulse.kr(1), Amplitude.kr(sig[0]), label: "Master tap L");
	// Poll.kr(Impulse.kr(1), Amplitude.kr(sig[1]), label: "Master tap R");
	Poll.kr(Impulse.kr(0.05), Amplitude.kr(sig[1]), label: "[Mix] Mixer active at amplitude: ");

	Out.ar(outBus, sig);
}).add;


// --- Instrument Synths ---

// Pad Synths
SynthDef(\padSynth, { |out = 0, freq = 440, amp = 0.2, gate = 1, pan = 0|
	var osc, env, filt, mod, rev, snd;

	// Live parameters from mapped buses
	var ffreq    = In.kr(~paramBuses[\filterCutoff]); // cutoff frequency (mapped from brightness)
	var rq       = In.kr(~paramBuses[\rq]);           // filter resonance (brightness shaping)
	var modRate  = In.kr(~paramBuses[\modRate]);      // LFO rate (variability → tempo-synced)
	var modDepth = In.kr(~paramBuses[\modDepth]);     // LFO depth (warmth → detune/mod)
	var revMix   = In.kr(~paramBuses[\revMix]);       // reverb wet/dry (density shaping)
	var atk      = In.kr(~paramBuses[\atk]);          // attack time (rhythmicity shaping)
	var rel      = In.kr(~paramBuses[\rel]);          // release time (rhythmicity shaping)

	// Saw per voice
	osc = Saw.ar(freq);

	// Filter modulation
	mod = SinOsc.kr(modRate, 0, modDepth, ffreq);
	filt = RLPF.ar(osc, mod, rq);
	filt = tanh(filt * 0.8); // gentle analog-style limiting


	// Envelope
	env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

	// Reverb to push into space
	rev = FreeVerb.ar(filt * env, mix: revMix, room: 0.9, damp: 0.7);

	snd = rev * amp;

	Out.ar(out, Pan2.ar(snd, pan));
}).add;

// Dark Pad
SynthDef(\darkPad, { |out=0, freq=220, amp=0.1, gate=1|
	var osc, sub, mix, lfo, env, filt, dist, crush, chorus, rev;

	// Live parameters from buses
	var darkPadSub  = In.kr(~paramBuses[\darkPadSub]);    // sub level
	var darkPadBits = In.kr(~paramBuses[\darkPadBits]);   // bit depth
	var crushMix    = In.kr(~paramBuses[\crushMix]);      // bitcrush amount
	var drive       = In.kr(~paramBuses[\drive]);         // distortion drive
	var distAmt     = In.kr(~paramBuses[\distAmt]);       // distortion wet/dry
	var ffreq       = In.kr(~paramBuses[\darkPadCutoff]); // filter cutoff
	var rq          = In.kr(~paramBuses[\rq]);            // filter resonance
	var revMix      = In.kr(~paramBuses[\revMix]);        // reverb mix
	var atk         = In.kr(~paramBuses[\atk]);           // attack
	var rel         = In.kr(~paramBuses[\rel]);           // release

	// 2 saws slightly detuned (already thick enough)
	osc = Saw.ar(freq);

	// add a deep sub layer (square or sine one octave down)
	sub = Pulse.ar(freq/2, 0.4) * darkPadSub;

	// mix and balance
	mix = Mix([osc, sub]) * 0.3;

	// slow LFO for cutoff movement
	lfo = SinOsc.kr(0.03).range(0.4, 1.2);

	// dark low-pass filter (base cutoff not tied to pitch)
	filt = RLPF.ar(mix, (ffreq * lfo).clip(100, 2000), rq);

	// distortion: waveshaper for nasty harmonics
	dist = XFade2.ar(tanh(filt * (1 + drive * 10)), filt.clip2, distAmt * 2 - 1);
	dist = HPF.ar(dist, 80); // clean up mud


	// bitcrush for extra electronic grit
	crush = XFade2.ar(dist, Decimator.ar(dist, 44100, darkPadBits), crushMix * 2 - 1); // bit resolution

	// stereo spread / chorus
	chorus = Splay.ar([
		DelayC.ar(crush, 0.03, LFNoise1.kr(0.15).range(0.001, 0.02)),
		DelayC.ar(crush, 0.03, LFNoise1.kr(0.15).range(0.002, 0.025))
	], spread: 0.8);

	// envelope
	env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

	// optional dark reverb tail
	rev = FreeVerb.ar(chorus * env, mix: revMix, room: 0.7, damp: 0.3);
	rev = HPF.ar(rev, 80);


	Out.ar(out, rev * amp);
}).add;

// Bass Synth
SynthDef(\bassSynth, { |out = 0, freq = 60, amp = 0.3, gate = 1, pan = 0|
	var osc, sub, mix, filt, env;

	// Live parameters from mapped buses
	var atk     = In.kr(~paramBuses[\atk]);          // attack (rhythmicity)
	var rel     = In.kr(~paramBuses[\rel]);          // release (rhythmicity)
	var ffreq   = In.kr(~paramBuses[\filterCutoff]); // filter cutoff (brightness)
	var rq      = In.kr(~paramBuses[\rq]);           // resonance (brightness shaping)
	var subOct  = In.kr(~paramBuses[\sub]);          // sub level (warmth/density)
	var drive   = In.kr(~paramBuses[\drive]);        // drive/distortion (warmth)

	// Main osc: pulse wave for bass body
	osc = Pulse.ar(freq, 0.45, 0.8);

	// Sub osc: one octave below
	sub = SinOsc.ar(freq / 2, 0, subOct);

	// Mix and drive
	mix = (osc + sub).tanh * (1 + drive);

	// Filter for roundness
	filt = RLPF.ar(mix, ffreq, rq);

	// Envelope for shape
	env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

	// Output
	Out.ar(out, Pan2.ar(filt * env * amp, pan));
}).add;

// Drone Synth
SynthDef(\droneSynth, { |out = 0, freq = 55, amp = 0.2, pan = 0, gate = 1|
	var osc, detuneFactors, detuned, lfo, filt, env, rev, snd, mid, side, stereo;

	// Live parameters from mapped buses
	var droneDetune = In.kr(~paramBuses[\droneDetune]);  // per-voice detune (warmth)
	var lfoRate     = In.kr(~paramBuses[\droneLfoRate]); // very slow wobble (variability)
	var lfoDepth    = In.kr(~paramBuses[\detune]);       // wobble depth (warmth/variability)
	var ffreq       = In.kr(~paramBuses[\filterCutoff]); // filter cutoff (brightness)
	var rq          = In.kr(~paramBuses[\rq]);           // resonance (brightness shaping)
	var revMix      = In.kr(~paramBuses[\revMix]);       // reverb blend (density)
	var atk         = In.kr(~paramBuses[\atk]);          // attack (rhythmicity)
	var rel         = In.kr(~paramBuses[\rel]);          // release (rhythmicity)

	// store the multipliers first
	detuneFactors = Array.fill(4, { LFNoise1.kr(0.1).range(1 - droneDetune, 1 + droneDetune) });

	// now make the oscillators
	detuned = Mix.fill(4, { |i| Saw.ar(freq * detuneFactors[i])});

	// detuneFactors.do { |df, i| Poll.kr(Impulse.kr(1), df, "Drone detune factor " ++ i)};

	// slow LFO for movement (amplitude + subtle freq wobble)
	lfo = SinOsc.kr(lfoRate).range(1 - lfoDepth, 1 + lfoDepth);

	// resonant lowpass → shaping brightness
	filt = RLPF.ar(detuned, ffreq * lfo, rq);

	// long envelope (ASR)
	env = EnvGen.kr(Env.asr(5, 1, 10), gate, doneAction:2);

	// space
	rev = FreeVerb.ar(filt, mix: revMix, room: 0.9, damp: 0.7);

	// Haas trick
	stereo = [rev * 0.7, DelayC.ar(rev, 0.02, 0.005)];

	// Mid/Side encode
	mid  = (stereo[0] + stereo[1]) * 0.5;
	side = (stereo[0] - stereo[1]) * 0.5;

	// no mid
	stereo = [side, 1 - side];

	Out.ar(out, stereo * env * amp);
}).add;

// Harp Synth
SynthDef(\harpPluck, { |out = 0, freq = 440, decay=4, coef=0.3, revRoom=0.8, revDamp=0.5, amp = 0.2, pan = 0, gate = 1|
	var excEnv, exciter, string, body, panSig, rev, ampEnv, snd;

	// Live parameters from mapped buses
	var revMix  = In.kr(~paramBuses[\revMix]);     // reverb blend (density/space)
	var atk     = In.kr(~paramBuses[\atk]);        // attach mapping from rhythmicity
	var rel     = In.kr(~paramBuses[\rel]);        // release mapping from rhythmicity

	// Short exciter burst (noise impulse)
	excEnv = EnvGen.kr(Env.perc(0.001, 0.03, 1), doneAction: 0);
	exciter = PinkNoise.ar * excEnv;

	// Karplus-Strong string
	string = Pluck.ar(
		in: exciter,
		trig: 1,
		maxdelaytime: 0.1,
		delaytime: 1/freq,
		decaytime: decay,
		coef: coef
	);

	// Resonant body filter
	body = LPF.ar(string, freq * 4);

	// Pan
	pan = Pan2.ar(body, pan);

	// Reverb
	rev = FreeVerb.ar(pan, mix: revMix, room: revRoom, damp: revDamp);

	// Amplitude envelope controls full synth lifetime
	ampEnv = EnvGen.kr(
		Env.linen(0.001, decay, 0.1, 1),
		doneAction: 2
	);

	// Saturation + final scaling
	snd = (rev * 5).tanh * ampEnv * amp;

	Out.ar(out, snd);
}).add;

// Glass Arp Synth
SynthDef(\glassArp, { |out = 0, freq = 440, amp = 0.2, noiseLength=0.3, gate = 1, pan = 0|
	var exc, excAmp, resonAmp, env, reson, partials, amps, rels, rev, snd, noise;

	// Live parameters from mapped buses
	var atk         = In.kr(~paramBuses[\atk]);         // attack → rhythmicity
	var rel         = In.kr(~paramBuses[\rel]);         // release → rhythmicity
	var bright      = In.kr(~paramBuses[\bright]);      // brightness → partial emphasis
	var revMix      = In.kr(~paramBuses[\revMix]);      // reverb mix

	// Air
	noise = tanh(PinkNoise.ar(noiseLength) * 2) * 0.5;
	noise = FreeVerb.ar(noise, mix: revMix - 0.2, room: 0.6, damp: 0.7);

	// Exciter: short burst of noise + sine
	exc = noise + SinOsc.ar(freq, 0, 0.3);

	// Envelope for exciter
	env = EnvGen.kr(Env.perc(atk, rel), gate, doneAction: 2);

	// Resonant filter "glass tone" (narrow bandpass)
	partials = [1,   2,   3,   4,   5.001, 6,    20/3];
	amps =     [1.0, 0.5, 0.4, 0.2, 0.1,   0.05, 0.01];
	rels =     [2.0, 1.3, 1.2, 0.7, 0.3,   0.4,  0.25];
	reson = tanh(Mix.fill(partials.size, { |i|
		Ringz.ar(exc, freq * partials[i], rels[i], amps[i])
	}) * 0.002);

	// Brightness control (emphasize high partials)
	reson = reson * bright + LPF.ar(reson, 2000 * bright);

	// Reverb for space
	rev = FreeVerb.ar(reson * env, mix: revMix - 0.3, room: 0.9, damp: 0.4);

	// Pan & output
	snd = Pan2.ar(rev, pan, amp);

	Out.ar(out, snd);
}).add;

// Bell Synth
SynthDef(\bell, { |out = 0, freq = 220, amp = 0.3, pan = 0, gate = 1, revRoom=1, revDamp=0.7|
	var snd, env, partials, freqs, amps, decays, body, rev;

	// Live parameters from mapped buses
	var lpfFactor = In.kr(~paramBuses[\lpfFactor]);   // low-pass factor → warmth/brightness
	var revMix    = In.kr(~paramBuses[\revMix]);      // reverb mix → density
	var atk       = In.kr(~paramBuses[\atk]);         // attack (percussive vs swelling)
	var rel       = In.kr(~paramBuses[\rel]);         // release time

	// main envelope (long exponential fade, gated)
	env = EnvGen.kr(Env.asr(0.01, 1, 6, curve: -10), gate, doneAction:2);

	// inharmonic partial ratios (bell-like spectra)
	freqs = freq * [0.5, 0.66, 1   , 2   , 2.73, 3.01, 4.05, 4.97, 6.01, 7.32]; // slightly weird ratios
	amps   =       [0.7, 0.5 , 1.0 , 0.5 , 0.03, 0.2 , 0.15, 0.1 , 0.05, 0.03]; // balance of partials
	decays =       [3  , 2   , 6   , 2   , 0.4 , 1   , 0.5 , 1   , 0.7 , 0.6 ]; // longer ring for low partials

	// sum partials with individual decays
	partials = Mix.fill(freqs.size, { |i|
		SinOsc.ar(freqs[i]) *
		EnvGen.kr(Env.perc(0.001, decays[i]), doneAction: 0) * amps[i]
	});

	// slight attack "clang" using FM
	snd = partials + (SinOsc.ar(freq * 1.5, mul: 0.2) * Decay2.kr(Impulse.kr(0), 0.005, 0.2));

	// soft low-pass shaping
	body = LPF.ar(snd, freq * lpfFactor);

	// stereo spread + reverb
	body = Pan2.ar(body, pan, amp);
	rev  = FreeVerb.ar(body, mix:revMix, room: revRoom, damp:revDamp);

	// gentle saturation for fullness
	Out.ar(out, (rev * 3).tanh * env);
}).add;


// Textrure Synths

// Sea Sound
SynthDef(\seaSynth, { |out = 0, amp = 0.3, waveDepth = 0.4 , pan = 0, sus = 2, atk = 1, rel = 4, gate = 1|
	var src, mod, filt, env, rev, waveLFO;

	// Live parameters from mapped buses
	var ffreq     = In.kr(~paramBuses[\filterCutoff]);   // filter cutoff ← brightness
	var rq        = In.kr(~paramBuses[\rq]);             // resonance ← variability
	var modRate   = In.kr(~paramBuses[\modRate]);        // filter wobble rate ← rhythmicity
	var modDepth  = In.kr(~paramBuses[\modDepth]);       // filter wobble depth ← variability
	var pinkAmt   = In.kr(~paramBuses[\noisePink]);      // pink noise share ← warmth
	var whiteAmt  = In.kr(~paramBuses[\noiseWhite]);     // white noise share ← brightness
	var revMix    = In.kr(~paramBuses[\revMix]);         // reverb mix ← density
	var waveRate  = In.kr(~paramBuses[\droneLfoRate]);   // slow wave swell rate ← variability

	// Noise source (warm)
	src = PinkNoise.ar(pinkAmt) + WhiteNoise.ar(whiteAmt);

	// LFO modulating filter cutoff
	mod = SinOsc.kr(modRate, Rand(0, 2pi), modDepth, ffreq);

	// Resonant low-pass filter
	filt = RLPF.ar(src, mod, rq);

	// Wave motion LFO
	waveLFO = SinOsc.kr(waveRate, Rand(0, 2pi)).range(1 - waveDepth, 1);

	// ASR envelope
	env = EnvGen.kr(Env.linen(atk, sus, rel, curve: -3), doneAction: 2);

	// Reverb space
	rev = FreeVerb.ar(filt * env * amp * waveLFO, mix: revMix, room: 0.9, damp: 0.7);

	Out.ar(out, Pan2.ar(rev, pan));

}).add;

// Vinyl Crackle
SynthDef(\vinylCrackle, { |out = 0, amp=0.1, dustDensity=4, lpFreq=4000, hpFreq=800, rumbleFreq=50, wowRate=0.33, wowDepth=0.1|
	var trig, env, src, filtered, grainAmp, grainRel, saturated;
	var rumble, hum, rumbleLevel, humLevel, wow, mix, panned;

	// Live parameters from buses
	rumbleLevel = In.kr(~paramBuses[\rumbleLevel]);
	humLevel    = In.kr(~paramBuses[\humLevel]);

	// Crackles
	trig = Dust.kr(dustDensity);
	grainAmp = TRand.kr(0.1, 1.0, trig);      // per-grain random amp
	grainRel = TRand.kr(0.003, 0.005, trig);  // per-grain random length
	env = EnvGen.kr(Env.perc(0.001, grainRel), trig) * grainAmp;
	src = PinkNoise.ar(amp) * env;
	filtered = HPF.ar(LPF.ar(src, lpFreq), hpFreq);
	saturated = tanh(filtered * 5);

	// Mechanical rumble (low brown noise)
	rumble = LPF.ar(BrownNoise.ar(rumbleLevel), rumbleFreq);

	// Electrical hum (fundamental + harmonics)
	hum = (SinOsc.ar(50) + 0.5 * SinOsc.ar(100) + 0.25 * SinOsc.ar(150)) * humLevel * 0.08;

	// Wow/flutter (slow amplitude wobble)
	wow = SinOsc.kr(wowRate, 0, wowDepth, 1);

	// Mix & output
	mix = (saturated + rumble + hum) * wow;
	panned = Pan2.ar(mix, LFNoise1.kr(5).range(-0.5, 0.5));
	Out.ar(out, panned);
}).add;

// Rain Sound
SynthDef(\rainTexture, { |out = 0, densFactor = 1, hp=400, lp=6000, amp=0.2|
	var trigNear, trigFar, nearDrops, farDrops, noiseBed, rain, rev;
	var densFar, densNear, revMix, rq, noiseAmp;

	// Live parameters from buses
	rq         = In.kr(~paramBuses[\rq]);          // resonance shaping
	noiseAmp   = In.kr(~paramBuses[\noiseAmp]);    // background noise balance
	revMix     = In.kr(~paramBuses[\revMix]);      // wet/dry reverb

	densNear = 10 * densFactor;
	densFar  = 100 * densFactor;

	// 1. NEARBY drops (louder, fewer)
	trigNear = Dust.kr(densNear); // sparser
	nearDrops = Decay2.kr(trigNear, 0.001, TRand.kr(0.05, 0.15, trigNear)) * PinkNoise.ar(0.6);
	nearDrops = BPF.ar(nearDrops,TExpRand.kr(700, 1500, trigNear), 0.5);

	// Pan hardish sides
	nearDrops = Pan2.ar(nearDrops, Select.kr(TRand.kr(0,1,trigNear).round, [TRand.kr(-1.0, -0.6, trigNear), TRand.kr(0.6, 1.0, trigNear)]));

	// 2. FAR drops (many, quieter)
	trigFar = Dust.kr(densFar); // denser
	farDrops = Decay2.kr(trigFar, 0.002, TRand.kr(0.05, 0.1, trigFar)) * BrownNoise.ar(0.3);
	farDrops = BPF.ar(farDrops, TExpRand.kr(2000, 3000, trigFar), 0.4);

	// Spread narrower, closer to center
	farDrops = Pan2.ar(farDrops, TRand.kr(-0.6, 0.6, trigFar));

	// 3. Background noise "rain sheet"
	noiseBed = WhiteNoise.ar(0.2) * 0.5
	+ PinkNoise.ar(0.2)  * 0.3
	+ BrownNoise.ar(0.2) * 0.2;
	noiseBed = HPF.ar(LPF.ar(noiseBed, lp), hp) * noiseAmp;
	noiseBed = Splay.ar(noiseBed, 0.3); // stereo spread

	// Mix all layers
	rain = nearDrops + farDrops + noiseBed;

	// Reverb for space
	rev = FreeVerb.ar(rain, mix: 0.2, room: 0.9, damp: 0.9);

	Out.ar(out, rev * amp);
}).add;


// --- Control Synths ---

// Control-bus ramp (for faders/sends/master etc.)
SynthDef(\fade, { |bus, start = 0, end = 1, dur = 8, curve = -0.5|
	// protect against zero values in exponential fades
	var safeStart = start.max(0.0001);
	var safeEnd   = end.max(0.0001);

	// envelope to create the fade
	var ctl = EnvGen.kr(Env([start, end], [dur], curve), doneAction:2);

	ReplaceOut.kr(bus, ctl);

	// Poll.kr(Impulse.kr(1), ctl, label: "fade ctl");  // debug
}).add;
)