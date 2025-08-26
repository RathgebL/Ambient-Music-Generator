(
// --- Allocate Buses ---

~allocBuses = {
    if(~busesAllocated.not) {
		var audioNames, controlNames;

        "Allocating buses...".postln;


        // --- Names grouped by type ---
        audioNames = [
            \master,

            \pad, \darkPad, \bass, \drone, \harp, \glass, \bell, \sea, \rain, \vinyl,

            \rev, \comp, \del, \sat,

            \padGroup, \bassGroup, \droneGroup, \bellGroup, \arpGroup, \texGroup, \fxGroup,

            \padDry, \bassDry, \droneDry, \bellDry, \arpDry, \texDry
        ];

        controlNames = [
            \master,

            \pad, \darkPad, \bass, \drone, \bell, \harp, \glass, \sea, \rain, \vinyl,

            \rev, \comp, \del, \sat,

            \padGroup, \bassGroup, \droneGroup, \bellGroup, \arpGroup, \texGroup, \fxGroup,

            \padDry, \bassDry, \droneDry, \bellDry, \arpDry, \texDry
        ];

        // --- Audio buses ---
        audioNames.do { |name|
            var busName = (name.asString ++ "Bus").asSymbol;
            currentEnvironment.put(busName, Bus.audio(s, 2));
        };

        // --- Control buses ---
        controlNames.do { |name|
            var ctrlName = (name.asString ++ "Ctrl").asSymbol;
            var initVal = if(name == \master) { 1 } { 0.5 };
            currentEnvironment.put(ctrlName, Bus.control(s, 1).set(initVal));
        };

        ~busesAllocated = true;
    } {
        "Buses already allocated, skipping.".postln;
    };
};
)