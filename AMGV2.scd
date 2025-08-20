s.options.numAudioBusChannels = 512;
s.reboot;
s.scope;
s.meter;
s.plotTree;


(
// --- Mixing Engine ---

// Top-level groups
~mixerGroup        = Group.head(s);
~sourcesGroup      = Group.head(~mixerGroup);        // instrument synths
~fadersGroup       = Group.after(~sourcesGroup);     // instrument faders
~groupFadersGroup  = Group.after(~fadersGroup);      // group faders
~dryGroup          = Group.after(~groupFadersGroup); // sends to master
~sendsGroup        = Group.after(~dryGroup);         // sends to FX
~fxsGroup          = Group.after(~sendsGroup);       // FX processors
~masterGroup       = Group.after(~fxsGroup);         // final master fader


// Fader with control bus
SynthDef(\fader, { |inBus, outBus, ctrlBus|
    var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

    // print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "fader L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "fader R");

    Out.ar(outBus, sig);
}).add;

// Fader with control bus
SynthDef(\groupFader, { |inBus, outBus, ctrlBus|
    var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

    // print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "group fader L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "group fader R");

    Out.ar(outBus, sig);
}).add;

SynthDef(\drySend, { |inBus, outBus, ctrlBus|
    var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

    // print RMS amplitude of each channel every 0.1 sec
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "dry send L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "dry send R");

    Out.ar(outBus, sig);
}).add;

// Multi-send: tap one input bus, send copies to multiple FX buses
SynthDef(\multiSend, { |inBus, revBus, compBus, delBus, satBus, amp=1|
    var sig = In.ar(inBus, 2) * amp;

	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "send tap L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "send tap R");

    Out.ar(revBus, sig);
    Out.ar(compBus, sig);
    Out.ar(delBus, sig);
    Out.ar(satBus, sig);
}).add;

// FX reverb
SynthDef(\fxReverb, { |inBus=0, outBus=0, ctrlBus, room=0.9, damp=0.5, mix=1.0|
    var in, sig;
	in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
    sig = FreeVerb2.ar(in[0], in[1], mix, room, damp); // always wet

	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "rev tap L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "rev tap R");

	Out.ar(outBus, sig);
}).add;

// FX compression
SynthDef(\fxComp, { |inBus=0, outBus=0, ctrlBus, thresh=0.4, slopeAbove=0.3, clamp=0.01, relax=0.3|
    var in, sig;
    in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
    sig = Compander.ar(
        in, in,
        thresh,        // threshold
        1,             // slopeBelow (no expansion)
        slopeAbove,    // slopeAbove (compression)
        clamp, relax
    );
    Out.ar(outBus, sig);
}).add;

// FX delay
SynthDef(\fxDelay, { |inBus=0, outBus=0, ctrlBus, maxDelay=2.0, delayTime=0.5, feedback=0.3|
    var in, sig;
    in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
    sig = CombC.ar(in, maxDelay, delayTime, feedback * maxDelay);
    Out.ar(outBus, sig);
}).add;

// FX saturation
SynthDef(\fxSaturator, { |inBus=0, outBus=0, ctrlBus, drive=1.1|
    var in, sig;
    in = In.ar(inBus, 2) * In.kr(ctrlBus, 1);
    sig = tanh(in * drive);
    Out.ar(outBus, sig);
}).add;


// Master fader (with final FX)
SynthDef(\masterFader, { |inBus=0, outBus=0, ctrlBus|
    var sig = In.ar(inBus, 2) * In.kr(ctrlBus, 1);

    // Global processing
    sig = Compander.ar(sig, sig, thresh: 0.4, slopeBelow: 1, slopeAbove: 0.3, clampTime: 0.01, relaxTime: 0.3);
    sig = FreeVerb2.ar(sig[0], sig[1], mix: 0.1, room: 0.7, damp: 0.5);
	sig = Limiter.ar(sig, 0.9);

	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[0]), label: "Master tap L");
	// Poll.kr(Impulse.kr(10), Amplitude.kr(sig[1]), label: "Master tap R");

	Out.ar(outBus, sig);
}).add;

// Audio Buses
// Master bus
~masterBus       = Bus.audio(s, 2);

// Instrument buses
~padBus          = Bus.audio(s, 2);
~darkPadBus      = Bus.audio(s, 2);
~bassBus         = Bus.audio(s, 2);
~droneBus        = Bus.audio(s, 2);
~harpBus         = Bus.audio(s, 2);
~glassBus        = Bus.audio(s, 2);
~bellBus         = Bus.audio(s, 2);
~seaBus          = Bus.audio(s, 2);
~rainBus         = Bus.audio(s, 2);
~vinylBus        = Bus.audio(s, 2);

// FX buses
~revBus          = Bus.audio(s, 2);
~compBus         = Bus.audio(s, 2);
~delBus          = Bus.audio(s, 2);
~satBus          = Bus.audio(s, 2);

// Group buses
~padGroupBus     = Bus.audio(s, 2);
~bassGroupBus    = Bus.audio(s, 2);
~droneGroupBus   = Bus.audio(s, 2);
~bellGroupBus    = Bus.audio(s, 2);
~arpGroupBus     = Bus.audio(s, 2);
~texGroupBus     = Bus.audio(s, 2);
~fxGroup         = Bus.audio(s, 2);

// Dry sends
~padDryBus     = Bus.audio(s, 2);
~bassDryBus    = Bus.audio(s, 2);
~droneDryBus   = Bus.audio(s, 2);
~bellDryBus    = Bus.audio(s, 2);
~arpDryBus     = Bus.audio(s, 2);
~texDryBus     = Bus.audio(s, 2);

// Control buses
// Master control
~masterCtrl      = Bus.control(s, 1).set(1);

// Instrument control
~padCtrl         = Bus.control(s, 1).set(1);
~darkPadCtrl     = Bus.control(s, 1).set(1);
~bassCtrl        = Bus.control(s, 1).set(1);
~droneCtrl       = Bus.control(s, 1).set(1);
~bellCtrl        = Bus.control(s, 1).set(1);
~harpCtrl        = Bus.control(s, 1).set(1);
~glassCtrl       = Bus.control(s, 1).set(1);
~seaCtrl         = Bus.control(s, 1).set(1);
~rainCtrl        = Bus.control(s, 1).set(1);
~vinylCtrl       = Bus.control(s, 1).set(1);

// FX control
~revCtrl         = Bus.control(s, 1).set(1);
~compCtrl        = Bus.control(s, 1).set(1);
~delCtrl         = Bus.control(s, 1).set(1);
~satCtrl         = Bus.control(s, 1).set(1);

// Groups control
~padGroupCtrl    = Bus.control(s, 1).set(1);
~bassGroupCtrl   = Bus.control(s, 1).set(1);
~droneGroupCtrl  = Bus.control(s, 1).set(1);
~bellGroupCtrl   = Bus.control(s, 1).set(1);
~arpGroupCtrl    = Bus.control(s, 1).set(1);
~texGroupCtrl    = Bus.control(s, 1).set(1);
~fxGroupCtrl     = Bus.control(s, 1).set(1);
~padDryCtrl      = Bus.control(s, 1).set(1);

// Instrument faders
~padFader        = Synth(\fader,       [\inBus, ~padBus,        \outBus, ~padGroupBus,   \ctrlBus, ~padCtrl],        target: ~fadersGroup);
~darkPadFader    = Synth(\fader,       [\inBus, ~darkPadBus,    \outBus, ~padGroupBus,   \ctrlBus, ~darkPadCtrl],    target: ~fadersGroup);
~bassFader       = Synth(\fader,       [\inBus, ~bassBus,       \outBus, ~bassGroupBus,  \ctrlBus, ~bassCtrl],       target: ~fadersGroup);
~droneFader      = Synth(\fader,       [\inBus, ~droneBus,      \outBus, ~droneGroupBus, \ctrlBus, ~droneCtrl],      target: ~fadersGroup);
~bellFader       = Synth(\fader,       [\inBus, ~bellBus,       \outBus, ~bellGroupBus,  \ctrlBus, ~bellCtrl],       target: ~fadersGroup);
~harpFader       = Synth(\fader,       [\inBus, ~harpBus,       \outBus, ~arpGroupBus,   \ctrlBus, ~harpCtrl],       target: ~fadersGroup);
~glassFader      = Synth(\fader,       [\inBus, ~glassBus,      \outBus, ~arpGroupBus,   \ctrlBus, ~glassCtrl],      target: ~fadersGroup);
~seaFader        = Synth(\fader,       [\inBus, ~seaBus,        \outBus, ~texGroupBus,   \ctrlBus, ~seaCtrl],        target: ~fadersGroup);
~rainFader       = Synth(\fader,       [\inBus, ~rainBus,       \outBus, ~texGroupBus,   \ctrlBus, ~rainCtrl],       target: ~fadersGroup);
~vinylFader      = Synth(\fader,       [\inBus, ~vinylBus,      \outBus, ~texGroupBus,   \ctrlBus, ~vinylCtrl],      target: ~fadersGroup);

// Group faders
~padGroupFader   = Synth(\groupFader,  [\inBus, ~padGroupBus,   \outBus, ~padDryBus,     \ctrlBus, ~padGroupCtrl],   target: ~groupFadersGroup);
~bassGroupFader  = Synth(\groupFader,  [\inBus, ~bassGroupBus,  \outBus, ~bassDryBus,    \ctrlBus, ~bassGroupCtrl],  target: ~groupFadersGroup);
~droneGroupFader = Synth(\groupFader,  [\inBus, ~droneGroupBus, \outBus, ~droneDryBus,   \ctrlBus, ~droneGroupCtrl], target: ~groupFadersGroup);
~bellGroupFader  = Synth(\groupFader,  [\inBus, ~bellGroupBus,  \outBus, ~bellDryBus,    \ctrlBus, ~bellGroupCtrl],  target: ~groupFadersGroup);
~arpGroupFader   = Synth(\groupFader,  [\inBus, ~arpGroupBus,   \outBus, ~arpDryBus,     \ctrlBus, ~arpGroupCtrl],   target: ~groupFadersGroup);
~texGroupFader   = Synth(\groupFader,  [\inBus, ~texGroupBus,   \outBus, ~texDryBus,     \ctrlBus, ~texGroupCtrl],   target: ~groupFadersGroup);

// FX group fader
~fxGroupFader    = Synth(\groupFader,  [\inBus, ~fxGroup,       \outBus, ~masterBus,     \ctrlBus, ~fxGroupCtrl],    target: ~groupFadersGroup);

// Dry sends
~padDryFader     = Synth(\drySend,    [\inBus, ~padDryBus,      \outBus, ~masterBus,     \ctrlBus, ~padDryCtrl],     target: ~dryGroup);
~bassDryFader    = Synth(\drySend,    [\inBus, ~bassDryBus,     \outBus, ~masterBus,     \ctrlBus, ~bassDryCtrl],    target: ~dryGroup);
~droneDryFader   = Synth(\drySend,    [\inBus, ~droneDryBus,    \outBus, ~masterBus,     \ctrlBus, ~droneDryCtrl],   target: ~dryGroup);
~bellDryFader    = Synth(\drySend,    [\inBus, ~bellDryBus,     \outBus, ~masterBus,     \ctrlBus, ~bellDryCtrl],    target: ~dryGroup);
~arpDryFader     = Synth(\drySend,    [\inBus, ~arpDryBus,      \outBus, ~masterBus,     \ctrlBus, ~arpDryCtrl],     target: ~dryGroup);
~texDryFader     = Synth(\drySend,    [\inBus, ~texDryBus,      \outBus, ~masterBus,     \ctrlBus, ~texDryCtrl],     target: ~dryGroup);

