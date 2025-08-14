s.reboot;

(
// --- Parameter Mapping Engine ---

/*
warmth from cold (digital, thin) to warm (analog, fat) -> detuneAmt
brightness from dark (filtered, muffled) to bright (open) -> filter cutoff
density from sparse (few voices) to dense (many voices) -> number of voices
variability from static to highly changing -> modulation speed
rhythmicity from fluid/free to rhythmic/structured -> pulse emphasis
*/

~ensureParams = {
	if(~parameters.isNil) {
		~parameters = IdentityDictionary[
			\warmth -> 0.5,      // detune
			\brightness -> 0.5,  // filter cutoff
			\density -> 0.5,     // number of voices
			\variability -> 0.5, // modulation speed
			\rhythmicity -> 0.5  // rhythm emphasis
		];
	};
};
~ensureParams.();

~mapLin = { |val, inMin=0, inMax=1, outMin=0, outMax=1|
	((val - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
};

~mapExp = { |val, inMin=0, inMax=1, outMin=100, outMax=8000|
	var t = ((val - inMin) / (inMax - inMin)).clip(0,1);
	outMin * ((outMax/outMin) ** t)
};

~parameterMappings = (
	detune:       { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.1) },
	modDepth:     { ~mapLin.(~parameters[\warmth],      0, 1, 1, 250) },
	filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 1000, 10000) },
	rq:           { ~mapLin.(~parameters[\brightness],  0, 1, 0.9, 0.1)},
	dur:          { ~mapLin.(~parameters[\variability], 0, 1, 16, 4)},
	pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger },
	atk:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 0.5) },
    rel:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 8.0, 1.0) },
	norm:         { ~mapLin.(~parameters[\density],     0, 1, 0.4, 0.1) },
	numVoices:    {
		var raw =   ~mapLin.(~parameters[\density],         0, 1, 1, 9).round.asInteger;
		if(raw.even) { raw = raw + 1 }; // ensure odd
		raw
	},
	modRate: {
		var r = ~parameters[\rhythmicity];
		var tempo = TempoClock.default.tempo; // beats per second
		var divisions = [4, 2, 1.5, 1, 0.75, 0.5, 0.25]; // whole, half, dotted quarter, etc.
		var idx = (r * (divisions.size - 1)).round.clip(0, divisions.size - 1);
		var chosenDivision = divisions[idx];

		// Convert beats to Hz (tempo-synced)
		1 / chosenDivision * tempo
	},
);

~setParam = { |key, val|
	~ensureParams.();
	~parameters[key] = val.clip(0, 1);
};

~setParams = { |pairs|
	pairs.keysValuesDo { |k, v| ~setParam.(k, v) };
};

~getParam   = { |key| ~parameters[key] };
~getMapped  = { |key| var f = ~parameterMappings[key]; f.notNil.if({ f.() }, { nil }) };

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
)

// --- Pad Synth ---
(
SynthDef(\padSynth, { |freq = 440, amp = 0.2, gate = 1, pan = 0, atk = 2.0, rel = 4.0, ffreq = 100, rq = 0.2, modRate = 1, modDepth = 100, norm = 0.3|
    var osc, env, filt, mod;

    // Saw per voice
    osc = Saw.ar(freq) * norm;


    // Filter modulation
    mod = SinOsc.kr(modRate, 0, modDepth, ffreq);
	filt = RLPF.ar(osc, mod, rq);
	filt = tanh(filt * 0.8); // gentle analog-style limiting


    // Envelope
    env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

    Out.ar(0, Pan2.ar(filt * env * amp, pan));
}).add;
)


// --- Harmony ---
(
~scales = (
    ionian:     [0,2,4,5,7,9,11],   // major
    dorian:     [0,2,3,5,7,9,10],
    phrygian:   [0,1,3,5,7,8,10],
    lydian:     [0,2,4,6,7,9,11],
    mixolydian: [0,2,4,5,7,9,10],
    aeolian:    [0,2,3,5,7,8,10],   // natural minor
    locrian:    [0,1,3,5,6,8,10]
);

// note names just for convenience
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
	~keyMidi = ((octave + 1) * 12) + pc;
	("Key set to " ++ name ++ octave ++ " (MIDI " ++ ~keyMidi ++ ")").postln;
};

// Safety measure
~ensureScaleAndKey = {
    if(~keyMidi.isNil) {
        "No key set – defaulting to C4".postln;
        ~setKey.(\C, 4);
    };
    if(~scalePcs.isNil) {
        "No scale set – defaulting to ionian".postln;
        ~setScale.(\ionian);
    };
};

// Scale to MIDI mapping
~scaleToMidi = {
    ~ensureScaleAndKey.();
    ~scalePcs.collect { |interval| ~keyMidi + interval }
};

