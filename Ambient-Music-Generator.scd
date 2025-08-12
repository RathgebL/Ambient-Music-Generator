(
// -------------------------
// AMBIENT GENERATOR STARTUP
// -------------------------

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


	// --- FX utils ---
	// Groupings
	~srcGroup = Group.head(s);
	~fxGroup  = Group.tail(s);

	// (Re)create FX synth
	~restartFX = {
		try { ~fxSynth.free } { }; // free old one if present
		~fxSynth = Synth(\globalFX, [\in, ~fxBus], target: ~fxGroup, addAction: \addToTail);
		~fxSynth.set(\mix, 0.5, \room, 0.9, \damp, 0.3);
		"FX chain restarted.".postln;
	};

	// Ensure FX exists and is running
	~ensureFX = {
		if(~fxSynth.isNil or: { ~fxSynth.isRunning.not }) {
			"~fxSynth was missing; restarting…".postln;
			~restartFX.();
		} {
			"FX chain OK.".postln;
		};
	};

	// Install Cmd+. handler (defer so it runs after the stop)
	if(~fxCmdHookAdded != true) {
		CmdPeriod.add({ { ~restartFX.() }.defer });
		~fxCmdHookAdded = true;
	};

	// Make sure FX is up now
	~restartFX.();



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

	// Re‑evaluate this SynthDef
	SynthDef(\padVoice, {
		| out=0, freq=440, amp=0.3, detune=0.5, lforate=0.1, cutoff=3000, pan=0.0, gate=1, atk=3, rel=6 |

		var freqs, snd, lfoAmp, lfoCutoff, env, pans;

		freqs = [ freq, freq * (1 + detune * 0.01), freq * (1 - detune * 0.01) ];
		pans  = [-0.2, 0, 0.2];

		snd = Mix.fill(3, { |i|
			var saw  = Saw.ar(freqs[i]);
			var sine = SinOsc.ar(freqs[i], Rand(0, 2pi));
			var mix  = XFade2.ar(saw, sine, -0.3);
			Pan2.ar(mix, pans[i]);
		});

		lfoAmp    = SinOsc.kr(lforate, Rand(0, 2pi), 0.1, 0.9);
		snd       = snd * lfoAmp;

		lfoCutoff = SinOsc.kr(0.03, 0, 200, cutoff);
		snd       = LPF.ar(snd, lfoCutoff);

		// NOTE: ASR envelope with gate; we can close it with \gate, 0
		env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction:2);
		snd = snd * env * amp;

		Out.ar(out, snd);
	}).add; s.sync;




	// --- Pad Trigger Functions ---

	~playPad = { |note=60, dur=10, pan=0.0|
		var freq = note.midicps;
		~ensureFX.();
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

	// Keep handles to running pads
	~activePads = ~activePads ?? { List.new };

	~playPad = { |note=60, pan=0.0|
		var sy;
		~ensureFX.();
		sy = Synth(\padVoice, [
			\out, ~fxBus,
			\freq, note.midicps,
			\amp, 0.2,
			\detune, ~parameterMappings[\detune].(),
			\cutoff, ~parameterMappings[\filterCutoff].(),
			\lforate, ~parameterMappings[\modSpeed].(),
			\pan, pan,
			\atk, 2.5,   // gentle fade‑in
			\rel, 5.0    // gentle fade‑out
		], target: ~srcGroup, addAction: \addToHead);
		~activePads.add(sy);
		sy
	};

	// Array of Synths
	~playPadChordSync = { |notes, panSpread = 0.6|
		var n = notes.size, basePan = 0 - panSpread, step = (panSpread * 2) / (n - 1);
		notes.collect { |note, i|
			~playPad.(note, basePan + (i * step))
		}
	};


	~restartFX = {
    ~fxSynth = Synth(\globalFX, [\in, ~fxBus]);
    ~fxSynth.set(\mix, 0.5, \room, 0.9, \damp, 0.3);
    "FX chain restarted.".postln;
	};

	"Ambient system ready. Try: ~showMappedParams.();  ~playPadChord.([57,60,65,69], 0.8, 0.5);".postln;
};
)

