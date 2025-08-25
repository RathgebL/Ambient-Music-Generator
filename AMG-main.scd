// ====== Server Utilities (with auto-reboot) ======

(
s.options.numAudioBusChannels = 512;

// Reset mixer utility
~resetMixer = {
	s.freeAll;            // frees all synths, groups, and releases buses
	s.newBusAllocators;   // reset bus allocators
	"Mixer fully reset.".postln;
};

// Reboot server, then open GUIs when ready
s.reboot;

s.waitForBoot({
	~openMonitors = {
		s.meter;
		s.plotTree;
		s.scope;
	};
	~openMonitors.();
	">>> Server booted and monitors opened.".postln
});
)


// ====== Buses ======

~resetMixer.();
~busesAllocated = false;
"Buses.scd".loadRelative;
~allocBuses.();


// ====== Engines ======

(
// --- Load Mixing Console ---
"Mixing-Console.scd".loadRelative;


// --- Load Mixing Console GUI ---
"Mixing-Console-GUI.scd".loadRelative;


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

// Control buses parameter
~paramBuses = IdentityDictionary[
	\warmth     -> Bus.control(s,1),
	\brightness -> Bus.control(s,1),
	\density    -> Bus.control(s,1),
	\variability-> Bus.control(s,1),
	\rhythmicity-> Bus.control(s,1)
];


// Linear mapping function
~mapLin = { |val, inMin=0, inMax=1, outMin=0, outMax=1|
	((val - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
};

// Exponential mapping function
~mapExp = { |val, inMin=0, inMax=1, outMin=100, outMax=8000|
	var t = ((val - inMin) / (inMax - inMin)).clip(0,1);
	outMin * ((outMax/outMin) ** t)
};

// load mapped parameters
"Parameter-Mappings.scd".loadRelative;

// Init buses once per mapping
~paramBuses = IdentityDictionary.new;
~parameterMappings.keysDo { |key|
	if(~paramBuses[key].isNil) {
		~paramBuses[key] = Bus.control(s,1);
	};
};

// Add FX buses as well
~paramBuses[\reverb]    = ~revCtrl;
~paramBuses[\delay]     = ~delCtrl;
~paramBuses[\comp]      = ~compCtrl;
~paramBuses[\saturator] = ~satCtrl;
~paramBuses[\fxMaster]  = ~fxGroupCtrl;

// Safe updater task
~updateParamBusesTask = Task({
	inf.do {
		~parameterMappings.keysValuesDo { |key, func|
			if(~paramBuses[key].notNil) {
				try {
					~paramBuses[key].set(func.());
				} {
					("[updateParamBuses] Failed for % (maybe synth freed)"
						.format(key)).warn;
				};
			};
		};
		0.1.wait;
	}
});

// Start once
~updateParamBuses = {
	if(~updateParamBusesTask.isPlaying.not) {
		~updateParamBusesTask.play(TempoClock.default);
	} {
		"[updateParamBuses] already running".postln;
	};
};

// Run update bus function
~paramUpdater = ~updateParamBuses.();

// Quick set (safe)
~setParam = { |key, val|
	var mapped;
	~ensureParams.();
	~parameters[key] = val.clip(0,1);

	// compute mapped value
	mapped = ~getMapped.(key);

	// only try to set if bus exists AND is valid
	if(mapped.notNil and: { ~paramBuses[key].notNil }) {
		try {
			~paramBuses[key].set(mapped);
		} {
			("[ParamUpdate] FAILED for % → bus % (maybe synth freed)"
				.format(key, ~paramBuses[key])).warn;
		};
	} {
		("[ParamUpdate] skipped % → % (no mapped or no bus)"
			.format(key, val)).postln;
	};

	/*("[ParamUpdate] % = %, mapped → %"
	.format(key, val, mapped ?? "nil")).postln;*/
};

// Sets multiple parameters
~setParams = { |pairs|
	pairs.keysValuesDo { |k, v| ~setParam.(k, v) };
};

// Helpers
~getParam = { |param| ~parameters[param] };
~getMapped = { |param| var f = ~parameterMappings[param]; f !? { f.() } };

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


// --- Control Engine ---

~genDurations = { |totalDur=8|
	var choices, weights, remaining, result;
	var rhythmicity = ~parameters[\rhythmicity];
	var variability = ~parameters[\variability];
	("Parameters: " ++ rhythmicity ++ ", " ++ variability).postln;

	// --- Choices depend on rhythmicity ---
	choices = [
		[500000, 250000, 125000] * totalDur,
		[250000, 125000, 62500] * totalDur,
		[125000, 62500, 31250] * totalDur,
		[62500, 31250, 15625] * totalDur
	].at((rhythmicity * 3).round.clip(0, 3));

	// --- Weights depend on variability ---
	weights = [
		[10,26,10],
		[10,18,10],
		[10,14,10],
		[10,12,10]
	].at((variability * 3).round.clip(0, 3));

	// ---Generate sequence fitting exactly into totalDur ---

	remaining = totalDur * 1000000; // re-adjustment factor
	result = List[];

	while { remaining > 0 } {
		var possibleIdx = choices.selectIndices { |c| c <= remaining };
		var choice = choices[possibleIdx].wchoose(weights[possibleIdx].normalizeSum);

		result.add(choice);
		remaining = remaining - choice;
	};

	result = result.collect { |x| x * 0.000001 };

	// Debug print the full result
	("[Arp] Array size: " ++ result.size ++ " | Array: " ++ result).postln;

	result
};

// Toggle intruments
~layerOn = IdentityDictionary[
	\Pad -> false,
	\DarkPad -> true,
	\Bass -> false,
	\Drone ->true,
	\HarpArp -> true,
	\GlassArp -> false,
	\Bell -> false,
	\SeaTex -> true,
	\RainTex -> false,
	\VinylTex -> false
];


// Map your channel names → control buses
~channelBus = IdentityDictionary[
	\Pad        -> ~padCtrl,
	\DarkPad    -> ~darkPadCtrl,
	\Bass       -> ~bassCtrl,
	\Drone      -> ~droneCtrl,
	\Bell       -> ~bellCtrl,
	\HarpArp    -> ~harpCtrl,
	\GlassArp   -> ~glassCtrl,
	\SeaTex     -> ~seaCtrl,
	\RainTex    -> ~rainCtrl,
	\VinylTex   -> ~vinylCtrl,

	// FX + group/master
	\FXMaster   -> ~fxGroupCtrl,
	\ReverbFX   -> ~revCtrl,
	\DelayFX    -> ~delCtrl,
	\CompFX     -> ~compCtrl,
	\SaturatorFX-> ~satCtrl,
	\Master     -> ~masterCtrl
];


// --- Fade Helpers ---

~busLevels = IdentityDictionary.new;

~fadeSmart = { |bus, target=0.0, time=8.0|
	var current = (~busLevels[bus] ? 0.0).max(0.0001);
	var start, curve;

	if(current <= 0.001 and: { target > 0 }) {
		// case 1: new instrument (fade in from silence)
		start = 0.0001;
		curve = -0.5;   // gentle exponential rise
	} {
		if(target <= 0.001) {
			// case 2: fade out
			start = current;
			curve = 0.5; // convex (smooth decay)
		} {
			// case 3: adjustment (between two non-zero values)
			start = current;
			curve = 0;   // linear
		}
	};

	Synth(\fade, [
		\bus, bus,
		\start, start,
		\end, target,
		\dur, time,
		\curve, curve
	], target: ~controlGroup);

	~busLevels[bus] = target;  // update mirror

	("[Fade] bus % (idx %) from % to % in %s (curve %)"
		.format(bus, bus.index, start, target, time, curve)).postln;
};


~targetsToFades = { |targets, time=8|
	if(targets.isNil) { ^nil };

	targets.keysValuesDo { |k, v|
		var bus = ~channelBus[k];
		if(bus.notNil) {
			~fadeSmart.(bus, v, time);
		} {
			("[Target] WARNING: No bus for " ++ k).postln;
		};
	};
};

//  Set instrument faders
~setInstFaders = {|setValue|
    [
        ~padCtrl, ~darkPadCtrl, ~bassCtrl, ~droneCtrl, ~bellCtrl,
		~harpCtrl, ~glassCtrl, ~seaCtrl, ~rainCtrl, ~vinylCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
	("[Faders] Instrument set to " ++ setValue).postln;
};

//  Set group faders
~setGroupFaders = {|setValue|
    [
        ~padGroupCtrl, ~bassGroupCtrl, ~droneGroupCtrl,
        ~bellGroupCtrl, ~arpGroupCtrl, ~texGroupCtrl, ~fxGroupCtrl,
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Groups set to " ++ setValue).postln;
};
//  Set FX faders
~setFxFaders = {|setValue|
    [
        ~revCtrl, ~compCtrl, ~delCtrl, ~satCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] FX set to " ++ setValue).postln;
};

//  Set dry sends
~setDrySends = {|setValue|
    [
        ~padDryCtrl, ~bassDryCtrl, ~droneDryCtrl,
        ~bellDryCtrl, ~arpDryCtrl, ~texDryCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Dry sends set to " ++ setValue).postln;
};

//  Set master faders
~setMasterFaders = {|setValue|
    [
		~fxGroupCtrl, ~masterCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Master set to " ++ setValue).postln;
};

// Gradually change high level parameters
~rampParam = { |key, to, dur=60, curve=\lin|
	var start = ~getParam.(key) ?? 0.5;
	var env   = Env([start, to], [dur], curve);
	var mult = 10;
	var steps = dur * mult;

	("[Ramp] Starting ramp for %: start=%, target=%, steps=%, curve=%"
		.format(key, start, to, steps, curve)).postln;

	Task({
		env.asSignal(dur * 10).do { |val, i|
			~setParam.(key, val);  // safe bus update
			/*("    step %/% → % = %, mapped → %"
			.format(i, steps, key, val.round(0.001), ~getMapped.(key) ?? "nil")).postln;*/
			(1/mult).wait;
		};

		// final target
		~setParam.(key, to);
		("[Ramp] Finished ramp for % at final value % (mapped → %)"
			.format(key, to, ~getMapped.(key))).postln;
	}).start;
};


// --- Score Helpers ---
~normalizeScore = { |score|
	var val, dict;
	if(score.isNil) { ^IdentityDictionary[] };

	("[Normalize] input class: " ++ score.class).postln;

	// Convert Event → IdentityDictionary
	dict = if(score.isKindOf(Event)) {
		("[Normalize] converting Event to IdentityDictionary").postln;
		IdentityDictionary.newFrom(score)
	} {
		score
	};

	("[Normalize] after Event conversion → " ++ dict.class).postln;

	// Normalize fields
	[\layersOn, \targets, \params, \fx].do { |key|
		val = dict[key];
		if(val.notNil) {
			if(val.isKindOf(Event)) {
				("[Normalize] key " ++ key ++ " is Event, converting").postln;
				dict[key] = IdentityDictionary.newFrom(val);
			} {
				if(val.isKindOf(Dictionary).not) {
					("[Normalize] WARNING: key " ++ key ++ " is not a Dictionary, but " ++ val.class).warn;
				};
			};
		};
	};

	("[Normalize] output keys: " ++ dict.keys).postln;
	dict;
};

// Apply a score with smooth fades + param ramps
~enterScore = { |score|
	var allParams;

	score = ~normalizeScore.(score);  // ensure proper format
	("[Score] Entering score: " ++ score[\name]).postln;

	// Scale / key (optional)
	if(score[\key].notNil)   { ~setKey.(score[\key][0], score[\key][1]) };
	if(score[\scale].notNil) { ~setScale.(score[\scale]) };

	// Update layers
	if(score[\layersOn].notNil) {
		~layerOn.keysDo { |k|
			~layerOn[k] = score[\layersOn][k] ? false.asBoolean;
		};
		("[Score] Updated layerOn: " ++ ~layerOn).postln;
	};

	// Fade to target
	if(score[\targets].notNil) {
		~targetsToFades.(score[\targets], score[\fadeTime] ? 12);
	};

	// unify fx + params
	allParams = IdentityDictionary[];
	if(score[\params].notNil) {
		allParams.putAll(score[\params]);
	};
	if(score[\fx].notNil) {
		score[\fx].keysValuesDo { |k,v|
			var mappedKey = case
			{ k == \reverb    } { \reverb }
			{ k == \delay     } { \delay }
			{ k == \comp      } { \comp }
			{ k == \saturator } { \saturator }
			{ k == \fxMaster  } { \fxMaster }
			{ k }; // fallback
			allParams[mappedKey] = v;
		};
	};

	if(allParams.notEmpty) {
		allParams.keysValuesDo { |k,v|
			~rampParam.(k, v, score[\paramTime] ? (score[\fadeTime] ? 12));
		};
	};
};


// --- Scores (Presets) ---

~scores = [
	(
		name: \intro, fadeTime: 10, paramTime: 40, dur: 4,
		key: [\D, 3], scale: \yo,
		layersOn: (SeaTex:true, Drone:true, Pad:false, DarkPad:false, Bass:false, HarpArp:false, GlassArp:false, Bell:false, RainTex:true, VinylTex:true),
		targets: (SeaTex:1.0, Drone:1.0, DarkPad:0, Pad:0, Bass:0, Bell:0, HarpArp:0, GlassArp:0, Bell:0, RainTex:0.01, VinylTex:0.01, Master:1.0, FXMaster:0.85, ReverbFX:0.6, DelayFX:0.2),
		params: (warmth:0.4, brightness:0.35, density:0.2, variability:0.2, rhythmicity:0.3)
	),

	(
		name: \firstPads, fadeTime: 12, paramTime: 60, dur: 8,
		layersOn: (DarkPad:true, Drone:true, SeaTex:true),
		targets: (DarkPad:1.0, Drone:0.7, SeaTex:0.8, Master:1.0, ReverbFX:0.50, DelayFX:0.30),
		params: (warmth:0.3, brightness:0.45, density:0.3, variability:0.3, rhythmicity:0.5)
	),

	(
		name: \shimmer, fadeTime: 10, paramTime: 60, dur: 6,
		scale: \lydianDominant,
		layersOn: (GlassArp:true, Pad:true, RainTex:true, DarkPad:true, Drone:true, SeaTex:true),
		targets: (GlassArp:1.0, Pad:0.7, RainTex:0.8, SeaTex:0, DarkPad:0, Drone:0, DelayFX:0.4, ReverbFX:0.7),
		params: (brightness:0.6, density:0.3, variability:0.35, warmth:0.8, rhythmicity:0.3)
	),

	(
		name: \ground, fadeTime: 16, paramTime: 70, dur: 12,
		layersOn: (Bass:true, DarkPad:true, RainTex:true, GlassArp:true, Pad:true, Drone:false, SeaTex:false),
		targets: (Bass:0.6, DarkPad:1.0, RainTex:0.6, GlassArp:0, Pad:0, Master:1.0, DelayFX:0.1, SaturatorFX:0.5),
		params: (warmth:0.5, brightness:0.5, density:0.38, rhythmicity:0.7)
	),

	(
		name: \punctuate, fadeTime: 6, paramTime: 30, dur: 6,
		layersOn: (Bell:true, HarpArp:true, VinylTex:true, RainTex:true, Bass:true, DarkPad:true),
		targets: (VinylTex:0.8, Bell:0.7, HarpArp:1.0, Bass:0, DarkPad:0, RainTex:0, Master:1.0, ReverbFX:0.3),
		params: (variability:0.3, density:0.3, rhythmicity:0.2, warmth:0.7)
	),

	(
		name: \exhale, fadeTime: 12, paramTime: 60, dur: 8,
		scale: \inSen,
		layersOn: (Pad:true, Drone:true, Bass:true, VinylTex:true, RainTex:false, Bass:false, DarkPad:false),
		targets: (Bass:0.5, Pad:1.0, Drone:1.0, Master:1.0, DelayFX:0.2, ReverbFX:0.8),
		params: (warmth:0.4, brightness:0.35, density:0.2, variability:0.15)
	)
];
)


// ====== SynthDefs ======

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


// ====== Pdefs ======

(
~makePatterns = {
	// Sea
	Pdef(\sea,
		Pbind(
			\instrument, \seaSynth,
			\legato,      Pwhite(0.95, 1.05),

			// time between waves, in beats
			\dur,         Pfunc { ~getMapped.(\dur) },

			// envelope shaping (fractions of dur)
			\atkFrac,     Pwhite(0.1, 0.4),
			\susFrac,     Pwhite(0.05, 0.2),

			// convert fractions to actual seconds
			\atk, Pfunc { |ev|
				ev[\atkFrac] * ev[\dur] * thisThread.clock.beatDur
			},
			\sus, Pfunc { |ev|
				ev[\susFrac] * ev[\dur] * thisThread.clock.beatDur
			},
			\rel, Pfunc { |ev|
				var beatDur   = thisThread.clock.beatDur;
				var totalBeats = ev[\dur];
				var atkBeats   = ev[\atkFrac] * totalBeats;
				var susBeats   = ev[\susFrac] * totalBeats;
				var relBeats   = (totalBeats - atkBeats - susBeats).max(0.1);
				relBeats * beatDur
			},

			// synthesis params
			\waveDepth,   Pfunc({ ~mapLin.(~parameters[\density], 0, 1, 0.1, 0.6) }),
			\pan,         Pwhite(-1.0, 1.0),
			\amp,         Pfunc({ ~getMapped.(\seaAmp) }),
			\out,         ~seaBus
		)
	);

	// Vinyl
	Pdef(\vinyl,
		Pbind(
			\instrument,   \vinylCrackle,
			\dur,          Pfunc({ (~getMapped.(\dur) ? 1).max(0.01) }), // safe fallback, never 0/nil
			\dustDensity,  Pfunc({
				var lo = 10 - rrand(0, 3);
				var hi = 20 - rrand(0, 5);
				~mapExp.(~parameters[\density], 0, 1, lo, hi)
			}),
			\lpFreq,       Pwhite(2000, 5000),
			\hpFreq,       Pwhite(500, 1500),
			\amp,          Pfunc({ ~getMapped.(\vinylAmp) }),
			\out,          ~vinylBus
		)
	);

	// Rain
	Pdef(\rain,
		Pbind(
			\instrument, \rainTexture,
			\dur,        Pfunc({ ~getMapped.(\dur) }),
			\densFactor, Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 1, 2) }),
			\hp,         Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 200, 2000) }),
			\lp,         Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 3000, 8000) }),
			\amp,        Pfunc({ ~getMapped.(\rainAmp) }),
			\out,        ~rainBus
		)
	);

	"[Patterns] Rebuilt and registered into Pdefs".postln;
};


