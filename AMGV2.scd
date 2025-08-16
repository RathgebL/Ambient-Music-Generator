s.reboot;
s.meter;
s.plotTree;


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
	drive:        { ~mapLin.(~parameters[\warmth],      0, 1, 0.05, 0.5) },
	humLevel:     { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.05) },
	modDepth:     { ~mapLin.(~parameters[\warmth],      0, 1, 1, 250) },
	noisePink:    { ~mapLin.(~parameters[\warmth],      1, 0, 0.8, 0.2) },
	noiseWhite:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	revDamp:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	rumbleLevel:  { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.2) },
	sub:          { ~mapLin.(~parameters[\warmth],      0, 1, 0.5, 1.0) },
	filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 1000, 10000) },
	rq:           { ~mapLin.(~parameters[\brightness],  0, 1, 0.9, 0.1)},
	dur:          { ~mapLin.(~parameters[\variability], 0, 1, 16, 8)},
	revMix:       { ~mapLin.(~parameters[\variability], 0, 1, 0.3, 0.6) },
	atk:          { ~mapExp.(1 - ~parameters[\rhythmicity], 0, 1, 0.2, 2) },
	pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger },
    rel:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 1.0) },
	legato:       { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 0.95) },
	norm:         { ~mapExp.(~parameters[\density],     0, 1, 0.9, 0.1) },
	texAmp:       { ~mapExp.(~parameters[\density],     0, 1, 0.2, 0.35) },
	bassAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.25) },
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
SynthDef(\padSynth, { |freq = 440, amp = 0.2, gate = 1, pan = 0, atk = 2.0, rel = 4.0, ffreq = 100, rq = 0.2, modRate = 1, modDepth = 100, norm = 0.3, revMix = 0.3|
    var osc, env, filt, mod, rev;

    // Saw per voice
    osc = Saw.ar(freq) * norm;


    // Filter modulation
    mod = SinOsc.kr(modRate, 0, modDepth, ffreq);
	filt = RLPF.ar(osc, mod, rq);
	filt = tanh(filt * 0.8); // gentle analog-style limiting


    // Envelope
    env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

	// Reverb to push into space
    rev = FreeVerb.ar(filt * env * amp, mix: revMix, room: 0.9, damp: 0.7);

    Out.ar(0, Pan2.ar(rev, pan));
}).add;
)


// --- Bass Synth ---
(
SynthDef(\bassSynth, {
    |freq = 60, amp = 0.3, gate = 1, pan = 0, atk = 0.01, rel = 0.4,
     ffreq = 200, rq = 0.3, subOct = 0.5, drive = 0.2|

    var osc, sub, mix, filt, env;

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
    Out.ar(0, Pan2.ar(filt * env * amp, pan));
}).add;
)


// --- Textrure Synth ---
(
// Sea like texture
SynthDef(\textureSynth, {
    |amp = 0.1, ffreq = 1000, rq = 0.3,
     modRate = 0.05, modDepth = 300, pan = 0,
     pinkAmt = 0.5, whiteAmt = 0.5, revMix = 0.5,
     waveRate = 0.03, waveDepth = 0.4,
     atk = 4, sus = 1, rel = 6|  // swell timing in seconds

    var src, mod, filt, env, rev, waveLFO;

    // Noise source (warm)
    src = PinkNoise.ar(pinkAmt) + WhiteNoise.ar(whiteAmt);

    // LFO modulating filter cutoff
    mod = SinOsc.kr(modRate, Rand(0, 2pi), modDepth, ffreq);

    // Resonant low-pass filter
    filt = RLPF.ar(src, mod, rq);

    // Wave motion LFO
    waveLFO = SinOsc.kr(waveRate, Rand(0, 2pi)).range(1 - waveDepth, 1);

    // ASR envelope
    env = EnvGen.kr(Env.linen(atk, sus, rel, curve: -4), doneAction: 2);

    // Reverb space
    rev = FreeVerb.ar(filt * env * amp * waveLFO, mix: revMix, room: 0.9, damp: 0.7);

    Out.ar(0, Pan2.ar(rev, pan));
}).add;
)

)