(
// --------------
// HARMONY ENGINE
// --------------

// --- Scale library (7-note modes)
~scales = (
    ionian:     [0,2,4,5,7,9,11],   // major
    dorian:     [0,2,3,5,7,9,10],
    phrygian:   [0,1,3,5,7,8,10],
    lydian:     [0,2,4,6,7,9,11],
    mixolydian: [0,2,4,5,7,9,10],
    aeolian:    [0,2,3,5,7,8,10],   // natural minor
    locrian:    [0,1,3,5,6,8,10]
);

// note names for convenience
~noteNames = (C:0, Cis:1, Des:1, D:2, Dis:3, Es:3, E:4, F:5, Fis:6, Ges:6, G:7, Gis:8, As:8, A:9, Ais:10, B:10, H:11);

// choose scale by name
~setScale = { |name=\ionian|
    var pcs = ~scales[name];
    if(pcs.isNil) { ("Unknown scale: " ++ name).warn } { ~scalePcs = pcs; };
    ("Scale set to " ++ name ++ " → " ++ ~scalePcs).postln;
};

// choose tonic by note name + octave
~setKey = { |name=\C, octave=4|
    var pc = ~noteNames[name] ? 0;
    ~keyMidi = (octave * 12) + pc;
    ("Key set to " ++ name ++ octave ++ " (MIDI " ++ ~keyMidi ++ ")").postln;
};



// --- Scale & pitch helpers ---

~scalePcs = [0, 2, 4, 5, 7, 9, 11];   // major/Ionian (change if you like)
~keyMidi  = 60;                        // C4 as key center

// Scale to MIDI mapping
~degreeToMidi = { |degree, octave=4, rootMidi|
    var n, deg0, wrap, oct, rm;

    rm = rootMidi ?? { ~keyMidi };
    n    = (~scalePcs.size).max(1);
    deg0 = degree - 1;
    wrap = deg0 % n;
    oct  = (deg0 / n).floor;
    rm + ~scalePcs[wrap] + (octave + oct - 4) * 12
};

// Build a tertian chord from scale degree (triad..5-note), optionally add 9th
~chordFromDegree = { |degree, size=4, add9Prob=0.0, octave=4|
    var steps = [0, 2, 4, 6, 8];
    var count = size.asInteger.clip(1, steps.size);  // <-- force integer & clamp
    var degs  = steps.copyRange(0, count - 1);       // <-- safe slice
    var midis = degs.collect { |s| ~degreeToMidi.(degree + s, octave) };

    if(1.0.rand < add9Prob and: { count <= 4 }) {
        midis = midis.add(~degreeToMidi.(degree + 8, octave+1));  // add 9th
    };
    midis
};

// Bring chord into register & optionally invert
~voiceSpread = { |midiNotes, center=60, spread=24|
    midiNotes.collect { |n|
        var x = n;
        while { x < (center - spread) } { x = x + 12 };
        while { x > (center + spread) } { x = x - 12 };
        x
    }.sort
};

// Do N inversions (move lowest note up an octave)
~invert = { |notes, times=0|
    var n = notes.copy;
    times.do { n = n.add(n.removeAt(0) + 12) };
    n
};

// --- Markov harmony (degrees 1..7) ---
~degreeMarkov = (
    1: [[4,0.30],[5,0.30],[6,0.10],[2,0.20],[3,0.10]],
    2: [[5,0.40],[7,0.20],[1,0.40]],
    3: [[6,0.40],[4,0.20],[2,0.20],[1,0.20]],
    4: [[5,0.40],[2,0.20],[1,0.40]],
    5: [[1,0.50],[6,0.20],[4,0.20],[3,0.10]],
    6: [[2,0.30],[4,0.20],[5,0.30],[1,0.20]],
    7: [[1,0.70],[3,0.30]]
);

~nextDegree = { |cur|
    var pairs = ~degreeMarkov[cur] ? [[1,1.0]];
    var total = pairs.sum { |p| p[1] };
    var r = total.rand, acc = 0.0;
    pairs.do { |p|
        acc = acc + p[1];
        if(r < acc) { ^p[0] };
    };
    pairs.last[0] // fallback
};

// --- Parameter-to-music mappings ---
~chordHoldBeats = {~mapRange.(~parameters[\rhythmicity] ? 0.5, 0, 1, 6.0, 1.5)}; // rhythmicity: 0 (floaty) --> 6 beats, 1 (rhythmic) --> 1.5 beats

~chordSize = {(~mapRange.(~parameters[\density] ? 0.5, 0, 1, 3, 5).round.clip(3, 5).asInteger)}; // density: 0..1 --> 3..5 notes

~invAmount = {(~mapRange.(~parameters[\variability] ? 0.5, 0, 1, 0, 3).round.asInteger)}; // variability controls inversion amount (0..3)

~add9Prob = {~mapRange.(~parameters[\variability] ? 0.5, 0, 1, 0.0, 0.6)}; // variability controls chance of 9th added

~targetCenter = {(60 + ~mapRange.(~parameters[\brightness] ? 0.5, 0, 1, -12, 12)).round}; // brightness lifts register (C3..C5 approx)

~targetSpread = {(16 + ~mapRange.(~parameters[\warmth] ? 0.5, 0, 1, 0, 14)).round}; // warmth widens spread (16..30 semitones)

// --- Chord engine control (clock scheduler, no Routines/Tasks) ---

~chordClock = ~chordClock ? TempoClock.default;
~chordEngineOn = ~chordEngineOn ? false;
~lastChordSynths = ~lastChordSynths ?? { Array.newClear(0) };

// One step; schedules the next
~chordStep = { |clock|
    var deg, size, inv, center, spread, hold, chord, synths;

    if(~chordEngineOn.not) { ^nil };

    deg    = ~currentDegree ? 1;
    size   = ~chordSize.().asInteger.clip(3, 5);
    inv    = ~invAmount.().asInteger.clip(0, 3);
    center = ~targetCenter.();
    spread = ~targetSpread.();
    hold   = (~chordHoldBeats.()).max(0.05);

    chord  = ~chordFromDegree.(deg, size, ~add9Prob.(), 4);
    chord  = ~invert.(chord, inv);
    chord  = ~voiceSpread.(chord, center, spread);

    // 1) spawn & keep handles
    synths = ~playPadChordSync.(chord, 0.7);
    ~lastChordSynths = synths;

    // 2) schedule this chord's release
    clock.sched(hold, {
        synths.do { |sy| if(sy.notNil and: { sy.isRunning }) { sy.set(\gate, 0) } };
        nil
    });

    // 3) move to next degree and schedule next step
    ~currentDegree = ~nextDegree.(deg);
    clock.sched(hold, { ~chordStep.(clock); nil });

    nil
};

~startChordEngine = {
    ~ensureFX.();
    if(~chordEngineOn) { "Chord engine already running; ignoring.".postln; ^nil };
    ~chordEngineOn = true;
    ~chordStep.(~chordClock);
    "Chord engine started.".postln;
};

~stopChordEngine = {
    ~chordEngineOn = false;
    // fade whatever is currently playing
    (~lastChordSynths ? []).do { |sy| if(sy.notNil and: { sy.isRunning }) { sy.set(\gate, 0) } };
    "Chord engine stopped (fading current chord).".postln;
};
)

// --- Checks ---
~parameters.postln;    // should NOT be nil
~fxBus.postln;         // should be a Bus
~fxSynth.isRunning.postln; // often true; at least ~fxSynth is a Synth


// --- Usage ---
~setParam.(\warmth, 0.8);
~setParam.(\brightness, 0.3);
~setKey.(\D, 3);
~setScale.(\dorian);
~showMappedParams.();
~fxSynth.set(\mix, 0.3, \room, 0.95, \damp, 0.2);
~playPadChord.([57, 60, 65, 69], 0.8, 0.5); // Play a pad chord
~restartFX.(); // Manuel restart to be able to play again after cmd + . incase the automatic restart did not work
~startChordEngine.();
~stopChordEngine.();