// Generator
Pdef(\ambgen,
	Pspawner { |sp|
		var padSynths = List[];
		var darkPadSynths = List[];
		var bassSynths = List[];
		var droneSynths = List[];

		var chord, dur, durations, padFreqs, padPans, bassFreq;

		// Background textures
		sp.par(Pdef(\vinyl));
		sp.par(Pdef(\rain));
		sp.par(Pdef(\sea));

		loop {
			chord = ~nextChord.();
			dur   = ~getMapped.(\dur);
			durations = ~genDurations.(dur);

			// trigger score fade if pending
			if(~nextScore.notNil) {
				~enterScore.(~nextScore);
				~nextScore = nil;
			};

			// stop old synths
			padSynths.do { |s| s.set(\gate, 0) };      padSynths.clear;
			darkPadSynths.do { |s| s.set(\gate, 0) };  darkPadSynths.clear;
			bassSynths.do { |s| s.set(\gate, 0) };     bassSynths.clear;
			droneSynths.do { |s| s.set(\gate, 0) };    droneSynths.clear;

			// precompute pad freqs
			padFreqs = {
				var freqs, detune, n, baseVoices, octaveVoices, octaveAmpFactor, voicePairs;
				freqs  = chord.midicps;
				detune = ~getMapped.(\detune);
				n      = ~getMapped.(\numVoices);

				baseVoices = Array.fill(n, { |i|
					freqs + (detune * (i - (n - 1) / 2))
				}).flat;

				octaveVoices = baseVoices * 2;
				octaveAmpFactor = ~mapExp.(~parameters[\density], 0, 1, 0.1, 0.2);

				voicePairs = baseVoices.collect { |f| [f, 1.0] }
				++ octaveVoices.collect { |f| [f, octaveAmpFactor] };

				voicePairs.collect(_.first)
			}.value;

			padPans = Array.fill(padFreqs.size, { |i|
				(i / (padFreqs.size.max(1) - 1)).linlin(0, 1, -1, 1)
			});

			// bass register
			bassFreq = ~clampBassRange.(chord[0] - 24).midicps;

			// PAD
			if(~layerOn[\Pad]) {
				padFreqs.do { |f, i|
					padSynths.add(Synth(\padSynth, [
						\dur,    ~getMapped.(\dur),
						\freq,   f,
						\pan,    padPans[i],
						\legato, ~getMapped.(\legato),
						\amp,    ~getAmpForVoices.(chord.size),
						\out,    ~padBus
					]));
				};
			};

			// DARK PAD
			if(~layerOn[\DarkPad]) {
				padFreqs.do { |f, i|
					darkPadSynths.add(Synth(\darkPad, [
						\dur,    ~getMapped.(\dur),
						\freq,   f * 0.5,
						\legato, ~getMapped.(\legato),
						\pan,    padPans[i],
						\amp,    ~getAmpForVoices.(chord.size),
						\out,    ~darkPadBus
					]));
				};
			};

			// BASS
			if(~layerOn[\Bass]) {
				bassSynths.add(Synth(\bassSynth, [
					\dur,    ~getMapped.(\dur),
					\freq,   bassFreq,
					\legato, ~getMapped.(\legato) * 0.97,
					\amp,    ~getMapped.(\bassAmp),
					\out,    ~bassBus
				]));
			};

			// DRONE
			if(~layerOn[\Drone]) {
				droneSynths.add(Synth(\droneSynth, [
					\dur,    ~getMapped.(\dur),
					\legato, ~getMapped.(\legato) * 0.97,
					\freq,   ~getDroneNote.(~droneDegrees.choose, 2).midicps,
					\pan,    rrand(-0.5, 0.5),
					\amp,    ~getMapped.(\droneAmp),
					\out,    ~droneBus
				]));
			};

			// HARP ARP
			if(~layerOn[\HarpArp]) {
				sp.par(
					Pbind(
						\instrument, \harpPluck,
						\dur,   ~getMapped.(\dur),
						\dur,   Pseq(durations, 1),
						\freq,  Pxrand(chord.midicps, inf),
						\decay, Pwhite(2, 5, inf),
						\pan,   Pwhite(-0.6, 0.6, inf),
						\amp,   ~getMapped.(\harpAmp),
						\out,   ~harpBus
					)
				);
			};

			// GLASS ARP
			if(~layerOn[\GlassArp]) {
				sp.par(
					Pbind(
						\instrument, \glassArp,
						\dur,   Pseq(durations, 1),
						\freq, Pxrand(chord.midicps * 2, inf),
						\pan,   Pwhite(-0.6, 0.6, inf),
						\amp,   ~getMapped.(\glassAmp),
						\out,   ~glassBus
					)
				);
			};

			// BELL
			if(~layerOn[\Bell]) {
				sp.par(
					Pbind(
						\instrument, \bell,
						\dur,    Pseq(Array.fill(4, { dur/4 }), 1),
						\legato, ~getMapped.(\legato) * 0.97,
						\freq,   bassFreq * 2,
						\amp,    ~getMapped.(\bellAmp),
						\out,    ~bellBus,
						\type,   Pseq({
							var decisions = Array.fill(4, { \rest });
							var step = (0..3);
							var bellPlayed = false;
							step.do { |i|
								if (bellPlayed.not) {
									var options, weights, chosen;
									switch(i,
										0, { options = [\note, \rest]; weights = [0.3, 0.7]; },
										2, { options = [\note, \rest]; weights = [0.1, 0.9]; },
										1, { options = [\note, \rest]; weights = [0.05, 0.95]; },
										3, { options = [\note, \rest]; weights = [0.05, 0.95]; },
										{ options = [\rest]; weights = [1.0]; }
									);
									chosen = options.wchoose(weights);
									decisions[i] = chosen;
									if (chosen == \note) { bellPlayed = true };
								};
							};
							decisions
						}.(), 1),
					)
				);
			};

			sp.wait(dur);
		}
	}
);
)


