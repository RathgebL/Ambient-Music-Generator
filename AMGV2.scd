s.reboot;
s.meter;

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
	modDepth:     { ~mapLin.(~parameters[\warmth],      0, 1, 1, 250) },
	noisePink:    { ~mapLin.(~parameters[\warmth],      1, 0, 0.8, 0.2) },
	noiseWhite:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	revDamp:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 1000, 10000) },
	rq:           { ~mapLin.(~parameters[\brightness],  0, 1, 0.9, 0.1)},
	dur:          { ~mapLin.(~parameters[\variability], 0, 1, 16, 4)},
	revMix:       { ~mapLin.(~parameters[\variability], 0, 1, 0.3, 0.6) },
	pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger },
	atk:          { ~mapExp.(1 - ~parameters[\rhythmicity], 0, 1, 0.5, 3) },
    rel:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 1.0) },
	legato:       { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1.05, 0.95) },
	sub:          { ~mapLin.(~parameters[\density],     0, 1, 0.5, 1.0) },
	norm:         { ~mapExp.(~parameters[\density],     0, 1, 0.9, 0.1) },
	texAmp:       { ~mapExp.(~parameters[\density],     0, 1, 0.05, 0.25) },
	bassAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.3) },
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
    osc = Pulse.ar(freq, 0.45, 0.8); // slightly narrow pulse for warmth

    // Sub osc: one octave below
    sub = SinOsc.ar(freq / 2, 0, subOct); // smooth low reinforcement

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
SynthDef(\textureSynth, { |amp = 0.1, gate = 1, ffreq = 1000, rq = 0.3, modRate = 0.05, modDepth = 300, pan = 0, pinkAmt = 0.5, whiteAmt = 0.5, revMix = 0.5|
    var src, mod, filt, env, rev;

    // Noise source (slightly mixed for a warmer tone)
    src = PinkNoise.ar(pinkAmt) + WhiteNoise.ar(whiteAmt);

    // LFO modulating filter cutoff
    mod = SinOsc.kr(modRate, Rand(0, 2pi), modDepth, ffreq);

    // Resonant low-pass filter
    filt = RLPF.ar(src, mod, rq);

    // Slow amplitude envelope (for triggering)
    env = EnvGen.kr(Env.asr(2, 1, 4), gate, doneAction: 2);

    // Reverb to push into space
    rev = FreeVerb.ar(filt * env * amp, mix: revMix, room: 0.9, damp: 0.7);

    // Pan randomly per voice
    Out.ar(0, Pan2.ar(rev, pan));
}).add;
)

