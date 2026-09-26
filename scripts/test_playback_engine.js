// Unit test for components/playback_engine.js using Node.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

// Load playback_engine.js in a mock VM context
const code = fs.readFileSync(__dirname + '/../components/playback_engine.js', 'utf8');
const sandbox = {
    console: console,
    Date: Date,
    Math: Math,
    String: String,
    Array: Array,
    Object: Object,
    JSON: JSON,
    parseInt: parseInt,
    parseFloat: parseFloat,
    I18n: { tr: (vi, en) => vi },
    Quickshell: {
        execDetached: (cmd) => { sandbox.lastExec = cmd; },
        env: (k) => ""
    },
    XMLHttpRequest: function() {
        this.open = () => {};
        this.send = () => {};
    }
};

vm.createContext(sandbox);
vm.runInContext(code, sandbox);

console.log("Testing isSameTrack...");
assert.strictEqual(sandbox.isSameTrack(null, null), false);
assert.strictEqual(sandbox.isSameTrack({ path: "/a.flac" }, { path: "/a.flac" }), true);
assert.strictEqual(sandbox.isSameTrack({ videoId: "abc" }, { path: "ytdl://abc" }), true);
assert.strictEqual(sandbox.isSameTrack({ title: "Song", artist: "Artist" }, { name: "Song", artist: "Artist" }), true);
assert.strictEqual(sandbox.isSameTrack({ title: "Song 1", artist: "Artist" }, { name: "Song 2", artist: "Artist" }), false);
console.log("OK: isSameTrack tests passed.");

console.log("Testing queue operations...");
const mockWin = {
    currentTracks: [],
    currentTrack: null,
    isSameTrack: sandbox.isSameTrack,
    playTrack: (t) => { mockWin.currentTrack = t; },
    playOnlineTrack: (t) => { mockWin.currentTrack = t; },
    playNext: () => {},
    appDir: "/test"
};

// 1. Append
const t1 = { title: "Track 1", artist: "A1", path: "/t1.mp3" };
const t2 = { title: "Track 2", artist: "A2", path: "/t2.mp3" };
const t3 = { title: "Track 3", artist: "A3", path: "/t3.mp3" };

sandbox.appendTrackToQueue(mockWin, t1);
assert.strictEqual(mockWin.currentTracks.length, 1);
assert.strictEqual(mockWin.currentTracks[0].title, "Track 1");

sandbox.appendTrackToQueue(mockWin, t2);
assert.strictEqual(mockWin.currentTracks.length, 2);

// 2. Insert Play Next
mockWin.currentTrack = t1;
sandbox.insertTrackPlayNext(mockWin, t3);
assert.strictEqual(mockWin.currentTracks.length, 3);
assert.strictEqual(mockWin.currentTracks[1].title, "Track 3"); // inserted between t1 and t2

// 3. Remove
sandbox.removeTrackFromQueue(mockWin, t3);
assert.strictEqual(mockWin.currentTracks.length, 2);
assert.strictEqual(mockWin.currentTracks.some(t => t.title === "Track 3"), false);

console.log("OK: Queue operation tests passed.");

console.log("Testing status handling and cold-start recovery...");
const statusPayload = JSON.stringify({
    is_playing: true,
    time_pos: 15.4,
    duration: 210.0,
    filename: "t1.mp3"
});

mockWin.isLoadingAudio = false;
mockWin.isPlaying = false;
mockWin.allTracks = [t1, t2];
mockWin.currentTrack = null;

sandbox.handlePlayerStatus(mockWin, statusPayload, null, null);
assert.strictEqual(mockWin.isPlaying, true);
assert.strictEqual(mockWin.currentTime, 15.4);
assert.strictEqual(mockWin.totalDuration, 210.0);
assert.strictEqual(mockWin.currentTrack.title, "Track 1"); // recovered from filename match

console.log("OK: Status handling & cold-start recovery passed.");
console.log("ALL TESTS COMPLETED SUCCESSFULLY!");
