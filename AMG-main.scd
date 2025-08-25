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


// --- Load Harmony Engine ---

"Harmony.scd".loadRelative;


// --- Control Engine ---

"Control.scd".loadRelative;


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