// Vinyl Crackle Synth
(
SynthDef(\vinylCrackle, {
    |out=0, amp=0.1, dustDensity=3, lpFreq=4000, hpFreq=800,
     rumbleLevel=0.1, rumbleFreq=50,
     humLevel=0.02,
     wowRate=0.3, wowDepth=0.05|

    var trig, env, src, filtered, grainAmp, grainRel, saturated;
    var rumble, hum, wow, mix, panned;

    // --- Crackles ---
    trig = Dust.kr(dustDensity);
    grainAmp = TRand.kr(0.1, 1.0, trig);              // per-grain random amp
    grainRel = TRand.kr(0.003, 0.005, trig);           // per-grain random length
    env = EnvGen.kr(Env.perc(0.001, grainRel), trig) * grainAmp;
    src = PinkNoise.ar(amp) * env;
    filtered = HPF.ar(LPF.ar(src, lpFreq), hpFreq);
    saturated = (filtered * 5).tanh;

    // --- Mechanical rumble (low brown noise) ---
    rumble = LPF.ar(BrownNoise.ar(rumbleLevel), rumbleFreq);

    // --- Electrical hum (fundamental + harmonics) ---
    hum = (SinOsc.ar(50) + 0.5 * SinOsc.ar(100) + 0.25 * SinOsc.ar(150)) * humLevel;

    // --- Wow/flutter (slow amplitude wobble) ---
    wow = SinOsc.kr(wowRate, 0, wowDepth, 1);

    // --- Mix & output ---
    mix = (saturated + rumble + hum) * wow;
    panned = Pan2.ar(mix, LFNoise1.kr(5).range(-0.5, 0.5));
    Out.ar(out, panned);
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

// Build a chord by weighted selection (now reacts to variability)
~weightedChord = { |degree|
	var scaleMidis, rootIndex, size, tonePool, chosenSteps, total, r, acc, choice;

	scaleMidis = ~scaleToMidi.();
	rootIndex = degree - 1;
	size = ~getChordSize.();

	// tone pool with weights
	tonePool = [
		[0,   1.0], // root
		[2,   0.8], // 3rd
		[4,   0.9], // 5th
		[6,   0.5], // 7th
		[8,   0.3], // 9th
		[3,   0.2], // 4th
		[5,   0.1], // 6th
		[7,   0.05], // 11th (same pitch class as 4th)
		[9,   0.01]  // 13th (same pitch class as 6th)
	];

	// pick notes with rules
	chosenSteps = [];

	size.do {
		// For every already chosen step in the chord...
		chosenSteps.do { |step|

			switch(step,

				3, { // Already have a 4th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 6th (p[0] == 5) or a 13th (p[0] == 9)
						if((p[0] == 5) or: (p[0] == 9)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] } { p }
					};
				},

				5, { // Already have a 6th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3) or 7th (p[0] == 7)
						if((p[0] == 3) or: (p[0] == 7)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 9th (p[0] == 8)
						{ if(p[0] == 8) { [p[0], p[1] * 1.2] } { p } }
					};
				},

				6, { // Already have a 7th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3) or a 6th (p[0] == 5)
						if((p[0] == 3) or: (p[0] == 5)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 9th (p[0] == 8)
						{ if(p[0] == 8) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 1.1, 1.5)] } { p } }
					};
				},

				8, { // Already have a 9th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3)
						if((p[0] == 3)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 3rd (p[0] == 4) or a 6th (p[0] == 5)
						{ if((p[0] == 4) or: (p[0] == 5)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 1.1, 1.5)] } { p } }
					};
				}
			);
		};

		// Pick notes without doubles
		total = tonePool.sum { |p| p[1] };
		r = total.rand;
		acc = 0.0;
		choice = tonePool.detect { |p|
			acc = acc + p[1];
			r < acc
		};

		if(choice.notNil) {
			chosenSteps = chosenSteps.add(choice[0]);
			tonePool.remove(choice); // remove to avoid duplicates
		};
	};

	// Debug: check for duplicates
	if(chosenSteps.size != chosenSteps.as(Set).size) {
		("[WeightedChord DEBUG] Duplicate found: " ++ chosenSteps).warn;
	} {
		("[WeightedChord DEBUG] Unique notes: " ++ chosenSteps).postln;
	};

	// map steps to MIDI and sort
	chosenSteps = chosenSteps.sort;
	chosenSteps.collect { |s|
		scaleMidis.wrapAt(rootIndex + s)
	}
};

