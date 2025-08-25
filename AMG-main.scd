// ====== Server Utilities (with auto-reboot) ======

(
s.options.numAudioBusChannels = 512;

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

~resetBuses.();           // Run Helpers first
~busesAllocated = false;  // Run before allocBuses
"Buses.scd".loadRelative; // Define allocBuses first
~allocBuses.();           // Call the function


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


// --- Load Control Engine ---

"Control.scd".loadRelative;
)


// ====== Helpers ======

"Helpers.scd".loadRelative;


// ====== SynthDefs ======

"SynthDefs.scd".loadRelative;


// ====== Pdefs ======

"Pdefs.scd".loadRelative;


// ====== Scores ======

"Scores.scd".loadRelative;


// ====== Players ======

"Conductor.scd".loadRelative;

~stopRoutine.(\conductor);

"FreePlayer.scd".loadRelative

~stopRoutine.(\freePlayer);