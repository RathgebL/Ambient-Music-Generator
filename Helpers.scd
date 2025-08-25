(
// --- Load Score Helpers ---

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


// --- Routine Helpers ---

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