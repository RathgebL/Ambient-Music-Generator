(
~scales = (
	// existing diatonic
	ionian:     [0,2,4,5,7,9,11],   // major
	dorian:     [0,2,3,5,7,9,10],
	phrygian:   [0,1,3,5,7,8,10],
	lydian:     [0,2,4,6,7,9,11],
	mixolydian: [0,2,4,5,7,9,10],
	aeolian:    [0,2,3,5,7,8,10],   // natural minor
	locrian:    [0,1,3,5,6,8,10],

	// --- additionals ---

	// Modal flavors
	lydianDominant: [0,2,4,6,7,9,10], // Lydian with b7 (jazzy, floating)
	phrygianDominant: [0,1,4,5,7,8,10], // “Spanish gypsy”

	// Pentatonics (dreamy, open)
	majorPent: [0,2,4,7,9],   // C D E G A
	minorPent: [0,3,5,7,10],  // C Eb F G Bb
	egyptian:  [0,2,5,7,10],  // C D F G Bb (pentatonic but exotic)

	// Hexatonics / symmetrical
	wholeTone: [0,2,4,6,8,10], // dreamy, floating
	augmented: [0,3,4,7,8,11], // augmented scale
	tritone:   [0,1,4,6,7,10], // mysterious

	// Octatonic / diminished
	dimWH: [0,2,3,5,6,8,9,11], // whole-half diminished
	dimHW: [0,1,3,4,6,7,9,10], // half-whole diminished

	// Ethereal / ambient
	hirajoshi:   [0,2,3,7,8],   // Japanese pentatonic
	inSen:       [0,1,5,7,10],  // Japanese, very airy
	yo:          [0,2,5,7,9],   // bright Japanese pentatonic
	iwato:       [0,1,5,6,10],  // haunting, suspended
	persian:     [0,1,4,5,6,8,11], // tense & exotic
	neapolitan:  [0,1,3,5,7,8,11], // Neapolitan minor
	enigmatic:   [0,1,4,6,8,10,11] // mysterious modern scale
);

// note names just for convenience
~noteNames = (C:0, Cis:1, Des:1, D:2, Dis:3, Es:3, E:4, F:5, Fis:6, Ges:6, G:7, Gis:8, As:8, A:9, Ais:10, B:10, H:11);
)