// FX sends
~padGroupSend    = Synth(\multiSend,   [\inBus, ~padGroupBus,   \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~padGroupCtrl],   target: ~sendsGroup);
~bassGroupSend   = Synth(\multiSend,   [\inBus, ~bassGroupBus,  \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~bassGroupCtrl],  target: ~sendsGroup);
~droneGroupSend  = Synth(\multiSend,   [\inBus, ~droneGroupBus, \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~droneGroupCtrl], target: ~sendsGroup);
~bellGroupSend   = Synth(\multiSend,   [\inBus, ~bellGroupBus,  \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~bellGroupCtrl],  target: ~sendsGroup);
~arpGroupSend    = Synth(\multiSend,   [\inBus, ~arpGroupBus,   \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~arpGroupCtrl],   target: ~sendsGroup);
~texGroupSend    = Synth(\multiSend,   [\inBus, ~texGroupBus,   \revBus, ~revBus, \compBus, ~compBus, \delBus, ~delBus, \satBus, ~satBus, \ctrlBus, ~texGroupCtrl],   target: ~sendsGroup);


// FX processors
~reverbFX        = Synth(\fxReverb,    [\inBus, ~revBus,        \outBus, ~fxGroup,       \ctrlBus, ~revCtrl],        target: ~fxsGroup);
~compFX          = Synth(\fxComp,      [\inBus, ~compBus,       \outBus, ~fxGroup,       \ctrlBus, ~compCtrl],       target: ~fxsGroup);
~delayFX         = Synth(\fxDelay,     [\inBus, ~delBus,        \outBus, ~fxGroup,       \ctrlBus, ~delCtrl],        target: ~fxsGroup);
~saturatorFX     = Synth(\fxSaturator, [\inBus, ~satBus,        \outBus, ~fxGroup,       \ctrlBus, ~satCtrl],        target: ~fxsGroup);


// Master fader
~masterFader     = Synth(\masterFader, [\inBus, ~masterBus,     \outBus, 0,              \ctrlBus, ~masterCtrl],     target: ~masterGroup);
)


// --- Full Mixer Console GUI ---

(
var win, rowIndices, channels, soloActive, updateStates, colInstrument, colGroup, colFX, colFxMaster, colMaster;

// Colors
colInstrument = Color(0.9, 0.9, 0.9);  // light grey
colGroup      = Color(0.7, 0.9, 0.7);  // greenish
colFX         = Color(0.7, 0.7, 0.9);  // bluish
colFxMaster   = Color(0.6, 0.8, 0.9);  // light blue
colMaster     = Color(1, 0.6, 0.2);    // orange

// Channel definitions
// Each channel is a dictionary with name, synth, color, type, and ctrlBus
channels = [
    // Instrument level
    (name: \Pad,         color: colInstrument, type: \instrument, ctrlBus: ~padCtrl),
    (name: \DarkPad,     color: colInstrument, type: \instrument, ctrlBus: ~darkPadCtrl),
    (name: \Bass,        color: colInstrument, type: \instrument, ctrlBus: ~bassCtrl),
    (name: \Drone,       color: colInstrument, type: \instrument, ctrlBus: ~droneCtrl),
    (name: \Bell,        color: colInstrument, type: \instrument, ctrlBus: ~bellCtrl),
    (name: \HarpArp,     color: colInstrument, type: \instrument, ctrlBus: ~harpCtrl),
    (name: \GlassArp,    color: colInstrument, type: \instrument, ctrlBus: ~glassCtrl),
    (name: \SeaTex,      color: colInstrument, type: \instrument, ctrlBus: ~seaCtrl),
    (name: \RainTex,     color: colInstrument, type: \instrument, ctrlBus: ~rainCtrl),
    (name: \VinylTex,    color: colInstrument, type: \instrument, ctrlBus: ~vinylCtrl),

    // Group level
    (name: \PadGroup,    color: colGroup,      type: \group,      ctrlBus: ~padGroupCtrl),
    (name: \BassGroup,   color: colGroup,      type: \group,      ctrlBus: ~bassGroupCtrl),
    (name: \DroneGroup,  color: colGroup,      type: \group,      ctrlBus: ~droneGroupCtrl),
    (name: \BellGroup,   color: colGroup,      type: \group,      ctrlBus: ~bellGroupCtrl),
    (name: \ArpGroup,    color: colGroup,      type: \group,      ctrlBus: ~arpGroupCtrl),
    (name: \TexGroup,    color: colGroup,      type: \group,      ctrlBus: ~texGroupCtrl),

    // FX return level
    (name: \ReverbFX,    color: colFX,         type: \fx,         ctrlBus: ~revCtrl),
    (name: \CompFX,      color: colFX,         type: \fx,         ctrlBus: ~compCtrl),
    (name: \DelayFX,     color: colFX,         type: \fx,         ctrlBus: ~delCtrl),
    (name: \SaturatorFX, color: colFX,         type: \fx,         ctrlBus: ~satCtrl),

    // Master
	(name: \FXMaster,    color: colFxMaster,   type: \fx,         ctrlBus: ~fxGroupCtrl),
    (name: \Master,      color: colMaster,     type: \master,     ctrlBus: ~masterCtrl)
];

// Solo handling
soloActive = false;

~drySends = IdentityDictionary[
    \PadGroup   -> ~padDryCtrl,
    \BassGroup  -> ~bassDryCtrl,
    \DroneGroup -> ~droneDryCtrl,
    \BellGroup  -> ~bellDryCtrl,
    \ArpGroup   -> ~arpDryCtrl,
    \TexGroup   -> ~texDryCtrl
];

updateStates = {
    var soloedInstruments, soloedGroups, soloedFX, fxMasterSolo, soloActive, fxSoloActive;

    // detect soloed channels
    soloedInstruments = channels.select { |c| c[\type] == \instrument and: { c[\solo].notNil and: { c[\solo].value == 1 } } };
    soloedGroups      = channels.select { |c| c[\type] == \group      and: { c[\solo].notNil and: { c[\solo].value == 1 } } };
    soloedFX          = channels.select { |c| c[\type] == \fx and: { c[\name] != \FXMaster } and: { c[\solo].notNil and: { c[\solo].value == 1 } } };
    fxMasterSolo      = channels.detect { |c| c[\name] == \FXMaster and: { c[\solo].notNil and: { c[\solo].value == 1 } } };

    soloActive      = soloedInstruments.notEmpty or: { soloedGroups.notEmpty or: { soloedFX.notEmpty or: { fxMasterSolo.notNil } } };
    fxSoloActive    = soloedFX.notEmpty or: { fxMasterSolo.notNil };

    "===== updateStates triggered =====".postln;
    ("soloedInstruments: " ++ soloedInstruments.collect(_.name)).postln;
    ("soloedGroups: " ++ soloedGroups.collect(_.name)).postln;
    ("soloedFX: " ++ soloedFX.collect(_.name)).postln;
    ("fxMasterSolo: " ++ fxMasterSolo.tryPerform(\name)).postln;
    ("soloActive? " ++ soloActive).postln;
    ("fxSoloActive? " ++ fxSoloActive).postln;

    // per-channel handling
    channels.do { |c|
        var mute   = (c[\mute].notNil and: { c[\mute].value == 1 });
        var isSolo = (c[\solo].notNil and: { c[\solo].value == 1 });
        var val    = (c[\slider].notNil).if({ c[\slider].value }, { 0.5 });
        var newVal;

        ("--- Channel: " ++ c[\name]).postln;
        ("mute? " ++ mute ++ " solo? " ++ isSolo ++ " sliderVal: " ++ val).postln;

        if(c[\ctrlBus].notNil) {
            if(c[\type] == \master) {
                newVal = if(mute, 0, val);
                ("[MASTER handling] newVal: " ++ newVal).postln;

            } {
                if(soloActive) {
                    if(soloedInstruments.notEmpty) {
                        ("[Instrument solo active]").postln;
                        if(c[\type] == \instrument) {
                            newVal = if(isSolo and: { mute.not }, val, 0);
                        } {
                            newVal = if(mute, 0, val);
                        };

                    } {
                        if(soloedGroups.notEmpty) {
                            ("[Group solo active]").postln;
                            if(c[\type] == \group) {
                                newVal = if(isSolo and: { mute.not }, val, 0);
                            } {
                                newVal = if(mute, 0, val);
                            };

                        } {
                            if(soloedFX.notEmpty) {
                                ("[FX solo active]").postln;
                                if(c[\type] == \fx and: { c[\name] != \FXMaster }) {
                                    newVal = if(isSolo and: { mute.not }, val, 0);
                                } {
                                    newVal = if(mute, 0, val);
                                };

                            } {
                                if(fxMasterSolo.notNil) {
                                    ("[FX Master solo active]").postln;
                                    if(c[\name] == \FXMaster) {
                                        newVal = if(mute.not, val, 0);
                                    } {
                                        newVal = if(mute, 0, val);
                                    };
                                } {
                                    newVal = if(mute, 0, val);
                                };
                            };
                        };
                    };
                } {
                    newVal = if(mute, 0, val);
                    ("[No solo active]").postln;
                };
            };

            // write to bus
            c[\ctrlBus].set(newVal);

            ("CTRL UPDATE -> " ++ c[\name] ++ " set to " ++ newVal).postln;
        };
    };

    // dry send handling
    if(fxSoloActive) {
        ~drySends.keysValuesDo { |name, bus| bus.set(0) };
        ("Dry Sends muted (FX solo active): " ++ ~drySends.keys).postln;
    } {
        var dryDebug = [];
        ~drySends.keysValuesDo { |name, bus|
            var sliderVal = channels.detect { |ch| ch[\name] == name }[\slider].value;
            bus.set(sliderVal);
            dryDebug = dryDebug.add(name.asString ++ ":" ++ sliderVal);
        };
        ("Dry Sends restored: " ++ dryDebug).postln;
    };

    "===== END updateStates =====".postln;
};

// GUI window
win = Window("AMBIENT MUSIC GENERATOR Mixer", Rect(50, 50, channels.size * 100, 820)).front;

// Counters for xOffset
rowIndices = IdentityDictionary[
    \instrument -> 0,
    \group      -> 0,
    \fx         -> 0
];

channels.do { |c|
    var name = c[\name], color = c[\color], type = c[\type], ctrlBus = c[\ctrlBus];
    var slider, muteBtn, soloBtn, label, yOffset, xOffset;

    // row-specific yOffset
    yOffset = switch(type,
        \instrument, { 50 },
        \group,      { 300 },
        \fx,         { 550 },
        \master,     { 550 },   // Master sits with FX row
        { 50 }
    );

    // row-specific xOffset
    if(type == \master) {
        // Master should be placed after all FX channels
        xOffset = rowIndices[\fx] * 100 + 50;
    } {
        xOffset = rowIndices[type] * 100 + 50;
        rowIndices[type] = rowIndices[type] + 1;  // increment for non-master
    };

    // Slider
    slider = Slider(win, Rect(xOffset, yOffset, 30, 150))
        .background_(color)
        .value_(ctrlBus.getSynchronous)   // start at current bus value
        .action_({ |sl|
            ctrlBus.set(sl.value);        // update the bus
            updateStates.();
        });

	// Mute Button
	if(type == \master) {
		// Center mute under master slider
		muteBtn = Button(win, Rect(xOffset + 2, yOffset + 160, 25, 20))
		.states_([["M", Color.black, Color(1,0.3,0.3)], ["M", Color.white, Color.red]])
		.action_({ updateStates.() });
	} {
		// Default placement (to the left)
		muteBtn = Button(win, Rect(xOffset - 10, yOffset + 160, 25, 20))
		.states_([["M", Color.black, Color(1,0.3,0.3)], ["M", Color.white, Color.red]])
		.action_({ updateStates.() });
	};

    // Solo Button (only for non-master channels)
    if(type != \master) {
        soloBtn = Button(win, Rect(xOffset + 20, yOffset + 160, 25, 20))
            .states_([["S", Color.black, Color(0.7,0.7,1)], ["S", Color.white, Color.blue]])
            .action_({ updateStates.() });
        c[\solo] = soloBtn;
    };

    // Label
    label = StaticText(win, Rect(xOffset - 10, yOffset + 185, 70, 20))
        .align_(\center)
        .string_(name.asString);

    // Store GUI elements back into channel dict
    c[\slider] = slider;
    c[\mute]   = muteBtn;
    if(type != \master) { c[\solo] = soloBtn };
};
)


