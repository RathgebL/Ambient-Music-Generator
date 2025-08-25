// ─────────────────────────────────────────────────────────── //
//                                                             //
//          A  M  B  I  E  N  T         M  U  S  I  C          //
//                                                             //
//          G    E    N    E    R    A    T    O    R          //
//                                                             //
// ─────────────────────────────────────────────────────────── //


// ====== Setup ======

/*

Run this first (Cmd + Enter on the line).
The setup file contains everything from rebooting to setting up all utilities for the generator.
This step might take a view seconds. Afterwards you can run a player to generate some ambient music.
Have fun!

*/

"Setup.scd".loadRelative;


// ====== Players ======

/*

Run a player by pressing cmd + enter on the line. Stop it with cmd + .

The "Conductor" plays ambient music structured according to a score with the following six movements:

1. Intro
2. First Pads
3. Shimmer
4. Ground
5. Punctuate
6. Exhale

The "FreePlayer", on the other hand, improvises ambient music and randomly changes instruments, scales and effects over time.

*/

"Conductor.scd".loadRelative;

"FreePlayer.scd".loadRelative;