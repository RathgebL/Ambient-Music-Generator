// ──────────────────────────────────────────────────────────────────────────
//
//                   A  M  B  I  E  N  T   M  U  S  I  C
//
//                         G  E  N  E  R  A  T  O  R
//
// ──────────────────────────────────────────────────────────────────────────


// ==========================================================================
//                                  SETUP
// ==========================================================================
//
// 1. Run the line below (Cmd + Enter).
//    This will reboot the server, allocate buses, load all
//    engines, helpers, SynthDefs, patterns, and scores.
//
//    This step can take a few seconds.
//
// 2. Once setup is complete, you can choose a player to start
//    generating ambient music.
//
//
// For more information, open the README with:

Document.open(thisProcess.nowExecutingPath.dirname +/+ "README.md");

// ==========================================================================

"Setup.scd".loadRelative;


// ==========================================================================
//                                 PLAYERS
// ==========================================================================
//
// Choose one of the following players.
// Run with Cmd + Enter, stop with Cmd + .
//
// - Conductor:
//   Plays ambient music structured according to a score with
//   six movements:
//       1. Intro
//       2. Inhale
//       3. Shimmer
//       4. Ground
//       5. Punctuate
//       6. Exhale
//
// - FreePlayer:
//   Improvises ambient music and randomly changes instruments,
//   scales, and effects over time.
//
// ==========================================================================

"Player/Conductor.scd".loadRelative;

"Player/FreePlayer.scd".loadRelative;


// ==========================================================================
//                              MANUAL CHECKS
// ==========================================================================
//
// For debugging or manual changes, open the checks file:

Document.open(thisProcess.nowExecutingPath.dirname +/+ "Checks/Checks.scd");

// ==========================================================================