(
// --- Reset Mixer Utility ---
~resetMixer = {
	s.freeAll;   // frees all synths, groups, and releases buses
	s.newBusAllocators; // reset bus allocators

	"Mixer fully reset.".postln;
};
)


(
// --- Parameter Mapping Engine ---

/*
warmth from cold (digital, thin) to warm (analog, fat) -> detuneAmt
brightness from dark (filtered, muffled) to bright (open) -> filter cutoff
density from sparse (few voices) to dense (many voices) -> number of voices
variability from static to highly changing -> modulation speed
rhythmicity from fluid/free to rhythmic/structured -> pulse emphasis
*/

~ensureParams = {
	if(~parameters.isNil) {
		~parameters = IdentityDictionary[
			\warmth -> 0.5,      // detune
			\brightness -> 0.5,  // filter cutoff
			\density -> 0.5,     // number of voices
			\variability -> 0.5, // modulation speed
			\rhythmicity -> 0.5  // rhythm emphasis
		];
	};
};
~ensureParams.();

~mapLin = { |val, inMin=0, inMax=1, outMin=0, outMax=1|
	((val - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
};

~mapExp = { |val, inMin=0, inMax=1, outMin=100, outMax=8000|
	var t = ((val - inMin) / (inMax - inMin)).clip(0,1);
	outMin * ((outMax/outMin) ** t)
};

~parameterMappings = (
	crushMix:     { ~mapLin.(~parameters[\warmth],      0, 1, 0.25, 0.05) },
	darkPadSub:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	distAmt:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.25, 0.05) },
	droneDetune:  { ~mapLin.(~parameters[\warmth],      0, 1, 0.01, 0.05) },
	detune:       { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.05) },
	drive:        { ~mapLin.(~parameters[\warmth],      0, 1, 0.05, 0.5) },
	humLevel:     { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.05) },
	lpfFactor:    { ~mapLin.(~parameters[\warmth],      0, 1, 3, 12) },
	modDepth:     { ~mapLin.(~parameters[\warmth],      0, 1, 1, 250) },
	noisePink:    { ~mapLin.(~parameters[\warmth],      1, 0, 0.8, 0.2) },
	noiseWhite:   { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	revDamp:      { ~mapLin.(~parameters[\warmth],      0, 1, 0.2, 0.8) },
	rumbleLevel:  { ~mapLin.(~parameters[\warmth],      0, 1, 0.0, 0.2) },
	sub:          { ~mapLin.(~parameters[\warmth],      0, 1, 0.5, 1.0) },
	darkPadCutoff:{ ~mapExp.(~parameters[\brightness],  0, 1, 200, 2000) },
	filterCutoff: { ~mapExp.(~parameters[\brightness],  0, 1, 2000, 8000) },
	rq:           { ~mapLin.(~parameters[\brightness],  0, 1, 2, 0.5)},
	bright:       { ~mapLin.(~parameters[\brightness],  0, 1, 0.7, 0.2)},
	darkPadBits:  { ~mapLin.(~parameters[\variability], 0, 1, 4, 6).round.asInteger },
	droneLfoRate: { ~mapLin.(~parameters[\variability], 0, 1, 0.01, 0.1) },
	dur:          { ~mapLin.(~parameters[\variability], 0, 1, 16, 8).round.asInteger },
	revMix:       { ~mapLin.(~parameters[\variability], 0, 1, 0.3, 0.5) },
	atk:          { ~mapExp.(1 - ~parameters[\rhythmicity], 0, 1, 0.2, 2) },
	legato:       { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 0.95) },
	pulseDiv:     { ~mapLin.(~parameters[\rhythmicity], 0, 1, 1, 4).round.asInteger },
    rel:          { ~mapLin.(~parameters[\rhythmicity], 0, 1, 4, 1.0) },
	bassAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.2) },
	bellAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.1, 0.5) },
	droneAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.05, 0.2) },
	harpAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.5, 1) },
	noiseAmp:     { ~mapExp.(~parameters[\density],     0, 1, 0.5, 1) },
	norm:         { ~mapExp.(~parameters[\density],     0, 1, 0.01, 0.05) },
	seaAmp:       { ~mapExp.(~parameters[\density],     0, 1, 0.2, 0.3) },
	rainAmp:      { ~mapExp.(~parameters[\density],     0, 1, 0.5, 1) },
	numVoices:    {
		var raw =   ~mapLin.(~parameters[\density],         0, 1, 1, 9).round.asInteger;
		if(raw.even) { raw = raw + 1 }; // ensure odd
		raw
	},
	modRate: {
		var r = ~parameters[\rhythmicity];
		var tempo = TempoClock.default.tempo; // beats per second
		var divisions = [4, 2, 1.5, 1, 0.75, 0.5, 0.25]; // whole, half, dotted quarter, etc.
		var idx = (r * (divisions.size - 1)).round.clip(0, divisions.size - 1);
		var chosenDivision = divisions[idx];

		// Convert beats to Hz (tempo-synced)
		1 / chosenDivision * tempo
	},
);

~setParam = { |key, val|
	~ensureParams.();
	~parameters[key] = val.clip(0, 1);
};

~setParams = { |pairs|
	pairs.keysValuesDo { |k, v| ~setParam.(k, v) };
};

~getParam   = { |key| ~parameters[key] };
~getMapped  = { |key| var f = ~parameterMappings[key]; f.notNil.if({ f.() }, { nil }) };

~showParams = {
	"Params:".postln;
	~parameters.keysValuesDo { |k,v| ("%: %".format(k, v)).postln };
};

~showMappedParams = {
	"Mapped Parameter Values:".postln;
	~parameterMappings.keysValuesDo { |key, func|
		("%: %".format(key, func.())).postln;
	};
};
)

// --- Pad Synths ---
(
SynthDef(\padSynth, { |out = 0, freq = 440, amp = 1, gate = 1, pan = 0, atk = 2.0, rel = 4.0, ffreq = 100, rq = 0.2, modRate = 1, modDepth = 100, norm = 0.3, revMix = 0.3|
    var osc, env, filt, mod, rev, snd;

    // Saw per voice
    osc = Saw.ar(freq) * norm;


    // Filter modulation
    mod = SinOsc.kr(modRate, 0, modDepth, ffreq);
	filt = RLPF.ar(osc, mod, rq);
	filt = tanh(filt * 0.8); // gentle analog-style limiting


    // Envelope
    env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

	// Reverb to push into space
    rev = FreeVerb.ar(filt * env, mix: revMix, room: 0.9, damp: 0.7);

	snd = rev * amp;

    Out.ar(out, Pan2.ar(snd, pan));
}).add;
)

(
SynthDef(\darkPad, { |out=0, freq=220, amp=0.1, norm = 0.3, ffreq=1000, darkPadSub=0.5, darkPadBits=8, crushMix=0.3, drive=0.1, distAmt=0.1, gate=1, atk=4, rel=8, rq=0.4, revMix=0.2|
    var osc, sub, mix, lfo, env, filt, dist, crush, chorus, rev;

    // 2 saws slightly detuned (already thick enough)
    osc = Saw.ar(freq) * norm;

    // add a deep sub layer (square or sine one octave down)
    sub = Pulse.ar(freq/2, 0.4) * darkPadSub;

    // mix and balance
    mix = Mix([osc, sub]) * 0.3;

    // slow LFO for cutoff movement
    lfo = SinOsc.kr(0.03).range(0.4, 1.2);

    // dark low-pass filter (base cutoff not tied to pitch)
    filt = RLPF.ar(mix, (ffreq * lfo).clip(100, 2000), rq);

    // distortion: waveshaper for nasty harmonics
    dist = XFade2.ar(tanh(filt * (1 + drive * 10)), filt.clip2, distAmt * 2 - 1);
	dist = HPF.ar(dist, 80); // clean up mud


    // bitcrush for extra electronic grit
    crush = XFade2.ar(dist, Decimator.ar(dist, 44100, darkPadBits), crushMix * 2 - 1); // bit resolution

    // stereo spread / chorus
    chorus = Splay.ar([
        DelayC.ar(crush, 0.03, LFNoise1.kr(0.15).range(0.001, 0.02)),
        DelayC.ar(crush, 0.03, LFNoise1.kr(0.15).range(0.002, 0.025))
    ], spread: 0.8);

    // envelope
    env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

    // optional dark reverb tail
    rev = FreeVerb.ar(chorus * env, mix: revMix, room: 0.7, damp: 0.3);
	rev = HPF.ar(rev, 80);


    Out.ar(out, rev * amp);
}).add;
)


// --- Bass Synth ---
(
SynthDef(\bassSynth, {
    |out = 0, freq = 60, amp = 0.3, gate = 1, pan = 0, atk = 0.01, rel = 0.4,
     ffreq = 200, rq = 0.3, subOct = 0.5, drive = 0.2|

    var osc, sub, mix, filt, env;

    // Main osc: pulse wave for bass body
    osc = Pulse.ar(freq, 0.45, 0.8);

    // Sub osc: one octave below
    sub = SinOsc.ar(freq / 2, 0, subOct);

    // Mix and drive
    mix = (osc + sub).tanh * (1 + drive);

    // Filter for roundness
    filt = RLPF.ar(mix, ffreq, rq);

    // Envelope for shape
    env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);

    // Output
    Out.ar(out, Pan2.ar(filt * env * amp, pan));
}).add;
)


// --- Drone Synth ---

(
SynthDef(\droneSynth, {
    |out = 0, freq=55, amp=0.2, pan=0, gate=1,
     droneDetune=0.1, lfoRate=0.05, lfoDepth=0.01,
     ffreq=800, rq=0.3, revMix=0.4|

	var osc, detuneFactors, detuned, lfo, filt, env, rev, snd, mid, side, stereo;

	// store the multipliers first
	detuneFactors = Array.fill(4, { LFNoise1.kr(0.1).range(1 - droneDetune, 1 + droneDetune) });

	// now make the oscillators
	detuned = Mix.fill(4, { |i| Saw.ar(freq * detuneFactors[i])});

	// detuneFactors.do { |df, i| Poll.kr(Impulse.kr(1), df, "Drone detune factor " ++ i)};

	// slow LFO for movement (amplitude + subtle freq wobble)
	lfo = SinOsc.kr(lfoRate).range(1 - lfoDepth, 1 + lfoDepth);

    // resonant lowpass → shaping brightness
    filt = RLPF.ar(detuned, ffreq * lfo, rq);

    // long envelope (ASR)
    env = EnvGen.kr(Env.asr(5, 1, 10), gate, doneAction:2);

    // space
    rev = FreeVerb.ar(filt, mix: revMix, room: 0.9, damp: 0.7);

    // Haas trick
    stereo = [rev * 0.7, DelayC.ar(rev, 0.02, 0.005)];

    // Mid/Side encode
    mid  = (stereo[0] + stereo[1]) * 0.5;
    side = (stereo[0] - stereo[1]) * 0.5;

    // no mid
    stereo = [side, 1 - side];

    Out.ar(out, stereo * env * amp);
}).add;
)


// --- Harp Synth ---

