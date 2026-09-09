import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var playlists: []
    property var allTracks: []
    signal loaded()

    property string buffer: ""

    function reload() {
        buffer = "";
        proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", "-c", "import json, os; p = os.path.expanduser('~/Applications/FrostifyLocal/library.json'); print(json.dumps(json.load(open(p))))"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
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
        }
    }

    Component.onCompleted: reload()
}
