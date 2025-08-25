(
// --- Start mixing engine (groups + faders) ---

~startMixingEngine = {
	// Groups
	~mixerGroup        = Group.head(s);
	~controlGroup      = Group.after(~mixerGroup);
	~fadersGroup       = Group.after(~controlGroup);
	~groupFadersGroup  = Group.after(~fadersGroup);
	~dryGroup          = Group.after(~groupFadersGroup);
	~sendsGroup        = Group.after(~dryGroup);
	~fxsGroup          = Group.after(~sendsGroup);
	~fxMaster          = Group.after(~fxsGroup);
	~master            = Group.after(~fxMaster);

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

	// FX group fader
	~fxGroupFader    = Synth(\fxGroupFader,[\inBus, ~fxGroup,       \outBus, ~masterBus,     \ctrlBus, ~fxGroupCtrl],    target: ~fxMaster);

	// Master fader
	~masterFader     = Synth(\masterFader, [\inBus, ~masterBus,     \outBus, 0,              \ctrlBus, ~masterCtrl],     target: ~master);
};
)