(
SynthDef(\harpPluck, { |out = 0, freq=440, amp=0.2, decay=4, coef=0.3, pan=0,
    revMix=0.3, revRoom=0.8, revDamp=0.5|
    var excEnv, exciter, string, body, panSig, rev, ampEnv, snd;

    // Short exciter burst (noise impulse)
    excEnv = EnvGen.kr(Env.perc(0.001, 0.03, 1), doneAction: 0);
    exciter = PinkNoise.ar * excEnv;

    // Karplus-Strong string
    string = Pluck.ar(
        in: exciter,
        trig: 1,
        maxdelaytime: 0.1,
        delaytime: 1/freq,
        decaytime: decay,
        coef: coef
    );

    // Resonant body filter
    body = LPF.ar(string, freq * 4);

    // Pan
    pan = Pan2.ar(body, pan);

    // Reverb
    rev = FreeVerb.ar(pan, mix: revMix, room: revRoom, damp: revDamp);

    // Amplitude envelope controls full synth lifetime
    ampEnv = EnvGen.kr(
        Env.linen(0.001, decay, 0.1, 1),
        doneAction: 2
    );

    // Saturation + final scaling
    snd = (rev * 5).tanh * ampEnv * amp;

    Out.ar(out, snd);
}).add;
)


// --- Glass Arp Synth ---

(
SynthDef(\glassArp, { |out = 0, freq=440, noiseLength=0.3, amp=0.2, atk=0.005, rel=2, pan=0,
    revMix=0.3, rq=0.05, bright=0.7, gate=1|

    var exc, excAmp, resonAmp, env, reson, partials, amps, rels, rev, snd, noise;

	// Air
	noise = tanh(PinkNoise.ar(noiseLength) * 2) * 0.5;
	noise = FreeVerb.ar(noise, mix: revMix - 0.2, room: 0.6, damp: 0.7);

    // Exciter: short burst of noise + sine
    exc = noise + SinOsc.ar(freq, 0, 0.3);

	// Debug: measure amplitude of exc
/*	excAmp = Amplitude.kr(exc, 0.01, 0.01); // fast envelope follower
	Poll.kr(Impulse.kr(5), excAmp, "exc amplitude");*/

    // Envelope for exciter
    env = EnvGen.kr(Env.perc(atk, rel), gate, doneAction: 2);

    // Resonant filter "glass tone" (narrow bandpass)
	partials = [1,   2,   3,   4,   5.001, 6,    20/3];
	amps =     [1.0, 0.5, 0.4, 0.2, 0.1,   0.05, 0.01];
	rels =     [2.0, 1.3, 1.2, 0.7, 0.3,   0.4,  0.25];
	reson = tanh(Mix.fill(partials.size, { |i|
		Ringz.ar(exc, freq * partials[i], rels[i], amps[i])
	}) * 0.002);

/*	resonAmp = Amplitude.kr(reson, 0.01, 0.01);
	Poll.kr(Impulse.kr(5), resonAmp, "reson amplitude");*/

    // Brightness control (emphasize high partials)
    reson = reson * bright + LPF.ar(reson, 2000 * bright);

    // Reverb for space
    rev = FreeVerb.ar(reson * env, mix: revMix - 0.3, room: 0.9, damp: 0.4);

    // Pan & output
    snd = Pan2.ar(rev, pan, amp);

    Out.ar(out, snd);
}).add;
)


// --- Bell Synth ---

(
SynthDef(\bell, { |out = 0, freq=220, amp=0.3, pan=0, gate=1, lpfFactor=2, revMix=0.35, revRoom=1, revDamp=0.7|
    var snd, env, partials, freqs, amps, decays, body, rev;

    // main envelope (long exponential fade, gated)
    env = EnvGen.kr(Env.asr(0.01, 1, 6, curve: -10), gate, doneAction:2);

    // inharmonic partial ratios (bell-like spectra)
    freqs = freq * [0.5, 0.66, 1   , 2   , 2.73, 3.01, 4.05, 4.97, 6.01, 7.32]; // slightly weird ratios
    amps   =       [0.7, 0.5 , 1.0 , 0.5 , 0.03, 0.2 , 0.15, 0.1 , 0.05, 0.03]; // balance of partials
    decays =       [3  , 2   , 6   , 2   , 0.4 , 1   , 0.5 , 1   , 0.7 , 0.6 ]; // longer ring for low partials

    // sum partials with individual decays
    partials = Mix.fill(freqs.size, { |i|
        SinOsc.ar(freqs[i]) *
		EnvGen.kr(Env.perc(0.001, decays[i]), doneAction: 0) * amps[i]
    });

    // slight attack "clang" using FM
    snd = partials + (SinOsc.ar(freq * 1.5, mul: 0.2) * Decay2.kr(Impulse.kr(0), 0.005, 0.2));

    // soft low-pass shaping
    body = LPF.ar(snd, freq * lpfFactor);

    // stereo spread + reverb
    body = Pan2.ar(body, pan, amp);
    rev  = FreeVerb.ar(body, mix:revMix, room: revRoom, damp:revDamp);

    // gentle saturation for fullness
    Out.ar(out, (rev * 3).tanh * env);
}).add;
)


// --- Textrure Synths ---

(
// Sea like texture
SynthDef(\seaSynth, {
    |out = 0, amp = 0.1, ffreq = 1000, rq = 0.3,
     modRate = 0.05, modDepth = 300, pan = 0,
     pinkAmt = 0.5, whiteAmt = 0.5, revMix = 0.5,
     waveRate = 0.03, waveDepth = 0.4,
     atk = 4, sus = 1, rel = 6|  // swell timing in seconds

    var src, mod, filt, env, rev, waveLFO;

    // Noise source (warm)
    src = PinkNoise.ar(pinkAmt) + WhiteNoise.ar(whiteAmt);

    // LFO modulating filter cutoff
    mod = SinOsc.kr(modRate, Rand(0, 2pi), modDepth, ffreq);

    // Resonant low-pass filter
    filt = RLPF.ar(src, mod, rq);

    // Wave motion LFO
    waveLFO = SinOsc.kr(waveRate, Rand(0, 2pi)).range(1 - waveDepth, 1);

    // ASR envelope
    env = EnvGen.kr(Env.linen(atk, sus, rel, curve: -4), doneAction: 2);

    // Reverb space
    rev = FreeVerb.ar(filt * env * amp * waveLFO, mix: revMix, room: 0.9, damp: 0.7);

    Out.ar(out, Pan2.ar(rev, pan));
}).add;
)

)

// Vinyl Crackle Synth
(
SynthDef(\vinylCrackle, {
    |out = 0, amp=0.1, dustDensity=3, lpFreq=4000, hpFreq=800,
     rumbleLevel=0.1, rumbleFreq=50,
     humLevel=0.02,
     wowRate=0.3, wowDepth=0.05|

    var trig, env, src, filtered, grainAmp, grainRel, saturated;
    var rumble, hum, wow, mix, panned;

    // --- Crackles ---
    trig = Dust.kr(dustDensity);
    grainAmp = TRand.kr(0.1, 1.0, trig);      // per-grain random amp
    grainRel = TRand.kr(0.003, 0.005, trig);  // per-grain random length
    env = EnvGen.kr(Env.perc(0.001, grainRel), trig) * grainAmp;
    src = PinkNoise.ar(amp) * env;
    filtered = HPF.ar(LPF.ar(src, lpFreq), hpFreq);
	saturated = tanh(filtered * 5);

    // --- Mechanical rumble (low brown noise) ---
    rumble = LPF.ar(BrownNoise.ar(rumbleLevel), rumbleFreq);

    // --- Electrical hum (fundamental + harmonics) ---
    hum = (SinOsc.ar(50) + 0.5 * SinOsc.ar(100) + 0.25 * SinOsc.ar(150)) * humLevel;

    // --- Wow/flutter (slow amplitude wobble) ---
    wow = SinOsc.kr(wowRate, 0, wowDepth, 1);

    // --- Mix & output ---
    mix = (saturated + rumble + hum) * wow;
    panned = Pan2.ar(mix, LFNoise1.kr(5).range(-0.5, 0.5));
    Out.ar(out, panned);
}).add;
)

// Rain sound
(
SynthDef(\rainTexture, { |out = 0, amp=0.2,
    densFactor= 1, hp=400, lp=6000,
    revMix=0.25, rq=0.3, noiseAmp=0.3|

    var trigNear, trigFar, nearDrops, farDrops, noiseBed, rain, rev, densNear, densFar;

	densNear = 10 * densFactor;
	densFar  = 100 * densFactor;

    // 1. NEARBY drops (louder, fewer)
    trigNear = Dust.kr(densNear); // sparser
    nearDrops = Decay2.kr(trigNear, 0.001, TRand.kr(0.05, 0.15, trigNear)) * PinkNoise.ar(0.6);
    nearDrops = BPF.ar(nearDrops,TExpRand.kr(700, 1500, trigNear), 0.5);

	// Pan hardish sides
    nearDrops = Pan2.ar(nearDrops, Select.kr(TRand.kr(0,1,trigNear).round, [TRand.kr(-1.0, -0.6, trigNear), TRand.kr(0.6, 1.0, trigNear)]));

    // 2. FAR drops (many, quieter)
    trigFar = Dust.kr(densFar); // denser
    farDrops = Decay2.kr(trigFar, 0.002, TRand.kr(0.05, 0.1, trigFar)) * BrownNoise.ar(0.3);
    farDrops = BPF.ar(farDrops, TExpRand.kr(2000, 3000, trigFar), 0.4);

	// Spread narrower, closer to center
    farDrops = Pan2.ar(farDrops, TRand.kr(-0.6, 0.6, trigFar));

    // 3. Background noise "rain sheet"
    noiseBed = WhiteNoise.ar(0.2) * 0.5
             + PinkNoise.ar(0.2)  * 0.3
             + BrownNoise.ar(0.2) * 0.2;
    noiseBed = HPF.ar(LPF.ar(noiseBed, lp), hp) * noiseAmp;
    noiseBed = Splay.ar(noiseBed, 0.3); // stereo spread

    // Mix all layers
    rain = nearDrops + farDrops + noiseBed;

    // Reverb for space
    rev = FreeVerb.ar(rain, mix: 0.2, room: 0.9, damp: 0.9);

    Out.ar(out, rev * amp);
}).add;
)


// --- Harmony ---
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

// choose scale by name
~setScale = { |name=\ionian|
    var pcs = ~scales[name];
    if(pcs.isNil) { ("Unknown scale: " ++ name).warn } { ~scalePcs = pcs; };
    ("Scale set to " ++ name ++ " → " ++ ~scalePcs).postln;
};

// choose tonic by note name + octave
~setKey = { |name=\C, octave=4|
	var pc = ~noteNames[name] ? 0;
	~keyMidi = ((octave + 1) * 12) + pc;
	("Key set to " ++ name ++ octave ++ " (MIDI " ++ ~keyMidi ++ ")").postln;
};

// Safety measure
~ensureScaleAndKey = {
    if(~keyMidi.isNil) {
        "No key set – defaulting to C4".postln;
        ~setKey.(\C, 4);
    };
    if(~scalePcs.isNil) {
        "No scale set – defaulting to ionian".postln;
        ~setScale.(\ionian);
    };
};

// Scale to MIDI mapping
~scaleToMidi = {
    ~ensureScaleAndKey.();
    ~scalePcs.collect { |interval| ~keyMidi + interval }
};

// Define allowed drone anchors
~droneDegrees = [1, 2, 4, 5];

// Set the drone note
~getDroneNote = { |degree=2, octaveShift=3|
    var scale = ~scaleToMidi.();
    var note = scale.wrapAt(degree - 1); // pick scale degree
    note = note + (12 * octaveShift);           // shift if needed
	("[Drone DEBUG] Note: " ++ note ++ " | "
		++ note.midicps).postln;

	note
};

