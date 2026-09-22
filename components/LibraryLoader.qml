import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string libraryPath: (typeof win !== "undefined" && win.appDir)
        ? (win.appDir + "/library.json")
        : ((Quickshell.env("NUTSTY_APP_DIR") || (Quickshell.env("HOME") + "/Applications/FrostifyLocal")) + "/library.json")

    property var playlists: []
    property var allTracks: []
    signal loaded()

    FileView {
        id: libFileView
        path: root.libraryPath
        onLoadedChanged: {
            if (loaded) root.parseLibrary();
        }
    }

    function reload() {
        libFileView.reload();
        root.parseLibrary();
    }

    function parseLibrary() {
        var raw = libFileView.text();
        if (!raw || raw.trim() === "") return;
        try {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                root.allTracks = parsed;
            } else if (parsed && typeof parsed === "object") {
                if (parsed.playlists) root.playlists = parsed.playlists;
                if (parsed.tracks) root.allTracks = parsed.tracks;
            }
            console.log("LibraryLoader successfully loaded tracks count:", root.allTracks.length);
            root.loaded();
        } catch(e) {
            console.log("Failed to parse library:", e);
        }
    }

    Component.onCompleted: {
        root.parseLibrary();
    }
}
