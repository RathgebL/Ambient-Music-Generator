(
// --- Pdefs ---

~makePatterns = {
	// Sea
	Pdef(\sea,
		Pbind(
			\instrument, \seaSynth,
			\legato,      Pwhite(0.95, 1.05),

			// time between waves, in beats
			\dur,         Pfunc { ~getMapped.(\dur) },

			// envelope shaping (fractions of dur)
			\atkFrac,     Pwhite(0.1, 0.4),
			\susFrac,     Pwhite(0.05, 0.2),

			// convert fractions to actual seconds
			\atk, Pfunc { |ev|
				ev[\atkFrac] * ev[\dur] * thisThread.clock.beatDur
			},
			\sus, Pfunc { |ev|
				ev[\susFrac] * ev[\dur] * thisThread.clock.beatDur
			},
			\rel, Pfunc { |ev|
				var beatDur   = thisThread.clock.beatDur;
				var totalBeats = ev[\dur];
				var atkBeats   = ev[\atkFrac] * totalBeats;
				var susBeats   = ev[\susFrac] * totalBeats;
				var relBeats   = (totalBeats - atkBeats - susBeats).max(0.1);
				relBeats * beatDur
			},

			// synthesis params
			\waveDepth,   Pfunc({ ~mapLin.(~parameters[\density], 0, 1, 0.1, 0.6) }),
			\pan,         Pwhite(-1.0, 1.0),
			\amp,         Pfunc({ ~getMapped.(\seaAmp) }),
			\out,         ~seaBus
		)
	);

	// Vinyl
	Pdef(\vinyl,
		Pbind(
			\instrument,   \vinylCrackle,
			\dur,          Pfunc({ (~getMapped.(\dur) ? 1).max(0.01) }), // safe fallback, never 0/nil
			\dustDensity,  Pfunc({
				var lo = 10 - rrand(0, 3);
				var hi = 20 - rrand(0, 5);
				~mapExp.(~parameters[\density], 0, 1, lo, hi)
			}),
			\lpFreq,       Pwhite(2000, 5000),
			\hpFreq,       Pwhite(500, 1500),
			\amp,          Pfunc({ ~getMapped.(\vinylAmp) }),
			\out,          ~vinylBus
		)
	);

	// Rain
	Pdef(\rain,
		Pbind(
			\instrument, \rainTexture,
			\dur,        Pfunc({ ~getMapped.(\dur) }),
			\densFactor, Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 1, 2) }),
			\hp,         Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 200, 2000) }),
			\lp,         Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 3000, 8000) }),
			\amp,        Pfunc({ ~getMapped.(\rainAmp) }),
			\out,        ~rainBus
		)
	);

	"[Patterns] Rebuilt and registered into Pdefs".postln;
};


