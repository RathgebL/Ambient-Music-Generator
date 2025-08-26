(
// --- Control Engine ---

~genDurations = { |totalDur=8|
	var choices, weights, remaining, result;
	var rhythmicity = ~parameters[\rhythmicity];
	var variability = ~parameters[\variability];
	("Parameters: " ++ rhythmicity ++ ", " ++ variability).postln;

	// --- Choices depend on rhythmicity ---
	choices = [
		[500000, 250000, 125000] * totalDur,
		[250000, 125000, 62500] * totalDur,
		[125000, 62500, 31250] * totalDur,
		[62500, 31250, 15625] * totalDur
	].at((rhythmicity * 3).round.clip(0, 3));

	// --- Weights depend on variability ---
	weights = [
		[10,26,10],
		[10,18,10],
		[10,14,10],
		[10,12,10]
	].at((variability * 3).round.clip(0, 3));

	// ---Generate sequence fitting exactly into totalDur ---

	remaining = totalDur * 1000000; // re-adjustment factor
	result = List[];

	while { remaining > 0 } {
		var possibleIdx = choices.selectIndices { |c| c <= remaining };
		var choice = choices[possibleIdx].wchoose(weights[possibleIdx].normalizeSum);

		result.add(choice);
		remaining = remaining - choice;
	};

	result = result.collect { |x| x * 0.000001 };

	// Debug print the full result
	("[Arp] Array size: " ++ result.size ++ " | Array: " ++ result).postln;

	result
};

// Toggle intruments
~layerOn = IdentityDictionary[
	\Pad -> false,
	\DarkPad -> true,
	\Bass -> false,
	\Drone ->true,
	\HarpArp -> true,
	\GlassArp -> false,
	\Bell -> false,
	\SeaTex -> true,
	\RainTex -> false,
	\VinylTex -> false
];


// Map your channel names → control buses
~channelBus = IdentityDictionary[
	\Pad        -> ~padCtrl,
	\DarkPad    -> ~darkPadCtrl,
	\Bass       -> ~bassCtrl,
	\Drone      -> ~droneCtrl,
	\Bell       -> ~bellCtrl,
	\HarpArp    -> ~harpCtrl,
	\GlassArp   -> ~glassCtrl,
	\SeaTex     -> ~seaCtrl,
	\RainTex    -> ~rainCtrl,
	\VinylTex   -> ~vinylCtrl,

	// FX + group/master
	\FXMaster   -> ~fxGroupCtrl,
	\ReverbFX   -> ~revCtrl,
	\DelayFX    -> ~delCtrl,
	\CompFX     -> ~compCtrl,
	\SaturatorFX-> ~satCtrl,
	\Master     -> ~masterCtrl
];


// --- Fade Helpers ---

~busLevels = IdentityDictionary.new;

~fadeSmart = { |bus, target=0.0, time=8.0|
	var current = (~busLevels[bus] ? 0.0).max(0.0001);
	var start, curve;

	if(current <= 0.001 and: { target > 0 }) {
		// case 1: new instrument (fade in from silence)
		start = 0.0001;
		curve = -0.5;   // gentle exponential rise
	} {
		if(target <= 0.001) {
			// case 2: fade out
			start = current;
			curve = 0.5; // convex (smooth decay)
		} {
			// case 3: adjustment (between two non-zero values)
			start = current;
			curve = 0;   // linear
		}
	};

	Synth(\fade, [
		\bus, bus,
		\start, start,
		\end, target,
		\dur, time,
		\curve, curve
	], target: ~controlGroup);

	~busLevels[bus] = target;  // update mirror

	("[Fade] bus % (idx %) from % to % in %s (curve %)"
		.format(bus, bus.index, start, target, time, curve)).postln;
};


~targetsToFades = { |targets, time=8|
	if(targets.isNil) { ^nil };

	targets.keysValuesDo { |k, v|
		var bus = ~channelBus[k];
		if(bus.notNil) {
			~fadeSmart.(bus, v, time);
		} {
			("[Target] WARNING: No bus for " ++ k).postln;
		};
	};
};

//  Set instrument faders
~setInstFaders = {|setValue|
    [
        ~padCtrl, ~darkPadCtrl, ~bassCtrl, ~droneCtrl, ~bellCtrl,
		~harpCtrl, ~glassCtrl, ~seaCtrl, ~rainCtrl, ~vinylCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
	("[Faders] Instrument set to " ++ setValue).postln;
};

//  Set group faders
~setGroupFaders = {|setValue|
    [
        ~padGroupCtrl, ~bassGroupCtrl, ~droneGroupCtrl,
        ~bellGroupCtrl, ~arpGroupCtrl, ~texGroupCtrl, ~fxGroupCtrl,
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Groups set to " ++ setValue).postln;
};
//  Set FX faders
~setFxFaders = {|setValue|
    [
        ~revCtrl, ~compCtrl, ~delCtrl, ~satCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] FX set to " ++ setValue).postln;
};

//  Set dry sends
~setDrySends = {|setValue|
    [
        ~padDryCtrl, ~bassDryCtrl, ~droneDryCtrl,
        ~bellDryCtrl, ~arpDryCtrl, ~texDryCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Dry sends set to " ++ setValue).postln;
};

//  Set master faders
~setMasterFaders = {|setValue|
    [
		~fxGroupCtrl, ~masterCtrl
    ].do { |bus| if(bus.notNil) { bus.set(setValue) } };
    ("[Faders] Master set to " ++ setValue).postln;
};

// Gradually change high level parameters
~rampParam = { |key, to, dur=60, curve=\lin|
	var start = ~getParam.(key) ?? 0.5;
	var env   = Env([start, to], [dur], curve);
	var mult = 10;
	var steps = dur * mult;

	("[Ramp] Starting ramp for %: start=%, target=%, steps=%, curve=%"
		.format(key, start, to, steps, curve)).postln;

	Task({
		env.asSignal(dur * 10).do { |val, i|
			~setParam.(key, val);  // safe bus update
			/*("    step %/% → % = %, mapped → %"
			.format(i, steps, key, val.round(0.001), ~getMapped.(key) ?? "nil")).postln;*/
			(1/mult).wait;
		};

		// final target
		~setParam.(key, to);
		("[Ramp] Finished ramp for % at final value % (mapped → %)"
			.format(key, to, ~getMapped.(key))).postln;
	}).start;
};
)