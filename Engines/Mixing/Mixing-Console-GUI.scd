(
// --- Make Mixing Console GUI (sliders only) ---

~makeMixerGUI = {
	var win, slotWidth, padding, winWidth, nInstruments, rowIndices, channels, colInstrument, colGroup, colFX, colFxMaster, colMaster;

	// Colors
	colInstrument = Color(0.9, 0.9, 0.9);  // light grey
	colGroup      = Color(0.7, 0.9, 0.7);  // greenish
	colFX         = Color(0.7, 0.7, 0.9);  // bluish
	colFxMaster   = Color(0.6, 0.8, 0.9);  // light blue
	colMaster     = Color(1, 0.6, 0.2);    // orange

	// Channel definitions (map to control buses)
	~channels = channels = [
		// Instruments
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

		// Groups
		(name: \PadGroup,    color: colGroup,      type: \group,      ctrlBus: ~padGroupCtrl),
		(name: \BassGroup,   color: colGroup,      type: \group,      ctrlBus: ~bassGroupCtrl),
		(name: \DroneGroup,  color: colGroup,      type: \group,      ctrlBus: ~droneGroupCtrl),
		(name: \BellGroup,   color: colGroup,      type: \group,      ctrlBus: ~bellGroupCtrl),
		(name: \ArpGroup,    color: colGroup,      type: \group,      ctrlBus: ~arpGroupCtrl),
		(name: \TexGroup,    color: colGroup,      type: \group,      ctrlBus: ~texGroupCtrl),

		// FX
		(name: \ReverbFX,    color: colFX,         type: \fx,         ctrlBus: ~revCtrl),
		(name: \CompFX,      color: colFX,         type: \fx,         ctrlBus: ~compCtrl),
		(name: \DelayFX,     color: colFX,         type: \fx,         ctrlBus: ~delCtrl),
		(name: \SaturatorFX, color: colFX,         type: \fx,         ctrlBus: ~satCtrl),

		// Master
		(name: \FXMaster,    color: colFxMaster,   type: \fx,         ctrlBus: ~fxGroupCtrl),
		(name: \Master,      color: colMaster,     type: \master,     ctrlBus: ~masterCtrl)
	];

	// Create window
	slotWidth = 100;
	padding   = 35;
	nInstruments = channels.count { |c| c[\type] == \instrument };
	winWidth  = (nInstruments * slotWidth) + padding;
	win = Window("AMBIENT MUSIC GENERATOR Mixer", Rect(50, 50, winWidth, 820)).front;

	// Track row indices for x positioning
	rowIndices = IdentityDictionary[
		\instrument -> 0,
		\group      -> 0,
		\fx         -> 0
	];

	// Build channels (sliders + labels only)
	channels.do { |c, i|
		var name = c[\name], color = c[\color], type = c[\type], ctrlBus = c[\ctrlBus];
		var slider, label, yOffset, xOffset;

		// row-specific yOffset
		yOffset = switch(type,
			\instrument, { 50 },
			\group,      { 300 },
			\fx,         { 550 },
			\master,     { 550 },
			{ 50 }
		);

		// row-specific xOffset
		if(type == \master) {
			xOffset = rowIndices[\fx] * 100 + 50;
		} {
			xOffset = rowIndices[type] * 100 + 50;
			rowIndices[type] = rowIndices[type] + 1;
		};

		// Slider
		slider = Slider(win, Rect(xOffset, yOffset, 30, 150))
			.background_(color)
			.value_(ctrlBus.getSynchronous)
			.action_({ |sl| ctrlBus.set(sl.value) });

		// Label
		label = StaticText(win, Rect(xOffset - 10, yOffset + 160, 70, 20))
			.align_(\center)
			.string_(name.asString);

		// Store refs
		channels[i][\slider] = slider;
	};

	// Updater: refresh sliders from control buses
	if(~guiUpdater.notNil and: { ~guiUpdater.isPlaying }) {
		~guiUpdater.stop;
	};

	win // Return win to be able to close it automatically
};

// --- GUI Updater ---
~startGuiUpdater = {
	if(~guiUpdater.notNil and: { ~guiUpdater.isPlaying }) {
		~guiUpdater.stop;
	};

	~guiUpdater = Routine({
		loop {
			var channels = ~channels;
			channels.do { |c|
				if(c[\ctrlBus].notNil and: { c[\slider].notNil }) {
					c[\ctrlBus].get { |val|
						{
							if(c[\slider].notNil) {
								var oldAction = c[\slider].action;
								c[\slider].action = nil;
								c[\slider].value = val;
								c[\slider].action = oldAction;
							};
						}.defer;
					};
				};
			};
			0.1.wait;
		};
	}).play(AppClock);

	"[GUIUpdater] started".postln;
};
)