// Range for notes
~clampChordRangeDynamic = { |notes|
    var root = notes.first;  // assume first note = root
    var minNote = root - 7;  // perfect 5th below root
    var maxNote = root + 24; // 2 octaves above root

    var clamped = notes.collect { |n|
        var x = n;
        while { x < minNote } { x = x + 12 };
        while { x > maxNote } { x = x - 12 };
        x
    };

    // Debug
    ("[RelClamp DEBUG] Root: " ++ root
        ++ " | Range: " ++ minNote ++ "-" ++ maxNote
        ++ " | Before: " ++ notes
        ++ " | After: " ++ clamped).postln;

    clamped
};


~lastChord = ~weightedChord.(1, 4); // start at degree 1

// Voice leading
~voiceLeading = { |newChord, lastChord|
    var maxLeap = ~mapLin.(~parameters[\variability], 0, 1, 4, 6).round.asInteger;

    if(lastChord.isNil) {
        ~clampChordRangeDynamic.(newChord)
    } {
        // Step 1: voice lead by nearest register
        var led = newChord.collect { |note, i|
            var target = note;
            var lastNote = lastChord.wrapAt(i);

            while { target - lastNote > maxLeap } { target = target - 12 };
            while { lastNote - target > maxLeap } { target = target + 12 };
            target
        };

        // Step 2: clamp into global range
        led = ~clampChordRangeDynamic.(led);

        // Step 3: avoid muddy intervals in low register
        led = led.sort;
        led = led.collect { |n, i|
            if(i > 0 and: { n < 72 and: { (n - led[i-1]).abs < 4 } }) {
                n + 12  // push up one octave if too close under 72
            } {
                n
            }
        };

        led
    }
};

// Getter for chord size with randomness influenced by variability
~getChordSize = {
    var baseSize = ~mapLin.(~parameters[\density], 0, 1, 2, 6).round.asInteger;
    var varChance = ~mapLin.(~parameters[\variability], 0, 1, 0.0, 0.5); // up to 50% chance

    // Randomly add or subtract 1 based on variability chance
    if(varChance.coin) {
        baseSize = baseSize + ([-1, 1].choose);
    };

    // Constrain size between 2 and 6 voices
    baseSize.clip(2, 6)
};

// Build a chord with voice leading
~voiceLeadChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~weightedChord.(degree, size);
    chord = ~voiceLeading.(chord, ~lastChord);
    ~lastChord = chord; // store for next time
    chord
};

// Build the final chord
~finalChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~voiceLeadChord.(degree);
    /*chord = ~applySuspensions.(chord);
    chord = ~enforceSuspensionRules.(chord);*/

	// Debug print final chord (both MIDI & Hz + voice count)
	("[Chord DEBUG @ " ++ Main.elapsedTime.round(0.01) ++ "] Voices: "
    ++ chord.size ++ " | MIDI: " ++ chord ++ " | Hz: " ++ chord.midicps).postln;



    ~lastChord = chord;
    chord
};

// Predefined amplitude levels for 2..6 voices
~ampLevels = (
	1: 0.7,
    2: 0.5,
    3: 0.35,
    4: 0.22,
    5: 0.15,
    6: 0.1,
	7: 0.07,
);

// Function to get amp for current chord size
~getAmpForVoices = { |numVoices|
    ~ampLevels[numVoices] ? 0.1 // fallback if somehow outside 2..6
};

