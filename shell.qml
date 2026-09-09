import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./components"

Scope {
    id: appScope

    FloatingWindow {
        id: win
        title: "Spotify"
        implicitWidth: 1280
        implicitHeight: 820
        color: "transparent"

        property var activeLyrics: amberolView.activeLyrics

    readonly property string appDir: Quickshell.env("HOME") + "/Applications/FrostifyLocal"

    property var playlists: []
    property var allTracks: []
    property var currentTracks: []
    property int selectedPlaylistIndex: 0

    property var currentTrack: null
    property bool isPlaying: false
    property real currentTime: 0.0
    property real totalDuration: 0.0
    property real volume: 100.0

    property bool isShuffle: true
    property bool isRepeat: true
    property bool showAmberolDetails: true

    Shortcut {
        sequence: "F11"
        onActivated: win.fullscreen = !win.fullscreen
    }

    // Master Container with Spotify Dark Aesthetic
    Rectangle {
        anchors.fill: parent
        radius: win.fullscreen ? 0 : Theme.radiusApp
        color: "#000000"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            // Top Spotify Header & Search
            SpotifyHeader {
                id: topHeader
                Layout.fillWidth: true

                onTabSelected: tab => win.filterByTab(tab)
                onSearchRequested: query => win.filterBySearch(query)
            }

            // Main Content Area: Left Sidebar + Right Main Grid (Or Amberol Synced Lyrics View)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                // Left: Your Library
                SpotifySidebar {
                    id: leftSidebar
                    Layout.fillHeight: true
                    playlists: win.playlists
                    selectedIndex: win.selectedPlaylistIndex
                    visible: !win.showAmberolDetails || win.width >= 900
                    Layout.preferredWidth: visible ? 240 : 0

                    onPlaylistSelected: (idx, pl) => {
                        win.selectedPlaylistIndex = idx;
                        win.selectPlaylist(pl.id);
                        win.showAmberolDetails = false;
                    }
                }

                // Right: Dynamic Stack View (Grid or Amberol Details)
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: win.showAmberolDetails ? 1 : 0

                    SpotifyMainGrid {
                        id: mainGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tracks: win.currentTracks
                        currentTrack: win.currentTrack
                        isPlaying: win.isPlaying

                        onTrackPlayRequested: trk => win.playTrack(trk)
                        onTrackDetailsRequested: trk => {
                            win.currentTrack = trk;
                            win.showAmberolDetails = true;
                        }
                    }

                    AmberolDetailView {
                        id: amberolView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        track: win.currentTrack
                        currentTime: win.currentTime
                        isPlaying: win.isPlaying

                        onCloseRequested: win.showAmberolDetails = false
                        onSeekRequested: sec => win.seekAudio(sec)
                    }
                }
            }

            // Bottom Player Bar (Centered layout, Amberol SVGs, 240Hz responsive)
            SpotifyPlayerBar {
                id: bottomPlayer
                Layout.fillWidth: true
                currentTrack: win.currentTrack
                isPlaying: win.isPlaying
                currentTime: win.currentTime
                totalDuration: win.totalDuration
                volume: win.volume
                isShuffle: win.isShuffle
                isRepeat: win.isRepeat
                isLyricsActive: win.showAmberolDetails
                isQueueActive: win.showAmberolDetails

                onPlayPauseClicked: win.togglePlay()
                onNextClicked: win.playNext()
                onPrevClicked: win.playPrev()
                onToggleShuffle: win.isShuffle = !win.isShuffle
                onToggleRepeat: win.isRepeat = !win.isRepeat
                onSeekRequested: sec => win.seekAudio(sec)
                onReqVolumeChange: vol => win.setVolume(vol)
                onOpenDetailsRequested: win.showAmberolDetails = !win.showAmberolDetails
            }
        }
    }

    // Library Data Loader
    LibraryLoader {
        id: libLoader
        onLoaded: {
        console.log("WIN GEOMETRY: win.width =", win.width, "win.height =", win.height, "showAmberolDetails =", win.showAmberolDetails, "currentIndex =", (win.showAmberolDetails ? 1 : 0));

            win.playlists = libLoader.playlists;
            win.allTracks = libLoader.allTracks;
            win.currentTracks = win.allTracks;
            if (!win.currentTrack && win.allTracks.length > 0) {
                // Default to first track
                win.currentTrack = win.allTracks[0];
                win.totalDuration = (win.allTracks[0].durationMs || 0) / 1000.0;
            }
        }
    }

    function selectPlaylist(pid) {
        if (pid === "all") {
            win.currentTracks = win.allTracks;
        } else if (pid === "simp") {
            win.currentTracks = win.allTracks.filter(t => t.source === "SimpMusic");
        } else if (pid === "downloads") {
            win.currentTracks = win.allTracks.filter(t => t.source === "Downloads");
        } else if (pid === "ado") {
            win.currentTracks = win.allTracks.filter(t => (t.artist && t.artist.toLowerCase().includes("ado")) || (t.name && t.name.toLowerCase().includes("ado")));
        }
    }

    function filterByTab(tab) {
        if (tab === "all") {
            win.currentTracks = win.allTracks;
        } else if (tab === "music") {
            win.currentTracks = win.allTracks.filter(t => t.source === "SimpMusic" || t.source === "Downloads");
        } else if (tab === "ado") {
            win.currentTracks = win.allTracks.filter(t => (t.artist && t.artist.toLowerCase().includes("ado")) || (t.name && t.name.toLowerCase().includes("ado")));
        }
    }

    function filterBySearch(q) {
        if (!q || q.trim() === "") {
            win.currentTracks = win.allTracks;
            return;
        }
        var lower = q.toLowerCase();
        win.currentTracks = win.allTracks.filter(t => (t.name && t.name.toLowerCase().includes(lower)) || (t.artist && t.artist.toLowerCase().includes(lower)));
    }

    function playTrack(trk) {
        if (!trk) return;
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.totalDuration = (trk.durationMs || 0) / 1000.0;
        win.isPlaying = true;

        playerCmd.command = ["python3", win.appDir + "/backend/player_daemon.py", "play", trk.path];
        playerCmd.running = true;
    }

    function togglePlay() {
        if (!win.currentTrack && win.currentTracks.length > 0) {
            win.playTrack(win.currentTracks[0]);
            return;
        }
        playerCmd.command = ["python3", win.appDir + "/backend/player_daemon.py", "toggle"];
        playerCmd.running = true;
        win.isPlaying = !win.isPlaying;
    }

    function playNext() {
        if (win.currentTracks.length === 0) return;
        if (win.isShuffle && win.currentTracks.length > 1) {
            var curIdx = win.currentTracks.findIndex(t => win.currentTrack && t.path === win.currentTrack.path);
            var nextIdx = curIdx;
            while (nextIdx === curIdx) {
                nextIdx = Math.floor(Math.random() * win.currentTracks.length);
            }
            win.playTrack(win.currentTracks[nextIdx]);
        } else {
            var curIdx = win.currentTracks.findIndex(t => win.currentTrack && t.path === win.currentTrack.path);
            var nextIdx = (curIdx + 1) % win.currentTracks.length;
            win.playTrack(win.currentTracks[nextIdx]);
        }
    }

    function playPrev() {
        if (win.currentTracks.length === 0) return;
        if (win.currentTime > 3.0) {
            win.seekAudio(0.0);
            return;
        }
        var curIdx = win.currentTracks.findIndex(t => win.currentTrack && t.path === win.currentTrack.path);
        var prevIdx = (curIdx - 1 + win.currentTracks.length) % win.currentTracks.length;
        win.playTrack(win.currentTracks[prevIdx]);
    }

    function seekAudio(sec) {
        win.currentTime = sec;
        playerCmd.command = ["python3", win.appDir + "/backend/player_daemon.py", "seek", String(sec)];
        playerCmd.running = true;
    }

    function setVolume(vol) {
        win.volume = vol;
        playerCmd.command = ["python3", win.appDir + "/backend/player_daemon.py", "volume", String(vol)];
        playerCmd.running = true;
    }

    Process {
        id: playerCmd
    }

    Timer {
        id: pollTimer
        interval: win.isPlaying ? 80 : 400
        running: true
        repeat: true
        onTriggered: {
            if (!statusProcess.running) {
                statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                statusProcess.running = true;
            }
        }
    }

    Process {
        id: statusProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var s = JSON.parse(data);
                    if (s.is_playing !== undefined) win.isPlaying = s.is_playing;
                    if (s.time_pos !== undefined && s.time_pos > 0) win.currentTime = s.time_pos;
                    if (s.duration !== undefined && s.duration > 0) win.totalDuration = s.duration;

                    // Sync track from filename if playing
                    if (s.filename && win.allTracks.length > 0) {
                        if (!win.currentTrack || (win.currentTrack.path && !win.currentTrack.path.endsWith(s.filename))) {
                            var matched = win.allTracks.find(t => t.path && t.path.endsWith(s.filename));
                            if (matched) win.currentTrack = matched;
                        }
                    }

                    // Auto-advance or Repeat at song end
                    if (win.totalDuration > 3 && win.currentTime >= win.totalDuration - 0.4) {
                        if (win.isRepeat) {
                            win.seekAudio(0.0);
                        } else {
                            win.playNext();
                        }
                    }
                } catch(e) {}
            }
        }
    }
    } // end win (FloatingWindow)

    // =========================================================================
    // Magical Harry Potter Desktop Lyrics Widget on Maid Skirt (Layer Bottom)
    // =========================================================================
    DesktopLyricsWidget {
        id: desktopLyrics
        activeLyrics: win.activeLyrics
        currentTime: win.currentTime
        isPlaying: win.isPlaying
        currentTrack: win.currentTrack
        enabled: true
    }
} // end appScope

