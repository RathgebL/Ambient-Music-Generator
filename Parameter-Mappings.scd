(
// --- Parameter Mappings ---

~parameterMappings = (

	// raw parameters (for direct access or GUI control)
	warmth:      { ~parameters[\warmth] },
	brightness:  { ~parameters[\brightness] },
	density:     { ~parameters[\density] },
	variability: { ~parameters[\variability] },
	rhythmicity: { ~parameters[\rhythmicity] },

	// mapped parameters
	crushMix:     { ~mapLin.(~parameters[\warmth],      0, 1, 0.25, 0.05) },
	darkPadSub:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	distAmt:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.25, 0.05) },
	droneDetune:  { ~mapExp.(~parameters[\warmth],      0, 1, 0.01, 0.05) },
	detune:       { ~mapExp.(~parameters[\warmth],      0, 1, 0.01, 0.05) },
	drive:        { ~mapLin.(~parameters[\warmth],      0, 1, 0.05, 0.5) },
	humLevel:     { ~mapExp.(~parameters[\warmth],      0, 1, 0.01, 0.03) },
	lpfFactor:    { ~mapLin.(~parameters[\warmth],      0, 1, 3, 12) },
	modDepth:     { ~mapLin.(~parameters[\warmth],      0, 1, 1, 500)},
	noisePink:    { ~mapLin.(~parameters[\warmth],      1, 0, 0.8, 0.2) },
	noiseWhite:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	revDamp:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	rumbleLevel:  { ~mapLin.(~parameters[\warmth],      0, 1, 0.001, 0.01) },
	sub:          { ~mapLin.(~parameters[\warmth],      0, 1, 0.5, 1.0) },

	darkPadCutoff:{ ~mapExp.(~parameters[\brightness],  0, 1, 200, 2000) },
	filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 2000, 8000) },
	rq:           { ~mapLin.(~parameters[\brightness],  0, 1, 1.5, 0.5)},
	bright:       { ~mapLin.(~parameters[\brightness],  0, 1, 0.7, 0.2)},

	darkPadBits:  { ~mapLin.(~parameters[\variability], 0, 1, 4, 6).round.asInteger },
	droneLfoRate: { ~mapLin.(~parameters[\variability], 0, 1, 0.01, 0.2) },
	dur:          { ~mapLin.(~parameters[\variability], 0, 1, 16, 8).round.asInteger },
	revMix:       { ~mapLin.(~parameters[\variability], 0, 1, 0.3, 0.5) },

	atk:          { ~mapExp.(1 - ~parameters[\rhythmicity], 0, 1, 0.2, 2) },
	legato:       { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 0.95) },
	pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger },
	rel:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 1.0) },

	bassAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.05, 0.15) },
	bellAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.3) },
	droneAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.05, 0.15) },
	harpAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.3, 0.6) },
	glassAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.01, 0.1) },
	noiseAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.5, 1) },
	seaAmp:       { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.3) },
	rainAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.3, 0.5) },
	vinylAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.05, 0.1) },

	numVoices: {
		var raw = ~mapLin.(~parameters[\density], 0, 1, 1, 9).round.asInteger;
		if(raw.even) { raw = raw + 1 }; // ensure odd
		raw
	},

	modRate: {
		var r = ~parameters[\rhythmicity];
		var tempo = TempoClock.default.tempo; // beats per second
		var divisions = [4, 2, 1.5, 1, 0.75, 0.5, 0.25]; // whole, half, dotted quarter, etc.
		var idx = (r * (divisions.size - 1)).round.clip(0, divisions.size - 1);
		var chosenDivision = divisions[idx];
		1 / chosenDivision * tempo // Convert beats to Hz (tempo-synced)
	}
);
)