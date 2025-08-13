
s.reboot;

(
// -------------------------
// AMBIENT GENERATOR STARTUP
// -------------------------

s.waitForBoot {

	// --- Mixing & Global FX ---

	// 1) Bus for all instruments to feed into
	~fxBus = ~fxBus ? Bus.audio(s, 2);

	// 2) Reverb synthdef
	SynthDef(\globalFX, { |in=0, mix=0.5, room=0.9, damp=0.3|
		var dry = In.ar(in, 2);
		var wet = FreeVerb.ar(dry, mix, room, damp);
		Out.ar(0, dry + wet);
	}).add;
	s.sync;

	// 3) Fixed-order groups: sources FIRST, FX AFTER
	~srcGroup = ~srcGroup ? Group.head(s);
	~fxGroup  = ~fxGroup  ? Group.tail(s);

	// 4) (Re)create the FX synth inside the FX group (tail)
	~restartFX = {
		try { ~fxSynth.free } { };  // free old one if any
		~fxSynth = Synth(\globalFX, [\in, ~fxBus], target: ~fxGroup, addAction: \addToTail);
		~fxSynth.set(\mix, 0.5, \room, 0.9, \damp, 0.3);
		"FX chain restarted.".postln;
	};

	// 5) Ensure FX is alive (use this before playing if needed)
	~ensureFX = {
		if(~fxSynth.isNil or: { ~fxSynth.isRunning.not }) { ~restartFX.() } { "FX chain OK.".postln };
	};

	// 6) Auto-respawn FX after Cmd+. (install once)
	if(~fxCmdHookAdded != true) {
		CmdPeriod.add({ { ~restartFX.() }.defer });
		~fxCmdHookAdded = true;
	};

	// 7) Start FX now
	~restartFX.();


	// --- Parameter Mapping Engine ---

	/*
	warmth from cold (digital, thin) to warm (analog, fat) -> detuneAmt
	brightness from dark (filtered, muffled) to bright (open) -> filter cutoff
	density from sparse (few voices) to dense (many voices) -> number of voices
	variability from static to highly changing -> modulation speed
	rhythmicity from fluid/free to rhythmic/structured -> pulse emphasis
	*/

	// 1) Init/ensure
	~ensureParams = {
		if(~parameters.isNil) {
			~parameters = IdentityDictionary[
				\warmth -> 0.5,
				\brightness -> 0.5,
				\density -> 0.5,
				\variability -> 0.5,
				\rhythmicity -> 0.5
			];
		};
	};
	~ensureParams.();

	// 2) Mappers
	~mapLin = { |val, inMin=0, inMax=1, outMin=0, outMax=1|
		((val - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
	};

	// expo mapping for things like cutoff; avoids “all the action at the top”
	~mapExp = { |val, inMin=0, inMax=1, outMin=100, outMax=8000|
		var t = ((val - inMin) / (inMax - inMin)).clip(0,1);
		outMin * ((outMax/outMin) ** t)
	};

	// 3) Mapped parameters (closures read current ~parameters)
	~parameterMappings = (
		detune:       { ~mapLin.(~parameters[\warmth],      0, 1, 0.01, 1.0) },
		filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 200, 8000) },
		numVoices:    { ~mapLin.(~parameters[\density],     0, 1, 3, 5).round.asInteger },
		modSpeed:     { ~mapLin.(~parameters[\variability], 0, 1, 0.05, 1.5) },
		pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger }
	);

	// 4) Setters / getters
	~setParam = { |key, val|
		~ensureParams.();
		~parameters[key] = val.clip(0, 1);
	};

	~setParams = { |pairs|  // e.g. ~setParams.( (warmth:0.8, brightness:0.3) );
		pairs.keysValuesDo { |k, v| ~setParam.(k, v) };
	};

	~getParam   = { |key| ~parameters[key] };
	~getMapped  = { |key| var f = ~parameterMappings[key]; f.notNil.if({ f.() }, { nil }) };

	// 5) Inspectors
	~showParams = {
		"Params:".postln;
		~parameters.keysValuesDo { |k,v| ("%: %".format(k, v)).postln };
	};

	~showMappedParams = {
		"Mapped Parameter Values:".postln;
		~parameterMappings.keysValuesDo { |key, func|
			("%: %".format(key, func.())).postln;
		};
	};


	// --- Control Buses ---

	~cutoffBus = ~cutoffBus ? Bus.control(s, 1);
	~detuneBus = ~detuneBus ? Bus.control(s, 1);

	~updatePadBuses = {
		~cutoffBus.set(~parameterMappings[\filterCutoff].());
		~detuneBus.set(~parameterMappings[\detune].());
	};
	~updatePadBuses.();  // initialize with current parameters


	// --- Pad SynthDef ---

	SynthDef(\padVoice, {
		| out=0, freq=440, amp=0.25,
		cutoffBus=0,     // ControlBus index (required; we always pass it)
		detuneBus=0,     // ControlBus index (required)
		pan=0.0, gate=1,
		atk=3.0, rel=6.0,
		driftHz=0.05,    // speed of cutoff random drift
		driftAmt=500,    // ±Hz of cutoff drift around the bus value
		rq=0.35,         // filter resonance
		chorusMix=0.45   // 0..1, amount of micro-chorus
		|

		var det, baseCf, cfMod, cfNow;
		var freqs, voice, snd, env, pans, ampMod;
		var d1, d2, chorL, chorR, dry;

		// Live controls
		det    = In.kr(detuneBus, 1);         // expected ~0.01..1.0 (interpreted as percent)
		baseCf = In.kr(cutoffBus, 1);         // e.g. 200..8000 Hz from mapping

		// Organic cutoff motion, smoothed
		cfMod  = Lag.kr(LFNoise2.kr(driftHz).range(0 - driftAmt, driftAmt), 3.0);
		cfNow  = (baseCf + cfMod).clip(200, 16000);

		// Three detuned partials
		freqs = [
			freq,
			freq * (1 + det * 0.01),
			freq * (1 - det * 0.01)
		];

		// Gentle stereo offsets
		pans  = [-0.25, 0, 0.25];

		voice = Mix.fill(3, { |i|
			var saw  = Saw.ar(freqs[i]);
			var sine = SinOsc.ar(freqs[i], Rand(0, 2pi));
			var mix  = XFade2.ar(saw, sine, -0.25);  // mostly saw
			Pan2.ar(mix, pans[i]);
		});

		// Subtle amplitude drift (non-periodic), smoothed
		ampMod = Lag.kr(LFNoise2.kr(0.15).range(0.95, 1.0), 2.5);

		// Filter
		snd = RLPF.ar(voice, cfNow, rq);

		// ASR envelope
		env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

		// Micro-chorus: two very short, slowly-wiggling delays
		d1 = 0.006 + LFNoise2.kr(0.10).range(-0.003, 0.003);
		d2 = 0.008 + LFNoise2.kr(0.07).range(-0.004, 0.004);
		dry   = snd.sum;
		chorL = DelayC.ar(dry, 0.02, d1);
		chorR = DelayC.ar(dry, 0.02, d2);

		// Blend chorus with original
		snd = (snd * (1 - chorusMix)) + ([chorL, chorR] * chorusMix);

		// Level, cleanup, pan
		snd = snd * ampMod * env * amp;
		snd = LeakDC.ar(snd);
		snd = Limiter.ar(snd, 0.95);

		snd = Balance2.ar(snd[0], snd[1], pan);
		Out.ar(out, snd);
	}).add;
	s.sync;

	// Done and give feedback
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

~currentDegree = ~currentDegree ? 1;

~nextDegree = { |cur|
    var pairs = ~degreeMarkov[cur] ? [[1, 1.0]];
    var total = pairs.sum { |p| p[1] };
    var r = total.rand, acc = 0.0;
    pairs.do { |p|
        acc = acc + p[1];
        if (r < acc) {
            ("Next degree: " ++ p[0]).postln; // <-- print each step
            ^p[0];
        };
    };
    pairs.last[0]
};

// --- Parameter-to-music mappings ---

// chord duration in beats from rhythmicity (0 --> 6 beats, 1 --> 1.5 beats)
~chordHoldBeats = {
    var v = ~parameters[\rhythmicity] ? 0.5;
    (~mapLin.(v, 0, 1, 6.0, 1.5)).max(0.1)
};

// chord size 3..5 (integer) from density
~chordSize = {
    var v = ~parameters[\density] ? 0.5;
    var r = ~mapLin.(v, 0, 1, 3, 5);
    (r.round.asInteger).clip(3, 5)
};

// inversion amount 0..3 (integer) from variability
~invAmount = {
    var v = ~parameters[\variability] ? 0.5;
    var r = ~mapLin.(v, 0, 1, 0, 3);
    (r.round.asInteger).clip(0, 3)
};

// probability of adding the 9th (0..0.6) from variability
~add9Prob = {
    var v = ~parameters[\variability] ? 0.5;
    ~mapLin.(v, 0, 1, 0.0, 0.6)
};

// register center (MIDI) from brightness (C3..C5 ≈ 48..72)
~targetCenter = {
    var v = ~parameters[\brightness] ? 0.5;
    var r = ~mapLin.(v, 0, 1, 48, 72);
    r.round
};

// spread (± around center) from warmth (16..30 semitones)
~targetSpread = {
    var v = ~parameters[\warmth] ? 0.5;
    var r = ~mapLin.(v, 0, 1, 16, 30);
    r.round
};

// Utility: build the next voiced chord (returns an Array of midinotes)
~nextVoicedChord = {
    var deg    = ~currentDegree ? 1;
    var size   = ~chordSize.().asInteger.clip(3, 5);
    var inv    = ~invAmount.().asInteger.clip(0, 3);
    var center = ~targetCenter.();
    var spread = ~targetSpread.();

    var chord  = ~chordFromDegree.(deg, size, ~add9Prob.(), 4);
    chord      = ~invert.(chord, inv);
    chord      = ~voiceSpread.(chord, center, spread);

    // advance degree for next event
    ~currentDegree = ~nextDegree.(deg);

    chord  // array of MIDI notes
};

// A safe “ensure FX + group” function for patterns
~ensureAudioInfra = {
    ~ensureFX.();
    ~srcGroup = ~srcGroup ?? { Group.head(s) };
    ~fxGroup  = ~fxGroup  ?? { Group.tail(s) };
};

// Pattern: one event per chord; Event system expands arrays into multiple notes
~ensureAudioInfra.();

// chord duration in beats: rhythmicity 0 → long (6), 1 → short (1.5)
~chordHoldBeats = {
	~ensureParams.();
	~mapLin.( ~parameters[\rhythmicity] ? 0.5, 0, 1, 6.0, 1.5 )
};

Pdef(\pad,
    Pbind(
        \instrument, \padVoice,
        \group,      Pfunc { ~srcGroup },  // ensure pad notes go to source group
        \out,        Pfunc { ~fxBus },     // route into global FX
        \atk,        2.5,                  // synth-side fade in
        \rel,        5.0,                  // synth-side fade out
        \amp,        0.20,

        // duration in beats per chord (from rhythmicity)
        \dur, Pfunc { ( ~chordHoldBeats ? { 2.0 } ).value.max(0.1) },

        // build voiced chord each event; Event will spawn parallel notes for arrays
        \midinote,   Pfunc { ~nextVoicedChord.() },

        // a touch of stereo spread per note (optional)
        \pan,        Pwhite(-0.3, 0.3),

        // make sure gate releases occur (Event uses sustain=dur*legato; we keep legato ~1)
        \legato,     1.0
    )
);
)


