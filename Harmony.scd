(
// --- Harmony Engine ---

// Load scales
"Scales.scd".loadRelative;

// choose scale by name
~setScale = { |name=\ionian|
	var pcs = ~scales[name];
	if(pcs.isNil) {
		("Unknown scale: " ++ name ++ " → defaulting to ionian").warn;
		pcs = ~scales[\ionian];
	};
	~scalePcs = pcs;
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

// Define allowed drone anchors
~droneDegrees = [1, 2, 4, 5];

// Set the drone note
~getDroneNote = { |degree=2, octaveShift=3|
	var scale = ~scaleToMidi.();
	var note = scale.wrapAt(degree - 1); // pick scale degree
	note = note + (12 * octaveShift);           // shift if needed
	("[Drone] Note: " ++ note ++ " | "
		++ note.midicps).postln;

	note
};

// Getter for chord size with randomness influenced by variability
~getChordSize = {
	var baseSize = ~mapLin.(~parameters[\density], 0, 1, 2, 5).round.asInteger;
	var varChance = ~mapLin.(~parameters[\variability], 0, 1, 0.0, 0.6);

	// Randomly add or subtract 1 based on variability chance
	if(varChance.coin) {
		baseSize = baseSize + ([-1, 1].choose);
	};

	// Constrain size between 2 and 5 voices
	baseSize.clip(2, 5)
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
		("[WeightedChord] Duplicate found: " ++ chosenSteps).warn;
	} {
		("[WeightedChord] Unique notes: " ++ chosenSteps).postln;
	};

	// map steps to MIDI and sort
	chosenSteps = chosenSteps.sort;
	chosenSteps.collect { |s|
		scaleMidis.wrapAt(rootIndex + s)
	}
};

// Range for notes
~clampChordRangeDynamic = { |notes|
	var root, minNote, maxNote, clamped;
	root = notes.first;  // assume first note = root
	minNote = root - 7;  // perfect 5th below root
	maxNote = root + 24; // 2 octaves above root

	clamped = notes.collect { |n|
		var x = n;
		while { x < minNote } { x = x + 12 };
		while { x > maxNote } { x = x - 12 };
		x
	};

	// Debug
	("[RelClamp] Root: " ++ root
		++ " | Range: " ++ minNote ++ "-" ++ maxNote
		++ " | Before: " ++ notes
		++ " | After: " ++ clamped).postln;

	clamped
};

// Boundries for notes
~clampChordRangeStatic = { |notes|
	var bright = ~mapLin.(~parameters[\warmth], 0, 1, 12, 0).round.asInteger;
	var minNote = 48 + bright;
	var maxNote = minNote + ~mapLin.(~parameters[\density], 0, 1, 24, 20).round.asInteger;

	var clamped = notes.collect { |n|
		var x = n;
		while { x < minNote } { x = x + 12 };
		while { x > maxNote } { x = x - 12 };
		x
	};

	// Debug print
	("[AbsClamp]  Min: " ++ minNote
		++ " | Max: " ++ maxNote
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
	chord = ~clampChordRangeStatic.(chord);

	// Debug print final chord (both MIDI & Hz + voice count)
	("[Final Chord @ " ++ Main.elapsedTime.round(0.01) ++ "] Voices: "
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
~getAmpForVoices = { |voices|
	var amp = 0.2 / (voices * 9);
	amp
};

// --- Load Markov Tables ---

"Markov-Tables.scd".loadRelative;


// Function to choose a Markov table
~chooseMarkov = {
	var n = ~scalePcs.size;
	var v = ~parameters[\variability];

	if(n == 5) {
		"[Markov] Using Pentatonic Markov table".postln;
		~degreeMarkov2Pent

	} {
		if(n == 6) {
			"[Markov] Using Hexatonic Markov table".postln;
			~degreeMarkov2Hex

		} {
			if(n == 8) {
				"[Markov] Using Octatonic Markov table".postln;
				~degreeMarkov2Oct

			} {
				// Default case = heptatonic (7-note scales)
				if(v < 0.4) {
					"[Markov] Using Ambient Markov table".postln;
					~degreeMarkov2Ambient
				} {
					if(v < 0.75) {
						"[Markov] Using Balanced Markov table".postln;
						~degreeMarkov2
					} {
						"[Markov] Using Exotic Markov table".postln;
						~degreeMarkov2Exotic
					}
				}
			}
		}
	}
};

// Set start values
~prevDegree = 1;
~currentDegree = 4;
~sameDegreeCount = 0;

// Calculate next degree
~nextDegree = {
	var key, pairs, total, r, result, acc, penaltyFactor;

	pairs = ~degreeMarkov2[10 * ~prevDegree + ~currentDegree];

	// Debug print
	("[Markov] pairs: " ++ pairs).postln;

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
	("[Markov] previous: " ++ ~prevDegree
		++ " -> current: " ++ ~currentDegree
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
	("[Bass] MIDI: " ++ x ++ " | Hz: " ++ x.midicps).postln;

	x
};
)