// --- Routine Helpers ---

(
// A global dictionary to track running routines
~routines = IdentityDictionary.new;

// Safe routine starter
~startRoutine = { |name, routineFunc|
	var existing = ~routines[name];
	if(existing.notNil and: { existing.isPlaying }) {
		("[Routine] " ++ name ++ " already running. Skipping.").postln;
		existing  // return the existing one
	} {
		var r = routineFunc.();
		r.play(TempoClock.default);
		~routines[name] = r; // store in dictionary
		("[Routine] Started " ++ name).postln;
		r  // return the new routine
	};
};

// Safe stopper
~stopRoutine = { |name|
	var r = ~routines[name];
	if(r.notNil and: { r.isPlaying }) {
		r.stop;
		("[Routine] Stopped " ++ name).postln;
		~routines.removeAt(name); // cleanup
	} {
		("[Routine] Not running: " ++ name).postln;
	};
};
)


// ====== Players ======

// --- Conductor to play a piece of ambient music (with Scores) ---

(
~startRoutine.(\conductor, {
	Routine({
		//  Start mixer engine
		if(~startMixingEngine.notNil) {
			~startMixingEngine.();
			s.sync;
			">>> Mixing engine started".postln;
		};

		// Set faders back before creating the GUI
		~setInstFaders.(0);
		~setGroupFaders.(1);
		~setDrySends.(1);
		~setFxFaders.(1);
		~setMasterFaders.(1);

		0.2.wait;

		// Start mixer GUI (safe to call multiple times)
		if(~makeMixerGUI.notNil) {
			{
				~makeMixerGUI.();
				">>> Mixer GUI started".postln;
			}.defer;  // run whole block on AppClock
		};

		0.4.wait;

		~startGuiUpdater.();

		// Start the patterns
		if(~makePatterns.notNil) {
			~makePatterns.();
			"[Conductor] Patterns created."
		};

		// Start ambgen if not running
		if(Pdef(\ambgen).isPlaying.not) {
			">>> Starting Ambient Music Generator".postln;
			Pdef(\ambgen).play;
		};

		// Cycle through scores
		~scores.do { |sc|
			("[Conductor] Queuing score: " ++ sc[\name]).postln;
			~nextScore = sc;   // only mark it, don't enter yet
			(sc[\dur] * (~getMapped.(\dur) ? 8)).wait;
		};
	})
});
)