// Vinyl Crackle Synth
(
SynthDef(\vinylCrackle, { |out=0, amp=0.1, dustDensity=3, lpFreq=4000, hpFreq=800|
    var trig, env, src, filtered,panned, saturated;

    trig = Dust.kr(dustDensity);
    env = EnvGen.kr(Env.perc(0.001, 0.02),trig);
    src = PinkNoise.ar(amp) * env;
    filtered = HPF.ar(LPF.ar(src, lpFreq), hpFreq);
	saturated = (filtered * 3).tanh * 0.4;
    panned = Pan2.ar(saturated, LFNoise1.kr(5).range(-0.5, 0.5));

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

~lastChord = ~weightedChord.(1, 4); // start at degree 1

// Voice leading
~voiceLeading = { |newChord, lastChord|
	var maxLeap = ~mapLin.(~parameters[\variability], 0, 1, 4, 6).round.asInteger;

	// ("[VoiceLead DEBUG] maxLeap: " ++ maxLeap).postln;

    if(lastChord.isNil) {
        // First chord: just return it
        newChord
    } {
        newChord.collect { |note, i|
            var target = note;
            var lastNote = lastChord.wrapAt(i);

            // shift up or down octaves until closest to lastNote
            while { target - lastNote > maxLeap } { target = target - 12 };
            while { lastNote - target > maxLeap } { target = target + 12 };

            target
        }
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
    var bright = ~mapLin.(~parameters[\warmth], 0, 1, 24, 0).round.asInteger;
	var minNote = 48 + bright;
	var maxNote = minNote + ~mapLin.(~parameters[\density], 0, 1, 12, 24).round.asInteger;

    var clamped = notes.collect { |n|
        var x = n;
        while { x < minNote } { x = x + 12 };
        while { x > maxNote } { x = x - 12 };
        x
    };

	// Debug print
	("[Clamp DEBUG]  Min: " ++ minNote
	 ++ " | Max: " ++ maxNote
	 ++ " | Before: " ++ notes
	 ++ " | After: " ++ clamped).postln;

    clamped
};



// Build a chord with voice leading
~voiceLeadChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~weightedChord.(degree, size);
	chord = ~clampChordRangeDynamic.(chord);
    chord = ~voiceLeading.(chord, ~lastChord);
    ~lastChord = chord; // store for next time
    chord
};

// Suspensions & omissions helper
~applySuspensions = { |chord|
	var probSus   = ~mapLin.(~parameters[\variability], 0, 1, 0.05, 0.4);
	var probOmit5 = ~mapLin.(~parameters[\variability], 0, 1, 0.05, 0.25);


    // Apply suspension (replace 3rd with 2nd or 4th)
    if(probSus.coin) {
        var idx3 = chord.detectIndex { |n|
            ((n % 12) == 4) or: { (n % 12) == 3 } // major or minor 3rd
        };
        if(idx3.notNil) {
            if(0.5.coin) {
                chord[idx3] = chord[idx3] - 2; // sus2
            } {
                chord[idx3] = chord[idx3] + 1; // sus4
            };
        };
    };

    // Drop 5th for openness
    if(probOmit5.coin) {
        chord = chord.reject { |n| (n % 12) == 7 };
    };

    chord
};

~enforceSuspensionRules = { |chord|
    var has2 = chord.any { |n| (n % 12) == 2 }; // D in C major
    var has4 = chord.any { |n| (n % 12) == 5 }; // F in C major

    if(has2 or: { has4 }) {
        // Remove major 3rd (4 semitones) or minor 3rd (3 semitones)
        chord = chord.reject { |n| ((n % 12) == 4) or: { (n % 12) == 3 } };
    };

    chord
};

// Build the final chord
~finalChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~voiceLeadChord.(degree);
    chord = ~applySuspensions.(chord);
    chord = ~enforceSuspensionRules.(chord);

	// Debug print final chord (both MIDI & Hz + voice count)
	("[Chord DEBUG] Voices: " ++ chord.size ++ " | MIDI: " ++ chord ++ " | Hz: " ++ chord.midicps).postln;


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

// Bring chord into register & optionally invert
~voiceSpread = { |midiNotes, center=60, spread=24|
    midiNotes.collect { |n|
        var x = n;
        while { x < (center - spread) } { x = x + 12 };
        while { x > (center + spread) } { x = x - 12 };
        x
    }.sort
};

// --- Markov second order harmony (degrees 1..7) ---
~degreeMarkov2 = (
    [1,1]: [[2,0.3],[3,0.3],[4,0.3],[5,0.1]],
    [1,2]: [[3,0.3],[4,0.4],[6,0.3]],
    [1,3]: [[4,0.4],[6,0.4],[2,0.2]],
    [1,4]: [[5,0.4],[2,0.3],[6,0.3]],
    [1,5]: [[6,0.4],[4,0.4],[2,0.2]],
    [1,6]: [[4,0.4],[2,0.3],[3,0.3]],
    [1,7]: [[1,0.3],[3,0.4],[4,0.3]],

    [2,1]: [[4,0.4],[5,0.3],[3,0.3]],
    [2,2]: [[4,0.4],[6,0.4],[1,0.2]],
    [2,3]: [[4,0.3],[1,0.3],[6,0.4]],
    [2,4]: [[5,0.3],[6,0.3],[1,0.4]],
    [2,5]: [[1,0.4],[6,0.3],[3,0.3]],
    [2,6]: [[4,0.4],[2,0.3],[1,0.3]],
    [2,7]: [[1,0.3],[4,0.4],[2,0.3]],

    [3,1]: [[6,0.4],[4,0.3],[2,0.3]],
    [3,2]: [[4,0.4],[1,0.3],[6,0.3]],
    [3,3]: [[6,0.3],[4,0.4],[1,0.3]],
    [3,4]: [[5,0.4],[6,0.3],[1,0.3]],
    [3,5]: [[1,0.3],[4,0.4],[2,0.3]],
    [3,6]: [[4,0.3],[1,0.4],[2,0.3]],
    [3,7]: [[1,0.4],[4,0.3],[3,0.3]],

    [4,1]: [[5,0.4],[2,0.3],[6,0.3]],
    [4,2]: [[5,0.3],[6,0.3],[1,0.4]],
    [4,3]: [[6,0.3],[1,0.4],[2,0.3]],
    [4,4]: [[5,0.4],[1,0.3],[6,0.3]],
    [4,5]: [[1,0.4],[6,0.3],[2,0.3]],
    [4,6]: [[2,0.4],[1,0.3],[5,0.3]],
    [4,7]: [[1,0.3],[4,0.4],[2,0.3]],

    [5,1]: [[6,0.4],[4,0.4],[2,0.2]],
    [5,2]: [[6,0.3],[4,0.4],[1,0.3]],
    [5,3]: [[1,0.3],[4,0.4],[6,0.3]],
    [5,4]: [[1,0.4],[6,0.4],[2,0.2]],
    [5,5]: [[1,0.4],[6,0.3],[4,0.3]],
    [5,6]: [[2,0.4],[4,0.3],[1,0.3]],
    [5,7]: [[1,0.3],[5,0.4],[2,0.3]],

    [6,1]: [[4,0.4],[2,0.3],[3,0.3]],
    [6,2]: [[4,0.3],[1,0.3],[5,0.4]],
    [6,3]: [[1,0.4],[4,0.3],[2,0.3]],
    [6,4]: [[5,0.4],[1,0.3],[2,0.3]],
    [6,5]: [[1,0.4],[6,0.3],[4,0.3]],
    [6,6]: [[4,0.4],[2,0.3],[1,0.3]],
    [6,7]: [[1,0.3],[4,0.4],[2,0.3]],

    [7,1]: [[5,0.4],[3,0.3],[4,0.3]],
    [7,2]: [[4,0.3],[1,0.4],[6,0.3]],
    [7,3]: [[1,0.4],[4,0.3],[2,0.3]],
    [7,4]: [[1,0.3],[6,0.3],[5,0.4]],
    [7,5]: [[1,0.4],[6,0.3],[4,0.3]],
    [7,6]: [[4,0.4],[2,0.3],[1,0.3]],
    [7,7]: [[1,0.4],[4,0.3],[2,0.3]]
);


~prevDegree = 5;
~currentDegree = 1; // starting point

~nextDegree2 = {
    var key = [~prevDegree, ~currentDegree];
    var pairs = ~degreeMarkov2[key] ? [[1, 1.0]]; // fallback if no entry

    var total = pairs.sum { |p| p[1] };
    var r = total.rand, acc = 0.0;
    var result;

    result = pairs.detect { |p|
        acc = acc + p[1];
        r < acc
    }[0];

    // shift degrees for next step
    ~prevDegree = ~currentDegree;
    ~currentDegree = result;

    result
};

~nextChord = {
    var deg, chord;

    deg = ~nextDegree2.(~currentDegree) ? 1; // fallback to degree 1 if nil
    ~currentDegree = deg;

    chord = ~finalChord.(deg, 4, 0.3);
    chord = ~voiceSpread.(chord, 60, 24);

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

~clampBassRange = { |note, min=24, max=48|
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
~chordData = Pbind(
    \dur, Pfunc({ ~getMapped.(\dur) }),
    \chord, Pfunc { ~nextChord.() },
    \bass,  Pfunc { |ev| ~clampBassRange.(ev[\chord][0] - 24) }
);

~padPattern = Pbindf(
    ~chordData, // inherit \dur, \chord, \bass
    \instrument, \padSynth,
	 \dur, Pfunc({ ~getMapped.(\dur) }),
	\legato, Pfunc({ ~getMapped.(\legato) - 0.05 }),
	\freq, Pfunc { |ev|
		var freqs = ev[\chord].midicps; // chord comes from Pkey(\chord) in ~chordData
		var detune = ~getMapped.(\detune);
		var n = ~getMapped.(\numVoices);
		var voices = Array.fill(n, { |i|
			freqs + (detune * (i - (n - 1) / 2))
		}).flat;

		if (n > 5) {
			voices = voices ++ (voices * 2); // octave up
		};

		voices
	},
	\pan, Pfunc({
		var n = ~getMapped.(\numVoices);
		Array.fill(n, { |i|
			(i / (n - 1)) * 2 - 1 // evenly spread between -1 and 1
		}).flat
	}),

	// Variability -> modRate
	\modRate, Pfunc({ ~getMapped.(\modRate) }),

	// Brightness -> filter cutoff
	\ffreq, Pfunc({ ~getMapped.(\filterCutoff) }),

	\revMix, Pfunc({ ~getMapped.(\revMix) * 0.7}),
	\atk, Pfunc({ ~getMapped.(\atk) }),
	\rel, Pfunc({ ~getMapped.(\rel) }),
	\rq,  Pfunc({ ~getMapped.(\rq) }),
	\amp, Pfunc { |ev|
		var chord = ev[\chord];
		var amp = ~getAmpForVoices.(chord.size);
		amp
	},
);

~bassPattern = Pbindf(
    ~chordData, // inherit \dur, \chord, \bass
    \instrument, \bassSynth,
	\dur, Pfunc({ ~getMapped.(\dur) }),
	\legato, Pfunc({ ~getMapped.(\legato) - 0.05 }),
	\freq, Pkey(\bass).collect(_.midicps),
	\ffreq, Pfunc({ ~getMapped.(\filterCutoff) }),
	\rq, Pfunc({ ~getMapped.(\rq) }),
	\subOct, Pfunc({ ~getMapped.(\sub) }),
	\drive, Pfunc({ ~getMapped.(\drive) }),
	\atk, Pfunc({ ~getMapped.(\atk) }),
	\rel, Pfunc({ ~getMapped.(\rel) }),
	\amp, Pfunc({ ~getMapped.(\bassAmp) }),
);

~seaPattern = Pbind(
	\instrument, \textureSynth,
	\dur, Pfunc({ ~getMapped.(\dur) }),
	\legato, Pfunc({ ~getMapped.(\legato) - 0.05 }),
	\ffreq, Pfunc({ ~getMapped.(\filterCutoff) }),
	\rq, Pfunc({ ~getMapped.(\rq) }),
	\modRate, Pfunc({ ~getMapped.(\modRate) }),
	\modDepth, Pfunc({ ~getMapped.(\modDepth) }),
	\pinkAmt, Pfunc({ ~getMapped.(\noisePink) }),
	\whiteAmt, Pfunc({ ~getMapped.(\noiseWhite) }),
	\revMix, Pfunc({ ~getMapped.(\revMix) }),
	\pan, Pwhite(-1.0, 1.0),
    \amp, Pfunc({ ~getMapped.(\texAmp) }),
);

~vinylPattern = Pbind(
    \instrument, \vinylCrackle,
    \dustDensity, Pfunc({ ~mapExp.(~parameters[\density], 0, 1, 2, 12) }),
    \lpFreq, Pwhite(1500, 5000),
    \hpFreq, Pwhite(700, 1200),
    \amp, Pwhite(0.03, 0.15),
    \dur, Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 6, 1).round.asInteger ** 2 })
);


Pdef(\ambgen,
    Ppar([ ~padPattern, ~bassPattern, ~seaPattern, ~vinylPattern ])
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
~setParam.(\warmth, 0.9);

// Brightness: 0 (dark/muffled) → 1 (bright/open)
~setParam.(\brightness, 0.2);

// Density: 0 (few voices) → 1 (many voices)
~setParam.(\density, 0.3);

// Variability: 0 (slow/static) → 1 (fast/changing)
~setParam.(\variability, 0.3);

// Rhythmicity: 0 (smooth/legato) → 1 (tight/rhythmic)
~setParam.(\rhythmicity, 0.1);

~parameters.postln;


// Show mapped values
~showMappedParams.();