// --- Checks ---

s.meter;
s.scope;
s.notetree;
~chordHoldBeats.().postln;  // should print a number, e.g. 3.75
~parameters.postln;         // not nil
~mapLin.postln;             // a Function
~chordSize.postln;
~invAmount.postln;
~targetCenter.postln;
~targetSpread.postln;
~add9Prob.postln;
~chordHoldBeats.postln;
~ensureFX.();
~fxSynth.isRunning.postln;
~nextVoicedChord.().postln;


(
// Create (or reuse) the control buses
~cutoffBus = ~cutoffBus ? Bus.control(s, 1);
~detuneBus = ~detuneBus ? Bus.control(s, 1);

// Updater: push mapped values to the buses
~updatePadBuses = {
	var cutoff = (~parameterMappings[\filterCutoff] ? { ~mapExp.(~parameters[\brightness] ? 0.5, 0,1, 200,8000) }).value;
	var detune = (~parameterMappings[\detune]       ? { ~mapLin.(~parameters[\warmth]     ? 0.5, 0,1, 0.01,1.0) }).value;
	~cutoffBus.set(cutoff);
	~detuneBus.set(detune);
};
)

(
// Quick status
~status = {
    "---- STATUS ----".postln;
    ("params   : " ++ (~parameters ? nil)).postln;
    ("fxBus    : " ++ (~fxBus ? nil)).postln;
    ("fxSynth  : " ++ (if(~fxSynth.notNil, { ~fxSynth.isRunning }, { nil }))).postln;
    ("scalePcs : " ++ (~scalePcs ? nil)).postln;
    ("keyMidi  : " ++ (~keyMidi ? nil)).postln;
    nil
};

// Panic (stop patterns + fade current nodes via CmdPeriod)
~panic = {
    Pdef.all.do(_.stop);
    CmdPeriod.run;
    "Panic: patterns stopped, server nodes halted.".postln;
};
)