// --- Markov second order harmony (degrees 1..7) ---
~degreeMarkov2 = (
    11: [[2,0.3],[3,0.3],[4,0.3],[5,0.1]],
    12: [[3,0.3],[4,0.4],[6,0.3]],
    13: [[4,0.4],[6,0.4],[2,0.2]],
    14: [[5,0.4],[2,0.3],[6,0.3]],
    15: [[6,0.4],[4,0.4],[2,0.2]],
    16: [[4,0.4],[2,0.3],[3,0.3]],
    17: [[1,0.3],[3,0.4],[4,0.3]],

    21: [[4,0.4],[5,0.3],[3,0.3]],
    22: [[4,0.4],[6,0.4],[1,0.2]],
    23: [[4,0.3],[1,0.3],[6,0.4]],
    24: [[5,0.3],[6,0.3],[1,0.4]],
    25: [[1,0.4],[6,0.3],[3,0.3]],
    26: [[4,0.4],[2,0.3],[1,0.3]],
    27: [[1,0.3],[4,0.4],[2,0.3]],

    31: [[6,0.4],[4,0.3],[2,0.3]],
    32: [[4,0.4],[1,0.3],[6,0.3]],
    33: [[6,0.3],[4,0.4],[1,0.3]],
    34: [[5,0.4],[6,0.3],[1,0.3]],
    35: [[1,0.3],[4,0.4],[2,0.3]],
    36: [[4,0.3],[1,0.4],[2,0.3]],
    37: [[1,0.4],[4,0.3],[3,0.3]],

    41: [[5,0.4],[2,0.3],[6,0.3]],
    42: [[5,0.3],[6,0.3],[1,0.4]],
    43: [[6,0.3],[1,0.4],[2,0.3]],
    44: [[5,0.4],[1,0.3],[6,0.3]],
    45: [[1,0.4],[6,0.3],[2,0.3]],
    46: [[2,0.4],[1,0.3],[5,0.3]],
    47: [[1,0.3],[4,0.4],[2,0.3]],

    51: [[6,0.4],[4,0.4],[2,0.2]],
    52: [[6,0.3],[4,0.4],[1,0.3]],
    53: [[1,0.3],[4,0.4],[6,0.3]],
    54: [[1,0.4],[6,0.4],[2,0.2]],
    55: [[1,0.4],[6,0.3],[4,0.3]],
    56: [[2,0.4],[4,0.3],[1,0.3]],
    57: [[1,0.3],[5,0.4],[2,0.3]],

    61: [[4,0.4],[2,0.3],[3,0.3]],
    62: [[4,0.3],[1,0.3],[5,0.4]],
    63: [[1,0.4],[4,0.3],[2,0.3]],
    64: [[5,0.4],[1,0.3],[2,0.3]],
    65: [[1,0.4],[6,0.3],[4,0.3]],
    66: [[4,0.4],[2,0.3],[1,0.3]],
    67: [[1,0.3],[4,0.4],[2,0.3]],

    71: [[5,0.4],[3,0.3],[4,0.3]],
    72: [[4,0.3],[1,0.4],[6,0.3]],
    73: [[1,0.4],[4,0.3],[2,0.3]],
    74: [[1,0.3],[6,0.3],[5,0.4]],
    75: [[1,0.4],[6,0.3],[4,0.3]],
    76: [[4,0.4],[2,0.3],[1,0.3]],
    77: [[1,0.4],[4,0.3],[2,0.3]]
);

// Second-order Markov for ambient harmony (degrees 1..7)
~degreeMarkov2Ambient = (

    // From I (1)
    11: [[2,0.25],[4,0.35],[6,0.3],[1,0.1]],
    12: [[4,0.35],[6,0.3],[1,0.2],[3,0.15]],
    14: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    16: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From ii (2)
    21: [[4,0.35],[6,0.25],[3,0.2],[1,0.2]],
    22: [[4,0.35],[6,0.35],[1,0.2],[3,0.1]],
    23: [[4,0.35],[6,0.3],[2,0.2],[1,0.15]],
    24: [[6,0.3],[2,0.25],[1,0.25],[3,0.2]],
    26: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From iii (3) – acts as connector
    31: [[6,0.35],[4,0.35],[2,0.2],[1,0.1]],
    32: [[4,0.35],[6,0.3],[1,0.2],[3,0.15]],
    33: [[4,0.35],[6,0.35],[2,0.2],[1,0.1]],
    34: [[6,0.3],[2,0.3],[1,0.2],[5,0.2]],
    36: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From IV (4) – "pivot" node
    41: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    42: [[6,0.35],[4,0.25],[1,0.25],[3,0.15]],
    43: [[6,0.3],[2,0.3],[1,0.25],[5,0.15]],
    44: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    46: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From V (5) – softened
    51: [[4,0.35],[6,0.3],[2,0.2],[1,0.15]],
    52: [[6,0.3],[4,0.3],[1,0.25],[3,0.15]],
    53: [[1,0.25],[4,0.35],[6,0.25],[2,0.15]],
    54: [[1,0.25],[6,0.35],[2,0.25],[3,0.15]],
    56: [[1,0.3],[4,0.3],[2,0.25],[3,0.15]],

    // From vi (6) – modal anchor
    61: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],
    62: [[4,0.3],[1,0.3],[5,0.2],[3,0.2]],
    63: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],
    64: [[1,0.3],[6,0.25],[2,0.25],[5,0.2]],
    66: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From vii° (7) – rare, drifty
    71: [[2,0.4],[4,0.4],[6,0.2]],
    72: [[4,0.35],[2,0.3],[1,0.2],[6,0.15]],
    73: [[4,0.4],[2,0.3],[6,0.2],[1,0.1]],
    74: [[2,0.35],[6,0.35],[1,0.2],[4,0.1]],
    76: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]]
);