// Build a chord by weighted selection (now reacts to variability)
~weightedChord = { |degree|
	var scaleMidis, rootIndex, size, tonePool, chosenSteps, total, r, acc, choice;

	scaleMidis = ~scaleToMidi.();
	rootIndex = degree - 1;
	size = ~getChordSize.();

	// tone pool with weights
	tonePool = [
		[0,   1.0], // root
		[2,   0.8], // 3rd
		[4,   0.9], // 5th
		[6,   0.5], // 7th
		[8,   0.3], // 9th
		[3,   0.2], // 4th
		[5,   0.1], // 6th
		[7,   0.05], // 11th (same pitch class as 4th)
		[9,   0.01]  // 13th (same pitch class as 6th)
	];

	// pick notes with rules
	chosenSteps = [];

	size.do {
		// For every already chosen step in the chord...
		chosenSteps.do { |step|

			switch(step,

				3, { // Already have a 4th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 6th (p[0] == 5) or a 13th (p[0] == 9)
						if((p[0] == 5) or: (p[0] == 9)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] } { p }
					};
				},

				5, { // Already have a 6th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3) or 7th (p[0] == 7)
						if((p[0] == 3) or: (p[0] == 7)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 9th (p[0] == 8)
						{ if(p[0] == 8) { [p[0], p[1] * 1.2] } { p } }
					};
				},

				6, { // Already have a 7th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3) or a 6th (p[0] == 5)
						if((p[0] == 3) or: (p[0] == 5)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 9th (p[0] == 8)
						{ if(p[0] == 8) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 1.1, 1.5)] } { p } }
					};
				},

				8, { // Already have a 9th in the chord
					tonePool = tonePool.collect { |p|
						// Reduce chance of adding a 4th (p[0] == 3)
						if((p[0] == 3)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 0.1, 0.5)] }
						// Increase chance of adding a 3rd (p[0] == 4) or a 6th (p[0] == 5)
						{ if((p[0] == 4) or: (p[0] == 5)) { [p[0], p[1] * ~mapLin.(~parameters[\variability], 0, 1, 1.1, 1.5)] } { p } }
					};
				}
			);
		};

		// Pick notes without doubles
		total = tonePool.sum { |p| p[1] };
		r = total.rand;
		acc = 0.0;
		choice = tonePool.detect { |p|
			acc = acc + p[1];
			r < acc
		};

		if(choice.notNil) {
			chosenSteps = chosenSteps.add(choice[0]);
			tonePool.remove(choice); // remove to avoid duplicates
		};
	};

	// Debug: check for duplicates
	if(chosenSteps.size != chosenSteps.as(Set).size) {
		("[WeightedChord DEBUG] Duplicate found: " ++ chosenSteps).warn;
	} {
		("[WeightedChord DEBUG] Unique notes: " ++ chosenSteps).postln;
	};

	// map steps to MIDI and sort
	chosenSteps = chosenSteps.sort;
	chosenSteps.collect { |s|
		scaleMidis.wrapAt(rootIndex + s)
	}
};

// Range for notes
~clampChordRangeDynamic = { |notes|
    var root, minNote, maxNote, clamped;
	root = notes.first;  // assume first note = root
    minNote = root - 7;  // perfect 5th below root
    maxNote = root + 24; // 2 octaves above root

    clamped = notes.collect { |n|
        var x = n;
        while { x < minNote } { x = x + 12 };
        while { x > maxNote } { x = x - 12 };
        x
    };

    // Debug
    ("[RelClamp DEBUG] Root: " ++ root
        ++ " | Range: " ++ minNote ++ "-" ++ maxNote
        ++ " | Before: " ++ notes
        ++ " | After: " ++ clamped).postln;

    clamped
};

// Boundries for notes
~clampChordRangeStatic = { |notes|
    var bright = ~mapLin.(~parameters[\warmth], 0, 1, 24, 0).round.asInteger;
	var minNote = 48 + bright;
	var maxNote = minNote + ~mapLin.(~parameters[\density], 0, 1, 36, 24).round.asInteger;

    var clamped = notes.collect { |n|
        var x = n;
        while { x < minNote } { x = x + 12 };
        while { x > maxNote } { x = x - 12 };
        x
    };

	// Debug print
	("[Clamp DEBUG]  Min: " ++ minNote
	 ++ " | Max: " ++ maxNote
	 ++ " | Before: " ++ notes
	 ++ " | After: " ++ clamped).postln;

    clamped
};

~lastChord = ~weightedChord.(1, 4); // start at degree 1

// Voice leading
~voiceLeading = { |newChord, lastChord|
    var maxLeap = ~mapLin.(~parameters[\variability], 0, 1, 4, 6).round.asInteger;

    if(lastChord.isNil) {
        ~clampChordRangeDynamic.(newChord)
    } {
        // Step 1: voice lead by nearest register
        var led = newChord.collect { |note, i|
            var target = note;
            var lastNote = lastChord.wrapAt(i);

            while { target - lastNote > maxLeap } { target = target - 12 };
            while { lastNote - target > maxLeap } { target = target + 12 };
            target
        };

        // Step 2: clamp into global range
        led = ~clampChordRangeDynamic.(led);

        // Step 3: avoid muddy intervals in low register
        led = led.sort;
        led = led.collect { |n, i|
            if(i > 0 and: { n < 72 and: { (n - led[i-1]).abs < 4 } }) {
                n + 12  // push up one octave if too close under 72
            } {
                n
            }
        };

        led
    }
};

// Getter for chord size with randomness influenced by variability
~getChordSize = {
    var baseSize = ~mapLin.(~parameters[\density], 0, 1, 2, 5).round.asInteger;
    var varChance = ~mapLin.(~parameters[\variability], 0, 1, 0.0, 0.6);

    // Randomly add or subtract 1 based on variability chance
    if(varChance.coin) {
        baseSize = baseSize + ([-1, 1].choose);
    };

    // Constrain size between 2 and 6 voices
    baseSize.clip(2, 5)
};

// Build a chord with voice leading
~voiceLeadChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~weightedChord.(degree, size);
    chord = ~voiceLeading.(chord, ~lastChord);
    ~lastChord = chord; // store for next time
    chord
};

// Build the final chord
~finalChord = { |degree|
	var size, chord;
	size = ~getChordSize.();
    chord = ~voiceLeadChord.(degree);
	chord = ~clampChordRangeStatic.(chord);

	// Debug print final chord (both MIDI & Hz + voice count)
	("[Chord DEBUG @ " ++ Main.elapsedTime.round(0.01) ++ "] Voices: "
    ++ chord.size ++ " | MIDI: " ++ chord ++ " | Hz: " ++ chord.midicps).postln;



    ~lastChord = chord;
    chord
};

// Predefined amplitude levels for 2..6 voices
~ampLevels = (
	1: 0.7,
    2: 0.5,
    3: 0.35,
    4: 0.22,
    5: 0.15,
    6: 0.1,
	7: 0.07,
);

// Function to get amp for current chord size
~getAmpForVoices = { |numVoices|
    ~ampLevels[numVoices] * 0.7 ? 0.1 // fallback if somehow outside 2..6
};

// --- Markov second order harmony (degrees 1..7) ---
~degreeMarkov2 = (
    11: [[2,0.3],[3,0.3],[4,0.3],[5,0.1]],
    12: [[3,0.3],[4,0.4],[6,0.3]],
    13: [[4,0.4],[6,0.4],[2,0.2]],
    14: [[5,0.4],[2,0.3],[6,0.3]],
    15: [[6,0.4],[4,0.4],[2,0.2]],
    16: [[4,0.4],[2,0.3],[3,0.3]],
    17: [[1,0.3],[3,0.4],[4,0.3]],

    21: [[4,0.4],[5,0.3],[3,0.3]],
    22: [[4,0.4],[6,0.4],[1,0.2]],
    23: [[4,0.3],[1,0.3],[6,0.4]],
    24: [[5,0.3],[6,0.3],[1,0.4]],
    25: [[1,0.4],[6,0.3],[3,0.3]],
    26: [[4,0.4],[2,0.3],[1,0.3]],
    27: [[1,0.3],[4,0.4],[2,0.3]],

    31: [[6,0.4],[4,0.3],[2,0.3]],
    32: [[4,0.4],[1,0.3],[6,0.3]],
    33: [[6,0.3],[4,0.4],[1,0.3]],
    34: [[5,0.4],[6,0.3],[1,0.3]],
    35: [[1,0.3],[4,0.4],[2,0.3]],
    36: [[4,0.3],[1,0.4],[2,0.3]],
    37: [[1,0.4],[4,0.3],[3,0.3]],

    41: [[5,0.4],[2,0.3],[6,0.3]],
    42: [[5,0.3],[6,0.3],[1,0.4]],
    43: [[6,0.3],[1,0.4],[2,0.3]],
    44: [[5,0.4],[1,0.3],[6,0.3]],
    45: [[1,0.4],[6,0.3],[2,0.3]],
    46: [[2,0.4],[1,0.3],[5,0.3]],
    47: [[1,0.3],[4,0.4],[2,0.3]],

    51: [[6,0.4],[4,0.4],[2,0.2]],
    52: [[6,0.3],[4,0.4],[1,0.3]],
    53: [[1,0.3],[4,0.4],[6,0.3]],
    54: [[1,0.4],[6,0.4],[2,0.2]],
    55: [[1,0.4],[6,0.3],[4,0.3]],
    56: [[2,0.4],[4,0.3],[1,0.3]],
    57: [[1,0.3],[5,0.4],[2,0.3]],

    61: [[4,0.4],[2,0.3],[3,0.3]],
    62: [[4,0.3],[1,0.3],[5,0.4]],
    63: [[1,0.4],[4,0.3],[2,0.3]],
    64: [[5,0.4],[1,0.3],[2,0.3]],
    65: [[1,0.4],[6,0.3],[4,0.3]],
    66: [[4,0.4],[2,0.3],[1,0.3]],
    67: [[1,0.3],[4,0.4],[2,0.3]],

    71: [[5,0.4],[3,0.3],[4,0.3]],
    72: [[4,0.3],[1,0.4],[6,0.3]],
    73: [[1,0.4],[4,0.3],[2,0.3]],
    74: [[1,0.3],[6,0.3],[5,0.4]],
    75: [[1,0.4],[6,0.3],[4,0.3]],
    76: [[4,0.4],[2,0.3],[1,0.3]],
    77: [[1,0.4],[4,0.3],[2,0.3]]
);

// Second-order Markov for ambient harmony (degrees 1..7)
~degreeMarkov2Ambient = (

    // From I (1)
    11: [[2,0.25],[4,0.35],[6,0.3],[1,0.1]],
    12: [[4,0.35],[6,0.3],[1,0.2],[3,0.15]],
    14: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    16: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From ii (2)
    21: [[4,0.35],[6,0.25],[3,0.2],[1,0.2]],
    22: [[4,0.35],[6,0.35],[1,0.2],[3,0.1]],
    23: [[4,0.35],[6,0.3],[2,0.2],[1,0.15]],
    24: [[6,0.3],[2,0.25],[1,0.25],[3,0.2]],
    26: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From iii (3) – acts as connector
    31: [[6,0.35],[4,0.35],[2,0.2],[1,0.1]],
    32: [[4,0.35],[6,0.3],[1,0.2],[3,0.15]],
    33: [[4,0.35],[6,0.35],[2,0.2],[1,0.1]],
    34: [[6,0.3],[2,0.3],[1,0.2],[5,0.2]],
    36: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From IV (4) – "pivot" node
    41: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    42: [[6,0.35],[4,0.25],[1,0.25],[3,0.15]],
    43: [[6,0.3],[2,0.3],[1,0.25],[5,0.15]],
    44: [[6,0.3],[1,0.3],[2,0.25],[5,0.15]],
    46: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From V (5) – softened
    51: [[4,0.35],[6,0.3],[2,0.2],[1,0.15]],
    52: [[6,0.3],[4,0.3],[1,0.25],[3,0.15]],
    53: [[1,0.25],[4,0.35],[6,0.25],[2,0.15]],
    54: [[1,0.25],[6,0.35],[2,0.25],[3,0.15]],
    56: [[1,0.3],[4,0.3],[2,0.25],[3,0.15]],

    // From vi (6) – modal anchor
    61: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],
    62: [[4,0.3],[1,0.3],[5,0.2],[3,0.2]],
    63: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],
    64: [[1,0.3],[6,0.25],[2,0.25],[5,0.2]],
    66: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]],

    // From vii° (7) – rare, drifty
    71: [[2,0.4],[4,0.4],[6,0.2]],
    72: [[4,0.35],[2,0.3],[1,0.2],[6,0.15]],
    73: [[4,0.4],[2,0.3],[6,0.2],[1,0.1]],
    74: [[2,0.35],[6,0.35],[1,0.2],[4,0.1]],
    76: [[1,0.3],[4,0.35],[2,0.2],[3,0.15]]
);

