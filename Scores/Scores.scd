(
// --- Scores (Presets) ---

~scores = [
	(
		name: \intro, fadeTime: 10, paramTime: 40, dur: 4,
		key: [\D, 3], scale: \yo,
		layersOn: (SeaTex:true, Drone:true, Pad:false, DarkPad:false, Bass:false, HarpArp:false, GlassArp:false, Bell:false, RainTex:true, VinylTex:true),
		targets:  (SeaTex:1.0, Drone:1.0, DarkPad:0, Pad:0, Bass:0, Bell:0, HarpArp:0, GlassArp:0, Bell:0, RainTex:0.01, VinylTex:0.01, Master:1.0, FXMaster:0.85, ReverbFX:0.6, DelayFX:0.2),
		params:   (warmth:0.4, brightness:0.35, density:0.2, variability:0.2, rhythmicity:0.3)
	),

	(
		name: \inhale, fadeTime: 12, paramTime: 60, dur: 8,
		layersOn: (DarkPad:true, Drone:true, SeaTex:true),
		targets:  (DarkPad:1.0, Drone:0.7, SeaTex:0.8, Master:1.0, ReverbFX:0.50, DelayFX:0.30),
		params:   (warmth:0.3, brightness:0.45, density:0.3, variability:0.3, rhythmicity:0.5)
	),

	(
		name: \shimmer, fadeTime: 10, paramTime: 60, dur: 6,
		scale: \lydianDominant,
		layersOn: (GlassArp:true, Pad:true, RainTex:true, DarkPad:true, Drone:true, SeaTex:true),
		targets:  (GlassArp:1.0, Pad:0.7, RainTex:0.8, DarkPad:0, Drone:0, SeaTex:0, DelayFX:0.4, ReverbFX:0.7),
		params:   (brightness:0.6, density:0.3, variability:0.35, warmth:0.8, rhythmicity:0.3)
	),

	(
		name: \ground, fadeTime: 16, paramTime: 70, dur: 12,
		layersOn: (Bass:true, DarkPad:true, RainTex:true, GlassArp:true, Pad:true, Drone:false, SeaTex:false),
		targets:  (Bass:0.5, DarkPad:1.0, RainTex:0.6, GlassArp:0, Pad:0, Master:1.0, DelayFX:0.1, SaturatorFX:0.5),
		params:   (warmth:0.5, brightness:0.5, density:0.38, rhythmicity:0.7)
	),

	(
		name: \punctuate, fadeTime: 6, paramTime: 30, dur: 6,
		layersOn: (Bell:true, HarpArp:true, VinylTex:true, RainTex:true, Bass:true, DarkPad:true, GlassArp:false, Pad:false),
		targets:  (Bell:0.7, HarpArp:1.0, VinylTex:0.8, RainTex:0, Bass:0, DarkPad:0, Master:1.0, ReverbFX:0.3),
		params:   (variability:0.3, density:0.3, rhythmicity:0.2, warmth:0.7)
	),

	(
		name: \exhale, fadeTime: 12, paramTime: 60, dur: 8,
		scale: \inSen,
		layersOn: (Pad:true, DarkPad:true, Drone:true, Bass:true, HarpArp:true, Bell:true, VinylTex:true, RainTex:false),
		targets:  (Pad:0.5, DarkPad:0.4, Drone:0.6, Bass:0.3, HarpArp:0, Bell:0.4, Master:1.0, DelayFX:0.2, ReverbFX:0.8),
		params:   (warmth:0.4, brightness:0.35, density:0.2, variability:0.15)
	)
];
)