~stopRoutine.(\conductor);


// --- FreePlayer to play improvised ambient music (with automatic scale and instrument changes) ---

(

~startRoutine.(\freePlayer, {
	Routine({
		var allScales, weights, textures, pads, arps, others, active, tex, pad, arp, fx, nInstruments, varChance, cycleWait, extras, fades, fadeTime, waitTime, factors, idx;

		//  Start mixer engine
		if(~startMixingEngine.notNil) {
			~startMixingEngine.();
			s.sync;
			">>> Mixing engine started".postln;
		};

		// Set faders up before creating the GUI
		~setInstFaders.(0);
		~setGroupFaders.(1);
		~setDrySends.(1);
		~setFxFaders.(0.3);
		~setMasterFaders.(1);

		0.2.wait;

		// Start mixer GUI (safe to call multiple times)
		if(~makeMixerGUI.notNil) {
			{
				~makeMixerGUI.();
				">>> Mixer GUI started".postln;
			}.defer;  // run whole block on AppClock
		};

		0.4.wait;

		~startGuiUpdater.();

		// Start the patterns
		if(~makePatterns.notNil) {
			~makePatterns.();
			"[Conductor] Patterns created."
		};

		if(Pdef(\ambgen).isPlaying.not) {
			">>> Starting ambgen".postln;
			Pdef(\ambgen).play;
		};

		allScales = [
			// --- Heptatonic (7-note) ---
			"ionian", "dorian", "phrygian", "lydian",
			"mixolydian", "aeolian", "locrian",

			// --- Pentatonic (5-note) ---
			"majorPent", "minorPent", "egyptian",

			// --- Hexatonic (6-note) ---
			"wholeTone", "augmented", "tritone",

			// --- Octatonic (8-note) ---
			"dimWH", "dimHW",

			// --- Modal hybrids (7-note) ---
			"lydianDominant", "phrygianDominant",

			// --- Ethereal / world-inspired ---
			"hirajoshi", "inSen", "yo", "iwato",

			// --- Exotic / other (7-note) ---
			"persian", "neapolitan", "enigmatic"
		];

		// weights must match array size
		weights = [
			// Heptatonic
			0.08, 0.08, 0.05, 0.08, 0.05, 0.08, 0.04,
			// Pentatonic
			0.08, 0.08, 0.05,
			// Hexatonic
			0.04, 0.03, 0.03,
			// Octatonic
			0.03, 0.03,
			// Modal hybrids
			0.04, 0.04,
			// Ethereal
			0.06, 0.05, 0.05, 0.05,
			// Exotic
			0.04, 0.03, 0.03
		];

		// instrument pools
		textures   = [\SeaTex, \RainTex, \VinylTex];
		pads       = [\Pad, \DarkPad];
		arps       = [\HarpArp, \GlassArp];
		others     = [\Drone, \Bass, \Bell];
		fx         = [\ReverbFX, \CompFX, \DelayFX, \SaturatorFX];


		loop {
			// SCALE SELECTION
			~setScale.(allScales.wchoose(weights).asSymbol);

			// wait time in chord cycles
			factors = [32, 24, 16, 12, 8, 6];
			idx = (~parameters[\variability] * 6).floor.clip(0, 5);
			waitTime = factors[idx] * ~getMapped.(\dur);

			("[freePlayer] New scale → " ++ ~currentScale ++ ", next in " ++ waitTime).postln;

			// INSTRUMENT SELECTION
			fadeTime = ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 12); // seconds to fade

			// Always one texture
			tex = textures.choose;

			// Optional pad
			pad = (1.rand == 0).if { pads.choose } { nil };

			// Optional arp
			arp = (1.rand == 0).if { arps.choose } { nil };

			// Decide total instrument count (2–6)
			nInstruments = ~mapLin.(~parameters[\density], 0, 1, 2, 6).round.asInteger;
			varChance = ~mapLin.(~parameters[\variability], 0, 1, 0.0, 0.6);
			if(varChance.coin) {
				nInstruments = (nInstruments + ([-1, 1].choose)).clip(2, 6);
			};

			// Build active set
			active = [tex];
			if(pad.notNil) { active = active.add(pad) };
			if(arp.notNil) { active = active.add(arp) };

			extras = others.scramble.copyRange(
				0,
				(nInstruments - active.size - 1).clip(0, others.size - 1)
			);
			active = active ++ extras;

			// FADES
			fades = IdentityDictionary[];

			// fade in chosen instruments
			active.do { |inst| fades[inst] = rrand(0.5, 1) };

			// fade out all others
			(~layerOn.keys.asArray ++ textures ++ pads ++ arps ++ others).as(Set).do { |inst|
				if(active.includes(inst).not) {
					fades[inst] = 0.0;
				};
			};

			// FX SELECTION
			fx.do { |fxName|
				if(0.7.coin) {
					fades[fxName] = exprand(0.1, 0.5);  // random but modest values
				} {
					fades[fxName] = 0.0;
				};
			};

			("[Free Player] Active instruments (fading): " ++ active).postln;
			("[Free Player] FX levels (fading): " ++ fx.collect { |f| f -> fades[f] }).postln;

			// apply fades (both instruments + FX together)
			~targetsToFades.(fades, fadeTime);

			// update bookkeeping
			~layerOn.keysDo { |k| ~layerOn[k] = active.includes(k) };


			("[Free Player] Active instruments (fading): " ++ active).postln;



			// Wait
			// pick the shorter of instrument cycleWait or scale waitTime
			cycleWait = rrand(4, 12) * ~getMapped.(\dur);
			(cycleWait.min(waitTime)).wait;
		}
	})
});
)

~stopRoutine.(\freePlayer);


// --- Checks ---

// Define key and scale
~setKey.(\C, 4);
~listScales = { allScales.do(_.postln) };
~setScale.(\dorian);
~getParam = { |key| ~parameters[key].value };
~parameters[key].postln;

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
~setParam.(\variability, 0.3);

// Rhythmicity: 0 (smooth/legato) → 1 (tight/rhythmic)
~setParam.(\rhythmicity, 0.7);

// Show parameter settings
~parameters.postln;

// Show mapped values
~showMappedParams.();

// Show server information
s.queryAllNodes;  // shows node tree
s.queryAllBuffers;
SynthDescLib.global.browse; // browse all available defs

// Reset mixer when all buses are used up
~resetMixer.();