// Second-order Markov for exotic ambient harmony
~degreeMarkov2Exotic = (

    // I behaves less "tonic-y"
    11: [[2,0.25],[3,0.2],[4,0.25],[6,0.2],[7,0.1]],
    12: [[3,0.25],[4,0.2],[6,0.25],[7,0.2],[1,0.1]],
    13: [[4,0.25],[6,0.25],[7,0.2],[2,0.15],[1,0.15]],
    14: [[2,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    16: [[7,0.25],[2,0.25],[4,0.2],[3,0.2],[1,0.1]],
    17: [[2,0.3],[4,0.25],[6,0.2],[3,0.15],[1,0.1]],

    // ii wanders sideways (Dorian / Phrygian feel)
    21: [[3,0.25],[4,0.25],[6,0.25],[7,0.15],[1,0.1]],
    22: [[4,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    23: [[4,0.25],[6,0.25],[7,0.25],[2,0.15],[1,0.1]],
    24: [[6,0.25],[7,0.25],[2,0.2],[3,0.2],[1,0.1]],
    26: [[7,0.25],[2,0.25],[4,0.2],[3,0.2],[1,0.1]],

    // iii now strong connector to exotic color
    31: [[4,0.25],[6,0.25],[7,0.25],[2,0.15],[1,0.1]],
    32: [[4,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    33: [[6,0.25],[7,0.25],[4,0.25],[2,0.15],[1,0.1]],
    34: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    36: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // IV less pivot, more modal shift
    41: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    42: [[7,0.25],[4,0.25],[6,0.25],[2,0.15],[1,0.1]],
    43: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    44: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    46: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // V not dominant at all, can escape anywhere
    51: [[2,0.25],[3,0.25],[6,0.25],[7,0.15],[1,0.1]],
    52: [[6,0.25],[7,0.25],[2,0.25],[3,0.15],[1,0.1]],
    53: [[7,0.25],[2,0.25],[6,0.25],[3,0.15],[1,0.1]],
    54: [[7,0.25],[6,0.25],[2,0.25],[3,0.15],[1,0.1]],
    56: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // vi modal anchor but much freer
    61: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],
    62: [[7,0.25],[4,0.25],[6,0.25],[2,0.15],[1,0.1]],
    63: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],
    64: [[7,0.25],[2,0.25],[6,0.25],[3,0.15],[1,0.1]],
    66: [[7,0.25],[2,0.25],[4,0.25],[3,0.15],[1,0.1]],

    // vii° gets promoted — dreamy tension
    71: [[2,0.25],[4,0.25],[6,0.25],[3,0.15],[7,0.1]],
    72: [[4,0.25],[2,0.25],[6,0.25],[7,0.15],[1,0.1]],
    73: [[4,0.25],[2,0.25],[6,0.25],[7,0.15],[1,0.1]],
    74: [[2,0.25],[6,0.25],[7,0.25],[3,0.15],[1,0.1]],
    76: [[2,0.25],[4,0.25],[7,0.25],[3,0.15],[1,0.1]]
);


// --- additional markov tables (Scale size ≠ 7) ---

~degreeMarkov2Pent = (

    // From I (1)
    11: [[1,0.2],[2,0.3],[3,0.2],[5,0.3]],   // tonic stable, can drift to 2,3,5
    12: [[2,0.2],[3,0.3],[5,0.3],[4,0.2]],
    13: [[3,0.2],[2,0.3],[4,0.3],[5,0.2]],
    14: [[4,0.2],[3,0.3],[5,0.3],[1,0.2]],
    15: [[5,0.3],[4,0.3],[2,0.2],[1,0.2]],

    // From II (2)
    21: [[2,0.2],[3,0.3],[1,0.3],[5,0.2]],
    22: [[2,0.2],[3,0.3],[4,0.3],[1,0.2]],
    23: [[3,0.2],[2,0.3],[4,0.3],[5,0.2]],
    24: [[4,0.2],[3,0.3],[5,0.3],[1,0.2]],
    25: [[5,0.2],[4,0.3],[2,0.3],[1,0.2]],

    // From III (3)
    31: [[3,0.2],[2,0.3],[4,0.3],[1,0.2]],
    32: [[2,0.2],[3,0.3],[5,0.3],[4,0.2]],
    33: [[3,0.2],[2,0.3],[4,0.3],[5,0.2]],
    34: [[4,0.2],[3,0.3],[5,0.3],[1,0.2]],
    35: [[5,0.2],[4,0.3],[3,0.3],[1,0.2]],

    // From IV (4)
    41: [[4,0.2],[3,0.3],[5,0.3],[1,0.2]],
    42: [[4,0.2],[5,0.3],[2,0.3],[1,0.2]],
    43: [[4,0.2],[3,0.3],[5,0.3],[2,0.2]],
    44: [[4,0.2],[3,0.3],[5,0.3],[1,0.2]],
    45: [[5,0.2],[4,0.3],[3,0.3],[1,0.2]],

    // From V (5)
    51: [[5,0.2],[4,0.3],[2,0.3],[1,0.2]],
    52: [[5,0.2],[4,0.3],[3,0.3],[1,0.2]],
    53: [[5,0.2],[4,0.3],[3,0.3],[2,0.2]],
    54: [[5,0.2],[4,0.3],[3,0.3],[1,0.2]],
    55: [[5,0.2],[4,0.3],[3,0.3],[1,0.2]]
);

~degreeMarkov2Hex = (

    // From I (1)
    11: [[1,0.2],[2,0.25],[3,0.25],[5,0.2],[6,0.1]],
    12: [[2,0.2],[3,0.25],[4,0.25],[1,0.2],[5,0.1]],
    13: [[3,0.2],[2,0.25],[4,0.25],[5,0.2],[1,0.1]],
    14: [[4,0.2],[3,0.25],[5,0.25],[6,0.2],[1,0.1]],
    15: [[5,0.2],[4,0.25],[6,0.25],[2,0.2],[1,0.1]],
    16: [[6,0.2],[5,0.25],[4,0.25],[3,0.2],[1,0.1]],

    // From II (2)
    21: [[2,0.2],[3,0.25],[1,0.25],[4,0.2],[5,0.1]],
    22: [[2,0.2],[3,0.25],[4,0.25],[1,0.2],[6,0.1]],
    23: [[3,0.2],[2,0.25],[4,0.25],[5,0.2],[1,0.1]],
    24: [[4,0.2],[3,0.25],[5,0.25],[6,0.2],[2,0.1]],
    25: [[5,0.2],[4,0.25],[6,0.25],[3,0.2],[2,0.1]],
    26: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[3,0.1]],

    // From III (3)
    31: [[3,0.2],[2,0.25],[4,0.25],[1,0.2],[5,0.1]],
    32: [[2,0.2],[3,0.25],[5,0.25],[4,0.2],[6,0.1]],
    33: [[3,0.2],[2,0.25],[4,0.25],[6,0.2],[5,0.1]],
    34: [[4,0.2],[3,0.25],[5,0.25],[1,0.2],[6,0.1]],
    35: [[5,0.2],[4,0.25],[6,0.25],[2,0.2],[3,0.1]],
    36: [[6,0.2],[5,0.25],[4,0.25],[3,0.2],[1,0.1]],

    // From IV (4)
    41: [[4,0.2],[3,0.25],[5,0.25],[1,0.2],[6,0.1]],
    42: [[4,0.2],[5,0.25],[2,0.25],[6,0.2],[1,0.1]],
    43: [[4,0.2],[3,0.25],[5,0.25],[2,0.2],[6,0.1]],
    44: [[4,0.2],[3,0.25],[5,0.25],[6,0.2],[1,0.1]],
    45: [[5,0.2],[4,0.25],[6,0.25],[3,0.2],[2,0.1]],
    46: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[1,0.1]],

    // From V (5)
    51: [[5,0.2],[4,0.25],[3,0.25],[1,0.2],[6,0.1]],
    52: [[5,0.2],[4,0.25],[6,0.25],[2,0.2],[3,0.1]],
    53: [[5,0.2],[4,0.25],[6,0.25],[3,0.2],[2,0.1]],
    54: [[5,0.2],[4,0.25],[6,0.25],[2,0.2],[1,0.1]],
    55: [[5,0.2],[4,0.25],[6,0.25],[3,0.2],[1,0.1]],
    56: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[1,0.1]],

    // From VI (6)
    61: [[6,0.2],[5,0.25],[4,0.25],[1,0.2],[3,0.1]],
    62: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[1,0.1]],
    63: [[6,0.2],[5,0.25],[4,0.25],[3,0.2],[2,0.1]],
    64: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[1,0.1]],
    65: [[6,0.2],[5,0.25],[4,0.25],[3,0.2],[1,0.1]],
    66: [[6,0.2],[5,0.25],[4,0.25],[2,0.2],[1,0.1]]
);

