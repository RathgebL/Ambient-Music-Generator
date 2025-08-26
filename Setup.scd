(
// ====== Server Utilities (with auto-reboot) ======

"Server-Setup.scd".loadRelative;

// ====== Everything else waits until boot is complete ======
s.waitForBoot({

    // ====== Buses ======
    ~resetBuses.();           // Run Helpers first
    ~busesAllocated = false;  // Run before allocBuses
    "Buses.scd".loadRelative; // Define allocBuses first
    ~allocBuses.();           // Call the function

    // ====== Engines ======
    "Mixing-Console.scd".loadRelative;
    "Mixing-Console-GUI.scd".loadRelative;
    "Parameter.scd".loadRelative;
    "Harmony.scd".loadRelative;
    "Control.scd".loadRelative;

    // ====== Helpers ======
    "Helpers.scd".loadRelative;

    // ====== SynthDefs ======
    "SynthDefs.scd".loadRelative;
    s.sync;

    // ====== Pdefs ======
    "Pdefs.scd".loadRelative;

    // Call and run texture patterns
    ~makeTextures.();

    // ====== Scores ======
    "Scores.scd".loadRelative;

    ">>> Full system initialized after server boot.".postln;
});
)