(
~updatePadBuses.();  // push cutoff/detune to buses
Synth(\padVoice, [
    \out,       ~fxBus,
    \cutoffBus, ~cutoffBus.index,
    \detuneBus, ~detuneBus.index,
    \freq,      220,
    \atk, 0.5, \rel, 2.0, \amp, 0.2
]);
)

// --- Usage ---
~setParam.(\warmth, 0.8);
~setParam.(\brightness, 0.3);
~setKey.(\D, 3);
~setScale.(\dorian);
~showMappedParams.();
~fxSynth.set(\mix, 0.9, \room, 0.95, \damp, 0.2);
~fxSynth = Synth(\globalFX, [\in, ~fxBus]);
~fxSynth.isRunning.postln; // sollte nun true sein!
~playPadChord.([57, 60, 65, 69], 0.8, 0.5); // Play a pad chord
~restartFX.(); // Manuel restart to be able to play again after cmd + . incase the automatic restart did not work
~updatePadBuses.(); // make sure buses reflect current params
~status.();
~panic.();

// Start / stop
Pdef(\pad).play(TempoClock.default);
Pdef(\pad).stop;

// Change the feel while it runs (affects *next* chord)
~setParam.(\density, 0.9);      // 3 → 5 notes
~setParam.(\variability, 0.6);  // more inversions/9ths
~setParam.(\brightness, 0.7);   // higher register
~setParam.(\warmth, 0.8);       // wider spread
~setParam.(\rhythmicity, 0.5);  // shorter holds = faster changes

// Set buses
~cutoffBus.set(5000);
~detuneBus.set(0.1);

// Key / scale changes (take effect on next chord)
~setKey.(\D, 3);
~setScale.(\dorian);

// Tempo
TempoClock.default.tempo = 80/60; // 80 BPM