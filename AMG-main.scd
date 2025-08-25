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


// --- Load Parameter Mappings ---

"Parameter.scd".loadRelative;


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


// --- Load Scores ---
"Scores.scd".loadRelative;
)


// ====== SynthDefs ======

"SynthDefs.scd".loadRelative;


// ====== Pdefs ======

"Pdefs.scd".loadRelative;


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