// Build a tertian chord from scale degree (triad..5-note), optionally add 9th
~chordFromDegree = { |degree, size=4, add9Prob=0.0|
    var scaleMidis = ~scaleToMidi.();
    var rootIndex = degree - 1;
    var steps = [0, 2, 4, 6, 8].copyRange(0, size - 1); // tertian intervals

    var chord = steps.collect { |s| scaleMidis.wrapAt(rootIndex + s) };

    if(1.0.rand < add9Prob and: { size <= 4 }) {
        chord = chord.add(scaleMidis.wrapAt(rootIndex + 8));
    };

    chord
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
    var result;

    result = pairs.detect { |p|
        acc = acc + p[1];
        r < acc
    }[0];

    ("Next degree: " ++ result).postln;
    result
};

~nextChord = {
    var deg, chord;

    deg = ~nextDegree.(~currentDegree);
    ~currentDegree = deg;

    chord = ~chordFromDegree.(deg, 4, 0.3);
    chord = ~voiceSpread.(chord, 60, 24);
    chord = ~invert.(chord, rrand(0, 2));  // Random inversion

	/*
    // Debug: check for nils
    if(chord.any(_.isNil)) {
        ("[ERROR] NIL in chord: degree " ++ deg ++ " chord: " ++ chord).postln;
    } {
        ("[OK] degree " ++ deg ++ " chord MIDI: " ++ chord).postln;
    };
	*/

    chord
};
)

// --- Pdef with probabilistic chord selection ---
(
Pdef(\pad,
    Pbind(
        \instrument, \padSynth,

        // Rhythm: rhythmicity influences dur choices
		\dur, Pfunc({ ~getMapped.(\dur) }),


        // Chords
		\freq, Pfunc({
			var chord, freqs, detune, n, voices;

			chord = ~nextChord.();
			freqs = chord.midicps;
			detune = ~getMapped.(\detune);
			n = ~getMapped.(\numVoices);

			// Detune voices
			voices = Array.fill(n, { |i|
				freqs + (detune * (i - (n-1)/2))
			}).flat;


			// Add octave up/down layers if many voices
			if(n > 5) {
				voices = voices
				++ ((voices * 2) * 0.5)   // octave up at half volume
			};


			// Debug
			("[Pbind DEBUG] numVoices: " ++ n).postln;
			("[Pbind DEBUG] final freqs: " ++ voices).postln;

			voices
		}),


		\pan, Pfunc({
			var n = ~getMapped.(\numVoices);
			Array.fill(n, { |i|
				(i / (n - 1)) * 2 - 1 // evenly spread between -1 and 1
			}).flat
		}),

        \amp, 0.3,

        // Variability -> modRate
        \modRate, Pfunc({ ~getMapped.(\modRate) }),

        // Brightness -> filter cutoff
        \ffreq, Pfunc({ ~getMapped.(\filterCutoff) }),

        \atk, Pfunc({ ~getMapped.(\atk) }),
        \rel, Pfunc({ ~getMapped.(\rel) }),
        \rq, 0.3,
    )
).play;
)


// --- Routine to change scales ---
(
Routine({
    var allScales = ["ionian", "dorian", "phrygian", "lydian", "mixolydian", "aeolian", "locrian"], waitTime;

    loop {
        ~setScale.(allScales.choose.asSymbol);

        // variability → 64, 32, 16 mapping
        waitTime = [64, 32, 16, 8][ (~parameters[\variability] * 4).floor.clip(0, 3) ];

        waitTime.postln; // debug
        waitTime.wait;
    }
}).play;
)


// --- Usage & Checks ---
// Play the Synth without Pbind
x = Synth(\padSynth, [\freq, [440, 550, 660], \amp, 0.3]);


// Define key and scale
~setKey.(\C, 4);
~setScale.(\ionian);


// Check scale, key and chord
~scalePcs.postln;     // Should be [0,2,4,5,7,9,11] for ionian
~keyMidi.postln;      // Should be 60 (for C4)
~scaleToMidi.().postln;  // should print [60, 62, 64, 65, 67, 69, 71]
~nextDegree.(1).postln;
~chordFromDegree.(1).postln;  // Should return MIDI notes like [60, 64, 67, 71]
~nextChord.().postln;  // -> posts degree and MIDI array
~nextChord.().midicps.postln;

// Warmth: 0 (cold/thin) → 1 (warm/fat)
~setParam.(\warmth, 0.5);

// Brightness: 0 (dark/muffled) → 1 (bright/open)
~setParam.(\brightness, 0.3);

// Density: 0 (few voices) → 1 (many voices)
~setParam.(\density, 0.6);

// Variability: 0 (slow/static) → 1 (fast/changing)
~setParam.(\variability, 0.7);

// Rhythmicity: 0 (smooth/legato) → 1 (tight/rhythmic)
~setParam.(\rhythmicity, 0.9);

~parameters.postln;


// Show mapped values
~showMappedParams.();
