(
// --- Parameter Engine ---

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
"git mv ParameMappings.scd".loadRelative;

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
)