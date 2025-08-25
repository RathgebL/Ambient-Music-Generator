// ─────────────────────────────────────────────────────────── //
//                                                             //
//          A  M  B  I  E  N  T         M  U  S  I  C          //
//     ~                                                 ~     //
//          G    E    N    E    R    A    T    O    R          //
//                                                             //
// ─────────────────────────────────────────────────────────── //


// ====== Server Utilities (with auto-reboot) ======

"Server-Setup.scd".loadRelative;


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

"FreePlayer.scd".loadRelative