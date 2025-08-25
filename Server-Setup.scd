(
// --- Server Setup ---

// Server options
s.options.numOutputBusChannels = 2;      // stereo out
s.options.numInputBusChannels  = 2;      // stereo in (optional)
s.options.numAudioBusChannels  = 4096;   // number of available audio buses
s.options.numControlBusChannels = 2048;  // number of available control buses

s.options.memSize      = 2 ** 16;        // memory for buffers ca. 256KB
s.options.numBuffers   = 8192;           // sample buffers
s.options.numWireBufs  = 256;            // routing capacity
s.options.maxNodes     = 2 ** 16;        // number of available synths

s.options.blockSize    = 64;             // low latency, raise to 128/256 if CPU chokes
s.options.sampleRate   = -1;             // use system default

// Reboot server
s.reboot;

// Open GUIs
s.waitForBoot({
	~openMonitors = {
		s.meter;
		s.plotTree;
		s.scope;
	};
	~openMonitors.();
	">>> Server booted and monitors opened.".postln
});
)