// Generator
Pdef(\ambgen,
	Pspawner { |sp|
		var padSynths = List[];
		var darkPadSynths = List[];
		var bassSynths = List[];
		var droneSynths = List[];

		var chord, dur, durations, padFreqs, padPans, bassFreq;

		// Background textures
		sp.par(Pdef(\vinyl));
		sp.par(Pdef(\rain));
		sp.par(Pdef(\sea));

		loop {
			chord = ~nextChord.();
			dur   = ~getMapped.(\dur);
			durations = ~genDurations.(dur);

			// trigger score fade if pending
			if(~nextScore.notNil) {
				~enterScore.(~nextScore);
				~nextScore = nil;
			};

			// stop old synths
			padSynths.do { |s| s.set(\gate, 0) };      padSynths.clear;
			darkPadSynths.do { |s| s.set(\gate, 0) };  darkPadSynths.clear;
			bassSynths.do { |s| s.set(\gate, 0) };     bassSynths.clear;
			droneSynths.do { |s| s.set(\gate, 0) };    droneSynths.clear;

			// precompute pad freqs
			padFreqs = {
				var freqs, detune, n, baseVoices, octaveVoices, octaveAmpFactor, voicePairs;
				freqs  = chord.midicps;
				detune = ~getMapped.(\detune);
				n      = ~getMapped.(\numVoices);

				baseVoices = Array.fill(n, { |i|
					freqs + (detune * (i - (n - 1) / 2))
				}).flat;

				octaveVoices = baseVoices * 2;
				octaveAmpFactor = ~mapExp.(~parameters[\density], 0, 1, 0.1, 0.2);

				voicePairs = baseVoices.collect { |f| [f, 1.0] }
				++ octaveVoices.collect { |f| [f, octaveAmpFactor] };

				voicePairs.collect(_.first)
			}.value;

			padPans = Array.fill(padFreqs.size, { |i|
				(i / (padFreqs.size.max(1) - 1)).linlin(0, 1, -1, 1)
			});

			// bass register
			bassFreq = ~clampBassRange.(chord[0] - 24).midicps;

			// PAD
			if(~layerOn[\Pad]) {
				padFreqs.do { |f, i|
					padSynths.add(Synth(\padSynth, [
						\dur,    ~getMapped.(\dur),
						\freq,   f,
						\pan,    padPans[i],
						\legato, ~getMapped.(\legato),
						\amp,    ~getAmpForVoices.(chord.size),
						\out,    ~padBus
					]));
				};
			};

			// DARK PAD
			if(~layerOn[\DarkPad]) {
				padFreqs.do { |f, i|
					darkPadSynths.add(Synth(\darkPad, [
						\dur,    ~getMapped.(\dur),
						\freq,   f * 0.5,
						\legato, ~getMapped.(\legato),
						\pan,    padPans[i],
						\amp,    ~getAmpForVoices.(chord.size),
						\out,    ~darkPadBus
					]));
				};
			};

			// BASS
			if(~layerOn[\Bass]) {
				bassSynths.add(Synth(\bassSynth, [
					\dur,    ~getMapped.(\dur),
					\freq,   bassFreq,
					\legato, ~getMapped.(\legato) * 0.97,
					\amp,    ~getMapped.(\bassAmp),
					\out,    ~bassBus
				]));
			};

			// DRONE
			if(~layerOn[\Drone]) {
				droneSynths.add(Synth(\droneSynth, [
					\dur,    ~getMapped.(\dur),
					\legato, ~getMapped.(\legato) * 0.97,
					\freq,   ~getDroneNote.(~droneDegrees.choose, 2).midicps,
					\pan,    rrand(-0.5, 0.5),
					\amp,    ~getMapped.(\droneAmp),
					\out,    ~droneBus
				]));
			};

			// HARP ARP
			if(~layerOn[\HarpArp]) {
				sp.par(
					Pbind(
						\instrument, \harpPluck,
						\dur,   ~getMapped.(\dur),
						\dur,   Pseq(durations, 1),
						\freq,  Pxrand(chord.midicps, inf),
						\decay, Pwhite(2, 5, inf),
						\pan,   Pwhite(-0.6, 0.6, inf),
						\amp,   ~getMapped.(\harpAmp),
						\out,   ~harpBus
					)
				);
			};

			// GLASS ARP
			if(~layerOn[\GlassArp]) {
				sp.par(
					Pbind(
						\instrument, \glassArp,
						\dur,   Pseq(durations, 1),
						\freq, Pxrand(chord.midicps * 2, inf),
						\pan,   Pwhite(-0.6, 0.6, inf),
						\amp,   ~getMapped.(\glassAmp),
						\out,   ~glassBus
					)
				);
			};

			// BELL
			if(~layerOn[\Bell]) {
				sp.par(
					Pbind(
						\instrument, \bell,
						\dur,    Pseq(Array.fill(4, { dur/4 }), 1),
						\legato, ~getMapped.(\legato) * 0.97,
						\freq,   bassFreq * 2,
						\amp,    ~getMapped.(\bellAmp),
						\out,    ~bellBus,
						\type,   Pseq({
							var decisions = Array.fill(4, { \rest });
							var step = (0..3);
							var bellPlayed = false;
							step.do { |i|
								if (bellPlayed.not) {
									var options, weights, chosen;
									switch(i,
										0, { options = [\note, \rest]; weights = [0.3, 0.7]; },
										2, { options = [\note, \rest]; weights = [0.1, 0.9]; },
										1, { options = [\note, \rest]; weights = [0.05, 0.95]; },
										3, { options = [\note, \rest]; weights = [0.05, 0.95]; },
										{ options = [\rest]; weights = [1.0]; }
									);
									chosen = options.wchoose(weights);
									decisions[i] = chosen;
									if (chosen == \note) { bellPlayed = true };
								};
							};
							decisions
						}.(), 1),
					)
				);
			};

			sp.wait(dur);
		}
	}
);
)