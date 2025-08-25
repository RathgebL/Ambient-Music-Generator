(
// --- Conductor to play a piece of ambient music (with Scores) ---

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