// --- Second-order Markov for ambient octatonic (degrees 1..8) ---
~degreeMarkov2Oct = (

    // From I (1)
    11: [[1,0.15],[2,0.2],[8,0.2],[3,0.1],[7,0.1],[5,0.15]],
    12: [[2,0.15],[1,0.2],[3,0.2],[4,0.1],[8,0.1],[6,0.15]],
    13: [[3,0.15],[2,0.2],[4,0.2],[1,0.1],[5,0.1],[7,0.15]],
    14: [[4,0.15],[3,0.2],[5,0.2],[2,0.1],[6,0.1],[8,0.15]],
    15: [[5,0.15],[4,0.2],[6,0.2],[3,0.1],[7,0.1],[1,0.15]],
    16: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    17: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    18: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From II (2)
    21: [[1,0.15],[2,0.15],[3,0.2],[8,0.2],[4,0.1],[6,0.1]],
    22: [[2,0.15],[1,0.2],[3,0.2],[4,0.1],[6,0.1],[8,0.15]],
    23: [[3,0.15],[2,0.2],[4,0.2],[1,0.1],[5,0.1],[7,0.15]],
    24: [[4,0.15],[3,0.2],[5,0.2],[2,0.1],[6,0.1],[8,0.15]],
    25: [[5,0.15],[4,0.2],[6,0.2],[3,0.1],[7,0.1],[1,0.15]],
    26: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    27: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    28: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From III (3)
    31: [[1,0.15],[2,0.1],[3,0.15],[4,0.2],[8,0.1],[5,0.2],[7,0.1]],
    32: [[2,0.15],[3,0.15],[4,0.2],[1,0.1],[5,0.1],[6,0.2],[8,0.1]],
    33: [[3,0.15],[2,0.2],[4,0.2],[1,0.1],[5,0.1],[7,0.15]],
    34: [[4,0.15],[3,0.2],[5,0.2],[2,0.1],[6,0.1],[8,0.15]],
    35: [[5,0.15],[4,0.2],[6,0.2],[3,0.1],[7,0.1],[1,0.15]],
    36: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    37: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    38: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From IV (4)
    41: [[1,0.15],[3,0.1],[4,0.15],[5,0.2],[2,0.1],[6,0.2],[8,0.1]],
    42: [[2,0.15],[4,0.15],[5,0.2],[3,0.1],[7,0.2],[1,0.1]],
    43: [[3,0.15],[4,0.15],[5,0.2],[2,0.1],[6,0.2],[8,0.1]],
    44: [[4,0.15],[3,0.2],[5,0.2],[2,0.1],[6,0.1],[8,0.15]],
    45: [[5,0.15],[4,0.2],[6,0.2],[3,0.1],[7,0.1],[1,0.15]],
    46: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    47: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    48: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From V (5)
    51: [[1,0.15],[5,0.15],[6,0.2],[4,0.1],[2,0.1],[7,0.2]],
    52: [[2,0.15],[5,0.15],[6,0.2],[3,0.1],[7,0.2],[8,0.1]],
    53: [[3,0.15],[5,0.15],[6,0.2],[2,0.1],[4,0.1],[8,0.2]],
    54: [[4,0.15],[5,0.15],[6,0.2],[3,0.1],[7,0.2],[1,0.1]],
    55: [[5,0.15],[4,0.2],[6,0.2],[3,0.1],[7,0.1],[1,0.15]],
    56: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    57: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    58: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From VI (6)
    61: [[1,0.15],[5,0.1],[6,0.15],[7,0.2],[3,0.1],[4,0.1],[8,0.2]],
    62: [[2,0.15],[6,0.15],[7,0.2],[1,0.1],[3,0.1],[5,0.1],[8,0.2]],
    63: [[3,0.15],[6,0.15],[7,0.2],[2,0.1],[4,0.1],[8,0.1],[1,0.2]],
    64: [[4,0.15],[6,0.15],[7,0.2],[3,0.1],[5,0.1],[1,0.1],[2,0.2]],
    65: [[5,0.15],[6,0.15],[7,0.2],[4,0.1],[8,0.1],[2,0.1],[3,0.2]],
    66: [[6,0.15],[5,0.2],[7,0.2],[4,0.1],[8,0.1],[2,0.15]],
    67: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    68: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

    // From VII (7)
    71: [[1,0.15],[7,0.15],[8,0.2],[2,0.1],[4,0.1],[6,0.2]],
    72: [[2,0.15],[7,0.15],[8,0.2],[3,0.1],[5,0.1],[1,0.2]],
    73: [[3,0.15],[7,0.15],[8,0.2],[2,0.1],[4,0.1],[6,0.2]],
    74: [[4,0.15],[7,0.15],[8,0.2],[3,0.1],[5,0.1],[1,0.2]],
    75: [[5,0.15],[7,0.15],[8,0.2],[4,0.1],[6,0.1],[2,0.2]],
    76: [[6,0.15],[7,0.15],[8,0.2],[5,0.1],[1,0.1],[3,0.2]],
    77: [[7,0.15],[6,0.2],[8,0.2],[5,0.1],[1,0.1],[3,0.15]],
    78: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]],

	// From VIII (8)
	81: [[1,0.15],[8,0.15],[7,0.2],[2,0.1],[4,0.1],[6,0.2]],
	82: [[2,0.15],[8,0.15],[1,0.2],[3,0.1],[5,0.1],[7,0.2]],
	83: [[3,0.15],[8,0.15],[2,0.2],[4,0.1],[6,0.1],[1,0.2]],
	84: [[4,0.15],[8,0.15],[3,0.2],[5,0.1],[7,0.1],[2,0.2]],
	85: [[5,0.15],[8,0.15],[4,0.2],[6,0.1],[1,0.1],[3,0.2]],
	86: [[6,0.15],[8,0.15],[5,0.2],[7,0.1],[2,0.1],[4,0.2]],
	87: [[7,0.15],[8,0.15],[6,0.2],[1,0.1],[3,0.1],[5,0.2]],
	88: [[8,0.15],[7,0.2],[1,0.2],[6,0.1],[2,0.1],[4,0.15]]
);

~chooseMarkov = {
    var n = ~scalePcs.size;
    var v = ~parameters[\variability];

    if(n == 5) {
        "Using Pentatonic Markov table".postln;
        ~degreeMarkov2Pent

    } {
        if(n == 6) {
            "Using Hexatonic Markov table".postln;
            ~degreeMarkov2Hex

        } {
            if(n == 8) {
                "Using Octatonic Markov table".postln;
                ~degreeMarkov2Oct

            } {
                // Default case = heptatonic (7-note scales)
                if(v < 0.4) {
                    "Using Ambient Markov table".postln;
                    ~degreeMarkov2Ambient
                } {
                    if(v < 0.75) {
                        "Using Balanced Markov table".postln;
                        ~degreeMarkov2
                    } {
                        "Using Exotic Markov table".postln;
                        ~degreeMarkov2Exotic
                    }
                }
            }
        }
    }
};

~prevDegree = 1;
~currentDegree = 4; // Starting point

~nextDegree = {
	var key, pairs, total, r, result, acc, penaltyFactor;

	pairs = ~degreeMarkov2[10 * ~prevDegree + ~currentDegree];
	// Debug print
	("[Markov DEBUG] pairs: " ++ pairs).postln;


	if(pairs.isNil) {pairs = [[1,1.0]]};
	penaltyFactor = (0.5).pow(~sameDegreeCount - 1);

    // Lower cance for doubles
    if(~sameDegreeCount >= 2) {
        pairs = pairs.collect { |p|
            if(p[0] == ~currentDegree) {
                [p[0], p[1] * penaltyFactor]
            }
        };
    };

	// Normalize weights
	total = pairs.sum { |p| p[1] };
	r = total.rand;
	acc = 0.0;
	result = pairs.detect { |p|
		acc = acc + p[1];
		r < acc
	}[0];

	// Debug print
	("[Markov DEBUG] prev: " ++ ~prevDegree
		++ " curr: " ++ ~currentDegree
		++ " -> next: " ++ result
		++ " | sameCount: " ++ ~sameDegreeCount).postln;

    // Shift degrees for next step
    ~prevDegree = ~currentDegree;
    ~currentDegree = result;

    result
};


~nextChord = {
    var deg, chord;

	deg = ~nextDegree.(); // fallback to degree 1 if nil
    chord = ~finalChord.(deg, 4, 0.3);

    chord
};

~clampBassRange = { |note, min=36, max=48|
    var x = note;
    while { x < min } { x = x + 12 };
    while { x > max } { x = x - 12 };

	// Debug print bass note (both MIDI & Hz)
    ("[Bass DEBUG] MIDI: " ++ x ++ " | Hz: " ++ x.midicps).postln;

    x
};
)


// --- Arpeggiator helper ---

(
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
	("[Arp DEBUG] Array size: " ++ result.size ++ ", Array: " ++ result).postln;

	result
};
)


// --- Pdef to play instruments simultaneously ---

(
~seaPattern = Pbind(
    \instrument, \seaSynth,
	\legato, Pwhite(0.97,1.03),

    // time between waves, in beats
	\dur, Pfunc({ ~getMapped.(\dur)}),

    // envelope shaping
    \atk, Pwhite(0.1, 0.4),   // proportion of dur
    \sus, Pwhite(0.05, 0.2),   // proportion of dur
    \rel, Pfunc { |ev|
        var beatDur = thisThread.clock.beatDur;
        var totalBeats = ev[\dur];
        var atkBeats   = (ev[\atk] * totalBeats);
        var susBeats   = (ev[\sus] * totalBeats);
        var relBeats   = (totalBeats - atkBeats - susBeats).max(0.1);
        relBeats * beatDur  // convert to seconds
    },

    // convert atk/sus also to seconds
    \atk,       Pfunc { |ev| ev[\atk] * ev[\dur] * thisThread.clock.beatDur },
    \sus,       Pfunc { |ev| ev[\sus] * ev[\dur] * thisThread.clock.beatDur },

    // synthesis params
    \ffreq,     1500,
    \rq,        0.7,
    \modRate,   Pfunc({ ~getMapped.(\modRate) } * 0.5),
    \modDepth,  Pfunc({ ~getMapped.(\modDepth) }),
    \pinkAmt,   Pfunc({ ~getMapped.(\noisePink) }),
    \whiteAmt,  Pfunc({ ~getMapped.(\noiseWhite) }),
    \revMix,    Pfunc({ ~getMapped.(\revMix) }),
    \waveDepth, Pfunc({ ~mapLin.(~parameters[\density], 0, 1, 0.1, 0.6) }),
    \waveRate,  Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 0.02, 0.08) }),
    \pan,       Pwhite(-1.0, 1.0),
    \amp,       Pfunc({ ~getMapped.(\seaAmp) }),
	\out,       ~seaBus
);

~vinylPattern = Pmono(
    \vinylCrackle,
    \dur,         Pfunc({ ~getMapped.(\dur) }),
	\dustDensity, Pfunc({
		var lo = 10 - rrand(0, 3);
		var hi = 20 - rrand(0, 5);
		~mapExp.(~parameters[\density], 0, 1, lo, hi)}),
    \lpFreq,      Pwhite(2000, 5000),
    \hpFreq,      Pwhite(500, 1500),
	\humLevel,    Pfunc({ ~getMapped.(\humLevel) }),
    \rumbleLevel, Pfunc({ ~getMapped.(\rumbleLevel) }),
    \amp, Pfunc({ ~getMapped.(\seaAmp) } ),
	\out, ~vinylBus
);

~rainPattern = Pmono(
    \rainTexture,
    \dur, Pfunc({ ~getMapped.(\dur) }),   // update every cycle
    \densFactor, Pfunc({ ~mapLin.(~parameters[\variability], 0, 1, 1, 2) }),
    \highpass, Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 200, 2000) }),
    \lowpass,  Pfunc({ ~mapLin.(~parameters[\brightness], 0, 1, 3000, 8000) }),
    \revMix,   Pfunc({ ~getMapped.(\revMix) }),
    \amp,      Pfunc({ ~getMapped.(\rainAmp) }),
	\out, ~rainBus
);

