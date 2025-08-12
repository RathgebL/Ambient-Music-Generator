(
// ==================================================
// AMBIENT GENERATOR STARTUP (evaluate this whole block)
// ==================================================

s.reboot;

s.waitForBoot {

	// --- Mixing Bus ---

	~fxBus = Bus.audio(s, 2);

	SynthDef(\globalFX, { |in=0, mix=0.3, room=0.9, damp=0.5|
		var dry, wet, snd;
		dry = In.ar(in, 2);
		wet = FreeVerb.ar(dry, mix, room, damp);
		snd = dry + wet;
		Out.ar(0, snd);
	}).add;
	s.sync;

	~fxSynth = Synth(\globalFX, [\in, ~fxBus]);

	// Reverb settings
	~fxSynth.set(\mix, 0.5);    // dry/wet mix (0.0 = dry, 1.0 = fully wet)
	~fxSynth.set(\room, 0.9);   // room size (0.0 = small, 1.0 = big hall)
	~fxSynth.set(\damp, 0.3);   // damping (0.0 = bright, 1.0 = muffled)



	// --- Parameter Mapping Engine ---

	/*
	warmth from cold (digital, thin) to warm (analog, fat) -> detuneAmt
	brightness from dark (filtered, muffled) to bright (open) -> filter cutoff
	density from sparse (few voices) to dense (many voices) -> number of voices
	variability from static to highly changing -> modulation speed
	rhythmicity from fluid/free to rhythmic/structured -> pulse emphasis
	*/

	// Input parameter
	~parameters = IdentityDictionary[
	    \warmth -> 0.5,
	    \brightness -> 0.5,
		\density -> 0.5,
	    \variability -> 0.5,
	    \rhythmicity -> 0.5
	];

	// Parameter mapping
	~mapRange = { |val, inMin=0, inMax=1, outMin=0, outMax=1|
		((val - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
	};

	~parameterMappings = (
		detune:       { ~mapRange.(~parameters[\warmth],      0, 1, 0.01, 1.0) },
		filterCutoff: { ~mapRange.(~parameters[\brightness],  0, 1, 800, 8000) },
		numVoices:    { ~mapRange.(~parameters[\density],     0, 1, 1, 8).round },
		modSpeed:     { ~mapRange.(~parameters[\variability], 0, 1, 0.01, 2.0) },
		pulseDiv:     { ~mapRange.(~parameters[\rhythmicity], 0, 1, 0.5, 4).round }
	);

	// Parameter check & limiter
	~setParam = { |key, val|
		if(~parameters.isNil) {
	        "~parameters was nil; reinitializing.".warn;
	        ~parameters = IdentityDictionary.new;
	    };
		~parameters[key] = val.clip(0.0, 1.0);
	};

	// Mapping info
	~showMappedParams = {
		"Mapped Parameter Values:".postln;
		~parameterMappings.keysValuesDo { |key, func|
			"%: %".format(key, func.()).postln;
		};
	};



	// --- Pad SynthDef ---

	SynthDef(\padVoice, {
		| out=0, freq=440, amp=0.3, detune=0.5, lforate=0.1, cutoff=3000, pan=0.0, gate=1 |

		var freqs, snd, lfoAmp, lfoCutoff, env, pans;

		// Detuned freqs
		freqs = [
			freq,
			freq * (1 + (detune * 0.01)),
			freq * (1 - (detune * 0.01))
		];

		// Per-voice subtle pan offsets
		pans = [-0.2, 0, 0.2];

		// Each voice = Saw + Sine blend
		snd = Mix.fill(3, { |i|
			var phaseOffset = Rand(0, 2pi);  // add randomness
			var saw = Saw.ar(freqs[i]);
			var sine = SinOsc.ar(freqs[i], phaseOffset);
			var mix = XFade2.ar(saw, sine, -0.3);  // tilt toward saw
			Pan2.ar(mix, pans[i]);  // stereo spread
		});

		// Gentle amplitude flutter
		lfoAmp = SinOsc.kr(lforate, Rand(0, 2pi), 0.1, 0.9);
		snd = snd * lfoAmp;

		// Cutoff modulation
		lfoCutoff = SinOsc.kr(0.03, 0, 200, cutoff);  // ±200Hz around cutoff
		snd = LPF.ar(snd, lfoCutoff);

		// Envelope
		env = EnvGen.kr(Env.asr(4, 1, 6), gate, doneAction:2);
		snd = snd * env * amp;

		// Output (route to FX bus from the caller)
		Out.ar(out, snd);
	}).add;
	s.sync;



	// --- Pad Trigger Functions ---

	~playPad = { |note=60, dur=10, pan=0.0|
		var freq = note.midicps;
		Synth(\padVoice, [
			\out, ~fxBus,
			\freq, freq,
			\amp, 0.2,
			\detune, ~parameterMappings[\detune].(),
			\cutoff, ~parameterMappings[\filterCutoff].(),
			\lforate, ~parameterMappings[\modSpeed].(),
			\pan, pan
		]);
	};

	~playPadChord = { |notes, panSpread = 0.6, stagger = 0.0|
		var nVoices, basePan, panStep;
		notes = notes ? [60, 64, 67];
		nVoices = notes.size;
		basePan = 0 - panSpread;
		panStep = (panSpread * 2) / (nVoices - 1);

		Routine({
			notes.do { |note, i|
				~playPad.(note, 10, basePan + (i * panStep));
				stagger.wait;
			};
		}).play;
	};

	~restartFX = {
    ~fxSynth = Synth(\globalFX, [\in, ~fxBus]);
    ~fxSynth.set(\mix, 0.5, \room, 0.9, \damp, 0.3);
    "FX chain restarted.".postln;
	};

	"Ambient system ready. Try: ~showMappedParams.();  ~playPadChord.([57,60,65,69], 0.8, 0.5);".postln;
};
)


// --- Checks ---
~parameters.postln;    // should NOT be nil
~fxBus.postln;         // should be a Bus
~fxSynth.isRunning.postln; // often true; at least ~fxSynth is a Synth


// --- Usage ---
~setParam.(\warmth, 0.8);
~setParam.(\brightness, 0.3);
~showMappedParams.();
~playPadChord.([57, 60, 65, 69], 0.8, 0.5); // Play a pad chord
~restartFX.(); // To be able to play again after cmd + .


