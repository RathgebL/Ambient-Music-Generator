(
// ====== Server Utilities (with auto-reboot) ======
"Server/Server-Setup.scd".loadRelative;

s.waitForBoot({

    // ====== Buses ======
    ~resetBuses.();
    ~busesAllocated = false;
    "Buses/Buses.scd".loadRelative;
    ~allocBuses.();

    // ====== Engines ======
    "Engines/Mixing/Mixing-Console.scd".loadRelative;
    "Engines/Mixing/Mixing-Console-GUI.scd".loadRelative;
    "Engines/Parameter/Parameter.scd".loadRelative;
    "Engines/Harmony/Harmony.scd".loadRelative;
    "Engines/Control/Control.scd".loadRelative;

    // ====== Helpers ======
    "Helper/Helpers.scd".loadRelative;

    // ====== SynthDefs ======
    "Synths/SynthDefs.scd".loadRelative;
    s.sync;

    // ====== Pdefs ======
    "Patterns/Pdefs.scd".loadRelative;
    ~makeTextures.();

    // ====== Scores ======
    "Scores/Scores.scd".loadRelative;

    ">>> Full system initialized after server boot.".postln;
});
)