// Second-order Markov for exotic ambient harmony
~degreeMarkov2Exotic = (

    // I behaves less "tonic-y"
    11: [[2,0.25],[3,0.2],[4,0.25],[6,0.2],[7,0.1]],
    12: [[3,0.25],[4,0.2],[6,0.25],[7,0.2],[1,0.1]],
    13: [[4,0.25],[6,0.25],[7,0.2],[2,0.15],[1,0.15]],
    14: [[2,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    16: [[7,0.25],[2,0.25],[4,0.2],[3,0.2],[1,0.1]],
    17: [[2,0.3],[4,0.25],[6,0.2],[3,0.15],[1,0.1]],

    // ii wanders sideways (Dorian / Phrygian feel)
    21: [[3,0.25],[4,0.25],[6,0.25],[7,0.15],[1,0.1]],
    22: [[4,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    23: [[4,0.25],[6,0.25],[7,0.25],[2,0.15],[1,0.1]],
    24: [[6,0.25],[7,0.25],[2,0.2],[3,0.2],[1,0.1]],
    26: [[7,0.25],[2,0.25],[4,0.2],[3,0.2],[1,0.1]],

    // iii now strong connector to exotic color
    31: [[4,0.25],[6,0.25],[7,0.25],[2,0.15],[1,0.1]],
    32: [[4,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    33: [[6,0.25],[7,0.25],[4,0.25],[2,0.15],[1,0.1]],
    34: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    36: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // IV less pivot, more modal shift
    41: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    42: [[7,0.25],[4,0.25],[6,0.25],[2,0.15],[1,0.1]],
    43: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    44: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    46: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // V not dominant at all, can escape anywhere
    51: [[2,0.25],[3,0.25],[6,0.25],[7,0.15],[1,0.1]],
    52: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    53: [[7,0.25],[2,0.25],[6,0.25],[3,0.15],[1,0.1]],
    54: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    56: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // vi modal anchor but much freer
    61: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],
    62: [[7,0.25],[4,0.25],[6,0.25],[2,0.15],[1,0.1]],
    63: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],
    64: [[7,0.25],[2,0.25],[6,0.25],[3,0.15],[1,0.1]],
    66: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // vii° gets promoted — dreamy tension
    71: [[2,0.25],[4,0.25],[6,0.25],[3,0.15],[7,0.1]],
    72: [[4,0.25],[2,0.25],[6,0.25],[7,0.15],[1,0.1]],
    73: [[4,0.25],[2,0.25],[6,0.25],[7,0.15],[1,0.1]],
    74: [[2,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    76: [[2,0.25],[4,0.25],[7,0.25],[3,0.15],[1,0.1]]
);

~chooseMarkov = {
    var v = ~parameters[\variability];
    if(v < 0.4) {
        "Using Ambient Markov table".postln;
        ~degreeMarkov2Ambient
    } {
        if(v < 0.75) {
            "Using Balanced Markov table".postln;
            ~degreeMarkov2
        } {
            "Using Exotic Markov table".postln;
            ~degreeMarkov2Exotic
        }
    }
};

~prevDegree = 1;
~currentDegree = 4; // Starting point

~nextDegree = {
	var key, pairs, total, r, result, acc, penaltyFactor;

	pairs = ~degreeMarkov2[10 * ~prevDegree + ~currentDegree];
	// Debug print
	("[Markov DEBUG] pairs: " ++ pairs).postln;


	if(pairs.isNil) {pairs = [[1,1.0]]};
	penaltyFactor = (0.5).pow(~sameDegreeCount - 1);

    // Lower cance for doubles
    if(~sameDegreeCount >= 2) {
        pairs = pairs.collect { |p|
            if(p[0] == ~currentDegree) {
                [p[0], p[1] * penaltyFactor]
            }
        };
    };

	// Normalize weights
	total = pairs.sum { |p| p[1] };
	r = total.rand;
	acc = 0.0;
	result = pairs.detect { |p|
		acc = acc + p[1];
		r < acc
	}[0];

	// Debug print
	("[Markov DEBUG] prev: " ++ ~prevDegree
		++ " curr: " ++ ~currentDegree
		++ " -> next: " ++ result
		++ " | sameCount: " ++ ~sameDegreeCount).postln;

    // Shift degrees for next step
    ~prevDegree = ~currentDegree;
    ~currentDegree = result;

    result
};


~nextChord = {
    var deg, chord;

	deg = ~nextDegree.(); // fallback to degree 1 if nil
    chord = ~finalChord.(deg, 4, 0.3);

    chord
};

~clampBassRange = { |note, min=36, max=48|
    var x = note;
    while { x < min } { x = x + 12 };
    while { x > max } { x = x - 12 };

	// Debug print bass note (both MIDI & Hz)
    ("[Bass DEBUG] MIDI: " ++ x ++ " | Hz: " ++ x.midicps).postln;

    x
};
)


// --- Pdef with probabilistic chord selection ---

(
~seaPattern = Pbind(
    \instrument, \textureSynth,
	\legato, Pwhite(0.97,1.03),

    // time between waves, in beats
	\dur, Pfunc({ ~getMapped.(\dur)}),

    // envelope shaping
    \atk, Pwhite(0.1, 0.4),   // proportion of dur
    \sus, Pwhite(0.05, 0.2),   // proportion of dur
    \rel, Pfunc { |ev|
        var beatDur = thisThread.clock.beatDur;
        var totalBeats = ev[\dur];
        var atkBeats   = (ev[\atk] * totalBeats);
        var susBeats   = (ev[\sus] * totalBeats);
        var relBeats   = (totalBeats - atkBeats - susBeats).max(0.1);
        relBeats * beatDur  // convert to seconds
    },

    // convert atk/sus also to seconds
    \atk, Pfunc { |ev| ev[\atk] * ev[\dur] * thisThread.clock.beatDur },
    \sus, Pfunc { |ev| ev[\sus] * ev[\dur] * thisThread.clock.beatDur },

    // synthesis params
    \ffreq,     1500,
    \rq,        0.7,
    \modRate,   Pfunc({ ~getMapped.(\modRate) } * 0.5),
    \modDepth,  Pfunc({ ~getMapped.(\modDepth) }),
    \pinkAmt,   Pfunc({ ~getMapped.(\noisePink) }),
    \whiteAmt,  Pfunc({ ~getMapped.(\noiseWhite) }),
    \revMix,    Pfunc({ ~getMapped.(\revMix) }),
    \waveDepth, Pfunc({ ~mapLin.(~parameters[\density], 0, 1, 0.1, 0.6) }),
    \waveRate,  Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 0.02, 0.08) }),
    \pan,       Pwhite(-1.0, 1.0),
    \amp,       Pfunc({ ~getMapped.(\texAmp) * 0.0001})
);

~vinylPattern = Pmono(
    \vinylCrackle,
    \dur,         Pfunc({ ~getMapped.(\dur) }),
	\dustDensity, Pfunc({
		var lo = 10 - rrand(0, 3);
		var hi = 20 - rrand(0, 5);
		~mapExp.(~parameters[\density], 0, 1, lo, hi)}),
    \lpFreq,      Pwhite(2000, 5000),
    \hpFreq,      Pwhite(500, 1500),
	\humLevel,    Pfunc({ ~getMapped.(\humLevel) }),
    \rumbleLevel, Pfunc({ ~getMapped.(\rumbleLevel) }),
    \amp, Pfunc({ ~getMapped.(\texAmp) } * 1.5)
);


Pdef(\ambgen,
    Pspawner { |sp|
        var padSynths = List[];
        var bassSynths = List[];
        var chord, dur, padFreqs, padPans, bassFreq;

		sp.par(~vinylPattern);

        loop {
            chord = ~nextChord.();
            dur   = ~getMapped.(\dur);

            // stop old synths
            padSynths.do { |s| s.set(\gate, 0) };
            bassSynths.do { |s| s.set(\gate, 0) };
            padSynths.clear;
            bassSynths.clear;

            // precompute pad params
            padFreqs = {
				var freqs  = chord.midicps;
				var detune = ~getMapped.(\detune);
				var n      = ~getMapped.(\numVoices);

				// base voices
				var baseVoices = Array.fill(n, { |i|
					freqs + (detune * (i - (n - 1) / 2))
				}).flat;

				// octave voices
				var octaveVoices = baseVoices * 2; // shift up an octave
				var octaveAmpFactor = ~mapExp.(~parameters[\density], 0, 1, 0.1, 0.3);

				// collect both freq + amp
				var voicePairs = baseVoices.collect { |f| [f, 1.0] }
				++ octaveVoices.collect { |f| [f, octaveAmpFactor] };

				voicePairs
			}.value;

			// Now padPans matches total voices
			padPans = Array.fill(padFreqs.size, { |i|
				(i / (padFreqs.size - 1)) * 2 - 1
			});

            // precompute bass
            bassFreq = ~clampBassRange.(chord[0] - 24).midicps;

            // spawn pad voices
            padFreqs.do { |f, i|
                padSynths.add(Synth(\padSynth, [
                    \freq, f,
                    \pan, padPans[i],
					\legato,  ~getMapped.(\legato),
                    \modRate, ~getMapped.(\modRate),
                    \ffreq,   ~getMapped.(\filterCutoff),
                    \revMix,  ~getMapped.(\revMix) * 0.7,
                    \atk,     ~getMapped.(\atk),
                    \rel,     ~getMapped.(\rel),
                    \rq,      ~getMapped.(\rq),
                    \amp,     ~getAmpForVoices.(chord.size)
                ]));
            };

            // spawn bass voice
            bassSynths.add(Synth(\bassSynth, [
                \freq, bassFreq,
				\legato, ~getMapped.(\legato) * 0.97,
                \ffreq,  ~getMapped.(\filterCutoff),
                \rq,     ~getMapped.(\rq),
                \subOct, ~getMapped.(\sub),
                \drive,  ~getMapped.(\drive),
                \atk,    ~getMapped.(\atk),
                \rel,    ~getMapped.(\rel),
                \amp,    ~getMapped.(\bassAmp)
            ]));

            // run sea & vinyl in parallel
            sp.par(Pbindf(~seaPattern));

            sp.wait(dur);
        }
    }
).play;
)


// Test Pdef
p = Pdef(\vinylOnly, ~padPattern).play;

// --- Routine to change scales ---

(
Routine({
    var allScales = ["ionian", "dorian", "phrygian", "lydian", "mixolydian", "aeolian", "locrian"], waitTime;

    loop {
        ~setScale.(allScales.choose.asSymbol);

        // variability → 64, 32, 16 mapping
        waitTime = [64, 32, 16][ (~parameters[\variability] * 3).floor.clip(0, 2) ];

        waitTime.postln; // debug
        waitTime.wait;
    }
}).play;
)


// --- Usage & Checks ---

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
~setParam.(\warmth, 0.8);

// Brightness: 0 (dark/muffled) → 1 (bright/open)
~setParam.(\brightness, 0.3);

// Density: 0 (few voices/open) → 1 (many voices/clustered)
~setParam.(\density, 0.2);

// Variability: 0 (slow/static) → 1 (fast/changing)
~setParam.(\variability, 0.5);

// Rhythmicity: 0 (smooth/legato) → 1 (tight/rhythmic)
~setParam.(\rhythmicity, 0.2);

~parameters.postln;


// Show mapped values
~showMappedParams.();