Pdef(\ambgen,
    Pspawner { |sp|
        var padSynths = List[];
		var darkPadSynths = List[];
        var bassSynths = List[];
		var droneSynths = List[];
        var chord, dur, subdiv, idx, durations, padFreqs, padPans, bassFreq, chordStartBeat;

		// Background layers
		sp.par(~vinylPattern);
		sp.par(~rainPattern);

        loop {
            chord = ~nextChord.();
            dur   = ~getMapped.(\dur);
			("Duration: " ++ dur).postln;
			durations = ~genDurations.(dur);
			chordStartBeat = thisThread.beats;  // mark when chord started

            // stop old synths
            padSynths.do { |s| s.set(\gate, 0) };
			darkPadSynths.do { |s| s.set(\gate, 0) };
            bassSynths.do { |s| s.set(\gate, 0) };
			droneSynths.do { |s| s.set(\gate, 0) };
            padSynths.clear;
			darkPadSynths.clear;
            bassSynths.clear;
			droneSynths.clear;

            // precompute pad params
            padFreqs = {
				var freqs, detune, n, baseVoices, octaveVoices, octaveAmpFactor, voicePairs;
				freqs  = chord.midicps;
				detune = ~getMapped.(\detune);
				n      = ~getMapped.(\numVoices);

				// base voices
				baseVoices = Array.fill(n, { |i|
					freqs + (detune * (i - (n - 1) / 2))
				}).flat;

				// octave voices
				octaveVoices = baseVoices * 2; // shift up an octave

				octaveAmpFactor = ~mapExp.(~parameters[\density], 0, 1, 0.1, 0.3);

				// collect both freq + amp
				voicePairs = baseVoices.collect { |f| [f, 1.0] }
				++ octaveVoices.collect { |f| [f, octaveAmpFactor] };

				// --- Debug ---
				("[DEBUG] chord (MIDI): " ++ chord).postln;
				("[DEBUG] baseVoices sorted: " ++ baseVoices.sort).postln;
				("[DEBUG] octaveVoices sorted: " ++ octaveVoices.sort).postln;
				("[DEBUG] all voicePairs (sorted by freq): " ++ voicePairs.sort { |a, b| a[0] < b[0] }).postln;

				voicePairs
			}.value;

			// Now padPans matches total voices
			padPans = Array.fill(padFreqs.size, { |i|
				(i / (padFreqs.size - 1)) * 2 - 1
			});

            // precompute bass
            bassFreq = ~clampBassRange.(chord[0] - 24).midicps;

            // spawn pad voices
            padFreqs.do { |f, i|
                padSynths.add(Synth(\padSynth, [
                    \freq, f,
                    \pan, padPans[i],
					\legato,  ~getMapped.(\legato),
                    \modRate, ~getMapped.(\modRate),
                    \ffreq,   ~getMapped.(\filterCutoff),
                    \revMix,  ~getMapped.(\revMix) * 0.7,
                    \atk,     ~getMapped.(\atk),
                    \rel,     ~getMapped.(\rel),
                    \rq,      ~getMapped.(\rq),
					\amp,     ~getAmpForVoices.(chord.size),
					\out,     ~padBus
                ]));
            };

			// spawn pad voices
            padFreqs.do { |f, i|
                darkPadSynths.add(Synth(\darkPad, [
                    \freq, f * 0.5, // one octave lower
                    \pan, padPans[i],
					\legato,      ~getMapped.(\legato),
					\darkPadSub,  ~getMapped.(\darkPadSub),
					\distAmt,     ~getMapped.(\distAmt),
					\crushMix,    ~getMapped.(\crushMix),
                    \modRate,     ~getMapped.(\modRate),
					\ffreq,       ~getMapped.(\darkPadCutoff),
					\darkPadBits, ~getMapped.(\darkPadBits),
                    \revMix,      ~getMapped.(\revMix) * 0.7,
                    \atk,         ~getMapped.(\atk),
                    \rel,         ~getMapped.(\rel),
                    \rq,          ~getMapped.(\rq),
                    \amp,         ~getAmpForVoices.(chord.size),
					\out,         ~darkPadBus
                ]));
            };

            // spawn bass voice
            bassSynths.add(Synth(\bassSynth, [
                \freq, bassFreq,
				\legato, ~getMapped.(\legato) * 0.97,
                \ffreq,  ~getMapped.(\filterCutoff),
                \rq,     ~getMapped.(\rq),
                \subOct, ~getMapped.(\sub),
                \drive,  ~getMapped.(\drive),
                \atk,    ~getMapped.(\atk),
                \rel,    ~getMapped.(\rel),
                \amp,    ~getMapped.(\bassAmp),
				\out,    ~bassBus
            ]));

			// spawn drone
			droneSynths.add(Synth(\droneSynth, [
				\freq,        ~getDroneNote.(~droneDegrees.choose, 2).midicps,  // degree, octave shift
				\droneDetune, ~getMapped.(\droneDetune),
				\lfoRate,     ~getMapped.(\droneLfoRate),
				\ffreq,       ~getMapped.(\filterCutoff),
				\rq,          ~getMapped.(\rq),
				\revMix,      ~getMapped.(\revMix) * 1.5,
				\pan,         rrand(-0.5, 0.5),
				\amp,         ~getMapped.(\droneAmp),
				\out,         ~droneBus
			]));

			sp.par(
				Pbind(
					\instrument, \harpPluck,
					\dur, Pseq(durations, 1),
					\freq, Pxrand(chord.midicps, inf),
					\decay, Pwhite(2, 5, inf),
					\pan, Pwhite(-0.6, 0.6, inf),
					\revMix, ~getMapped.(\revMix),
					\amp, ~getMapped.(\harpAmp),
					\out, ~harpBus
				)
			);

			sp.par(
				Pbind(
					\instrument, \glassArp,
					\dur, Pseq(durations, 1),
					\freq, Pxrand(chord.midicps*2, inf),
					\bright, ~getMapped.(\bright),
					\pan, Pwhite(-0.6, 0.6, inf),
					\revMix, ~getMapped.(\revMix) * 1.3,
					\amp, ~getMapped.(\harpAmp),
					\out, ~glassBus
				)
			);

			sp.par(
				Pbind(
					\instrument, \bell,
					\dur, Pseq(Array.fill(4, { dur/4 }), 1),
					\legato, ~getMapped.(\legato) * 0.97,
					\freq, bassFreq * 2,
					\lpfFactor, ~getMapped.(\lpfFactor),
					\revMix, ~getMapped.(\revMix),
					\amp, ~getMapped.(\bellAmp),
					\type, Pseq({
						var decisions = Array.fill(4, { \rest }); // 4 rests
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
					\out, ~bellBus
				)
			);

			// run sea & vinyl in parallel
			sp.par(Pbindf(~seaPattern));

			sp.wait(dur);
        }
    }
).play;
)


// --- Routine to change scales ---

(
Routine({
	var allScales = [
		// --- Heptatonic (7-note) ---
		"ionian", "dorian", "phrygian", "lydian",
		"mixolydian", "aeolian", "locrian",

		// --- Pentatonic (5-note) ---
		"majorPent", "minorPent", "egyptian",

		// --- Hexatonic (6-note) ---
		"wholeTone", "augmented", "tritone",

		// --- Octatonic (8-note) ---
		"dimWH", "dimHW",

		// --- Modal hybrids (7-note) ---
		"lydianDominant", "phrygianDominant",

		// --- Ethereal / world-inspired (5-note mostly) ---
		"hirajoshi", "inSen", "yo", "iwato",

		// --- Exotic / other (7-note) ---
		"persian", "neapolitan", "enigmatic"
	];

	// weights must match array size
	var weights = [
		// Heptatonic
		0.08, 0.08, 0.05, 0.08, 0.05, 0.08, 0.04,

		// Pentatonic (very common in ambient)
		0.08, 0.08, 0.05,

		// Hexatonic (moderately rare)
		0.04, 0.03, 0.03,

		// Octatonic (special flavor)
		0.03, 0.03,

		// Modal hybrids
		0.04, 0.04,

		// Ethereal
		0.06, 0.05, 0.05, 0.05,

		// Exotic
		0.04, 0.03, 0.03
	];

	var waitTime, factors, idx;

	loop {
		~setScale.(allScales.wchoose(weights).asSymbol);

		// wait time in chord cycles
		factors = [32, 24, 16, 12, 8, 6];
		idx = (~parameters[\variability] * 6).floor.clip(0, 5);
		waitTime = factors[idx] * ~getMapped.(\dur);

		("Next wait time: " ++ waitTime).postln; // debug
		waitTime.wait;
	}
}).play;
)



(
// simple test Pbind for darkPad
Pbind(
    \instrument, \darkPad,
    // make a 3-note chord
    \degree, Pseq([
        [0, 4, 7],   // minor triad
        [2, 5, 9],   // another chord
        [4, 7, 11],  // etc.
        [5, 9, 0]    // cycle back
    ], inf),

	\scale, Scale.minor,   // can switch to your ~scalePcs later
	\octave, 5,            // fairly low register
	\dur, Pfunc({ ~getMapped.(\dur)}),
	\legato,      ~getMapped.(\legato),
	\darkPadSub,  ~getMapped.(\darkPadSub),
	\distAmt,     ~getMapped.(\distAmt),
	\crushMix,    ~getMapped.(\crushMix),
	\modRate,     ~getMapped.(\modRate),
	\ffreq,       ~getMapped.(\darkPadCutoff),
	\darkPadBits, ~getMapped.(\darkPadBits),
	\revMix,      ~getMapped.(\revMix) * 0.7,
	\atk,         ~getMapped.(\atk),
	\rel,         ~getMapped.(\rel),
	\rq,          ~getMapped.(\rq),
	\amp,         ~getMapped.(\bassAmp)
).play;
)

(
// simple test Pbind for darkPad
Pbind(
	\instrument, \droneSynth,
	\freq, ~getDroneNote.(~droneDegrees.choose, -1).midicps,  // degree, octave shift
	\droneDetune,  ~getMapped.(\droneDetune),
	\lfoRate, ~getMapped.(\droneLfoRate),
	\ffreq,   ~getMapped.(\filterCutoff),
	\rq,      ~getMapped.(\rq),
	\revMix,  ~getMapped.(\revMix) * 1.2,
	\amp,     ~getMapped.(\droneAmp),
	\pan,     rrand(-0.5, 0.5)
).play;
)

(
// simple test arpeggio for glassArp
Pbind(
    \instrument, \glassArp,

    // arpeggiated chord patterns
    \degree, Pseq([
        [0, 3, 7],   // minor triad
        [2, 5, 9],   // another shape
        [4, 7, 11],  // bright color
        [5, 9, 0]    // cycle back
    ], inf).stutter(4),   // break into arpeggio

    \scale, Scale.minor,   // test in minor scale
    \octave, Pseq([5, 6], inf),  // alternate registers
    \dur, Pwhite(0.25, 0.5, inf),  // shimmering variable rhythm
    \atk, 0.01,
    \rel, Pwhite(2, 5, inf),       // different decay times
    \rq, Pwhite(0.01, 0.1, inf),   // resonance sharpness variation
    \bright, Pwhite(0.5, 1.0, inf), // sparkle amount
    \revMix, 0.7,
    \amp, 0.1,
    \pan, Pwhite(-0.6, 0.6, inf), // stereo movement
	\out, ~glassBus
).play;
)

(
Pbind(
    \instrument, \rainTexture,
    \dur, 100,                 // long event, constant rain
    \dens,  Pseq([200, 400, 600,300], inf),  // drizzle → medium → heavier
    \hp,    300,             // cut low rumble
    \lp,    6000,            // keep highs
    \revMix, 0.3,
	\noiseAmp, 0.5,
    \amp,   0.4
).play;
)

x = Synth(\bassSynth, [\out, 0]); // send straight to hardware output
x.free;
(
x = Synth(\bassSynth, [\out, ~bassBus], target: ~sourcesGroup);
{ In.ar(~masterBus, 2) }.play;
)

(
x = Synth(\padSynth, [\out, ~padBus], target: ~sourcesGroup);
{ In.ar(~masterBus, 2) }.play;
)

(
~testBus = Bus.audio(s, 2);
~bassCtrl = Bus.control(s, 1).set(10);  // full gain

~testFader = Synth(\fader, [\inBus, ~testBus, \outBus, 0, \ctrlBus, ~testCtrl]);

// simple sine feeding into the bus
~src = { Out.ar(~testBus, SinOsc.ar(220, 0, 0.2)) }.play;
)

~padCtrl.set(100);
~padGroupCtrl.set(100);
~masterCtrl.set(1.0); // make sure master is up too

~padCtrl.get({ |v| ("padCtrl = " ++ v).postln; });
~padGroupCtrl.get({ |v| ("padGroupCtrl = " ++ v).postln; });
~masterCtrl.get({ |v| ("masterCtrl = " ++ v).postln; });



// --- Usage & Checks ---

// Define key and scale
~setKey.(\C, 4);
~listScales = { allScales.do(_.postln) };
~setScale.(\dorian);

// Check scale, key and chord
~scalePcs.postln;     // Should be [0,2,4,5,7,9,11] for ionian
~keyMidi.postln;      // Should be 60 (for C4)
~scaleToMidi.().postln;  // should print [60, 62, 64, 65, 67, 69, 71]
~nextDegree.(1).postln;
~chordFromDegree.(1).postln;  // Should return MIDI notes like [60, 64, 67, 71]
~nextChord.().postln;  // -> posts degree and MIDI array
~nextChord.().midicps.postln;

// Warmth: 0 (cold/thin) → 1 (warm/fat)
~setParam.(\warmth, 0.8);

// Brightness: 0 (dark/muffled) → 1 (bright/open)
~setParam.(\brightness, 0.7);

// Density: 0 (few voices/open) → 1 (many voices/clustered)
~setParam.(\density, 0.2);

// Variability: 0 (slow/static) → 1 (fast/changing)
~setParam.(\variability, 0.3);

// Rhythmicity: 0 (smooth/legato) → 1 (tight/rhythmic)
~setParam.(\rhythmicity, 0.7);

// Show parameter settings
~parameters.postln;

// Show mapped values
~showMappedParams.();

// Show server information
s.queryAllNodes;  // shows node tree
s.queryAllBuffers;
SynthDescLib.global.browse; // browse all available defs

// Reset mixer when all buses are used up
~resetMixer.();
s.freeAll;   // frees all synths, groups, and releases buses
s.newBusAllocators; // reset bus allocators


