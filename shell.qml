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
        visible: true

        onClosed: {
            win.visible = false;
        }

        onVisibleChanged: {
            if (win.visible) {
                if (!statusProcess.running) {
                    statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                    statusProcess.running = true;
                }
                Qt.callLater(function() { amberolView.updateActiveLyric(true); });
            }
        }

        property var activeLyrics: amberolView.activeLyrics

    readonly property string appDir: Quickshell.env("HOME") + "/Applications/FrostifyLocal"

    property string currentView: "home" // "home" or "library"
    property var homeMoods: []
    property string selectedMood: "All"
    property var homeQuickPicks: []
    property var homeFeaturedPlaylists: []
    property bool isLoadingHome: false

    property bool isAuthLoggedIn: false
    property string authAccountName: ""
    property string authAccountThumb: ""

    property var playlists: []
    property var allTracks: []
    property var currentTracks: []
    property int selectedPlaylistIndex: 0
    property string currentTab: "all"
    property var ytMusicTracks: []
    property bool isSearchingYT: false
    property string lastYTQuery: ""

    Timer {
        id: ytSearchDebounce
        interval: 500
        repeat: false
        onTriggered: {
            if (win.currentTab === "ytmusic") {
                win.performYTSearch(win.lastYTQuery);
            }
        }
    }

    Process {
        id: ytSearchProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr)) {
                        win.ytMusicTracks = arr;
                        if (win.currentTab === "ytmusic") {
                            win.currentTracks = arr;
                        }
                    }
                } catch(e) {
                    console.log("ytSearchProc error:", e);
                } finally {
                    win.isSearchingYT = false;
                }
            }
        }
        onExited: {
            win.isSearchingYT = false;
        }
    }

    function performYTSearch(q) {
        win.isSearchingYT = true;
        ytSearchProc.running = false;
        ytSearchProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "search", q ? q : "Trending"];
        ytSearchProc.running = true;
    }

    Process {
        id: homeProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res.moods && Array.isArray(res.moods)) win.homeMoods = res.moods;
                    if (res.quick_picks && Array.isArray(res.quick_picks)) win.homeQuickPicks = res.quick_picks;
                    if (res.featured_playlists && Array.isArray(res.featured_playlists)) win.homeFeaturedPlaylists = res.featured_playlists;
                } catch(e) {
                    console.log("homeProc parse error:", e);
                } finally {
                    win.isLoadingHome = false;
                }
            }
        }
        onExited: {
            win.isLoadingHome = false;
        }
    }

    Process {
        id: moodProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res.quick_picks && Array.isArray(res.quick_picks)) win.homeQuickPicks = res.quick_picks;
                    if (res.featured_playlists && Array.isArray(res.featured_playlists)) win.homeFeaturedPlaylists = res.featured_playlists;
                    else if (Array.isArray(res)) win.homeFeaturedPlaylists = res;
                } catch(e) {
                    console.log("moodProc error:", e);
                } finally {
                    win.isLoadingHome = false;
                }
            }
        }
        onExited: {
            win.isLoadingHome = false;
        }
    }

    Process {
        id: radioProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr) && arr.length > 0) {
                        win.currentTracks = arr;
                    }
                } catch(e) {
                    console.log("radioProc error:", e);
                }
            }
        }
    }

    Process {
        id: playlistTracksProc
        property string targetTitle: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr) && arr.length > 0) {
                        win.currentTracks = arr;
                        win.currentView = "library";
                        mainGrid.sectionTitle = playlistTracksProc.targetTitle;
                    }
                } catch(e) {
                    console.log("playlistTracksProc error:", e);
                } finally {
                    win.isSearchingYT = false;
                }
            }
        }
        onExited: {
            win.isSearchingYT = false;
        }
    }

    Process {
        id: authStatusProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var s = JSON.parse(data);
                    win.isAuthLoggedIn = !!s.logged_in;
                    win.authAccountName = s.name || "";
                    win.authAccountThumb = s.thumb || "";
                } catch(e) {}
            }
        }
    }

    Process {
        id: saveAuthProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res.success) {
                        settingsModal.statusMessage = "Connected as " + (res.name || "Google User") + "!";
                        win.checkAuthStatus();
                        win.loadHomeFeed();
                    } else {
                        settingsModal.statusMessage = "Error: " + (res.error || "Failed to parse credentials");
                    }
                } catch(e) {
                    settingsModal.statusMessage = "Error: Invalid response";
                } finally {
                    settingsModal.isProcessing = false;
                }
            }
        }
        onExited: {
            settingsModal.isProcessing = false;
        }
    }

    Process {
        id: logoutProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                settingsModal.statusMessage = "Logged out successfully.";
                settingsModal.isProcessing = false;
                win.checkAuthStatus();
                win.loadHomeFeed();
            }
        }
        onExited: {
            settingsModal.isProcessing = false;
        }
    }

    function loadHomeFeed() {
        win.isLoadingHome = true;
        homeProc.running = false;
        homeProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "home"];
        homeProc.running = true;
    }

    function selectMood(title, params) {
        win.selectedMood = title;
        if (title === "All" || !params) {
            win.loadHomeFeed();
            return;
        }
        win.isLoadingHome = true;
        moodProc.running = false;
        moodProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "mood", params];
        moodProc.running = true;
    }

    function playOnlineTrack(trk) {
        if (!trk) return;
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.totalDuration = (trk.durationMs || 0) / 1000.0;
        win.isPlaying = true;
        win.showAmberolDetails = true;

        if (!win.currentTracks || win.currentTracks.length === 0) {
            win.currentTracks = [trk];
        }

        var streamPath = trk.path || ("ytdl://" + trk.videoId);
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "play", streamPath]);

        if (trk.videoId) {
            radioProc.running = false;
            radioProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "radio", trk.videoId];
            radioProc.running = true;
        }
        pollTimer.restart();
    }

    function loadPlaylistTracks(pl) {
        if (!pl || !pl.playlistId) return;
        win.currentView = "library";
        mainGrid.sectionTitle = pl.title || "Playlist";
        win.isSearchingYT = true;
        playlistTracksProc.running = false;
        playlistTracksProc.targetTitle = pl.title || "Playlist";
        playlistTracksProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "playlist", pl.playlistId];
        playlistTracksProc.running = true;
    }

    function checkAuthStatus() {
        authStatusProc.running = false;
        authStatusProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "auth_status"];
        authStatusProc.running = true;
    }

    property var currentTrack: null
    property bool isPlaying: false
    property real currentTime: 0.0
    property real totalDuration: 0.0
    property real volume: 100.0

    property bool isShuffle: false
    property bool isRepeat: false
    property bool showAmberolDetails: false

    Shortcut {
        sequence: "F11"
        onActivated: win.fullscreen = !win.fullscreen
    }

    Component.onCompleted: {
        win.loadHomeFeed();
        win.checkAuthStatus();
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
                currentTab: win.currentTab
                currentView: win.currentView

                onTabSelected: tab => win.filterByTab(tab)
                onSearchRequested: query => win.filterBySearch(query)
            }

            // Main Content Area: 3-Column Desktop Layout (SimpMusic Optimized)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                // Column 1: Left Navigation Sidebar
                SpotifySidebar {
                    id: leftSidebar
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: visible ? 240 : 0
                    Layout.maximumWidth: visible ? 240 : 0
                    Layout.minimumWidth: visible ? 240 : 0
                    playlists: win.playlists
                    selectedIndex: win.selectedPlaylistIndex
                    currentView: win.currentView
                    visible: !win.showAmberolDetails || win.width >= 900

                    onHomeSelected: {
                        win.currentView = "home";
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                    onLibrarySelected: {
                        win.currentView = "library";
                        win.currentTracks = win.allTracks;
                        mainGrid.sectionTitle = "Downloads (Local)";
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                    onSettingsRequested: {
                        settingsModal.visible = true;
                    }
                    onPlaylistSelected: (idx, pl) => {
                        win.currentView = "library";
                        win.selectedPlaylistIndex = idx;
                        win.selectPlaylist(pl.id);
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                }

                // Column 2: Center Main Content (Home Feed or Local Library)
                StackLayout {
                    id: centerStack
                    visible: !win.showAmberolDetails || win.width >= 1020
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 400
                    currentIndex: win.currentView === "home" ? 0 : 1

                    HomeFeedView {
                        id: homeView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        moods: win.homeMoods
                        selectedMood: win.selectedMood
                        quickPicks: win.homeQuickPicks
                        featuredPlaylists: win.homeFeaturedPlaylists
                        isLoading: win.isLoadingHome
                        currentTrack: win.currentTrack
                        isPlaying: win.isPlaying

                        onMoodSelected: (title, params) => win.selectMood(title, params)
                        onTrackPlayRequested: trk => win.playOnlineTrack(trk)
                        onPlaylistSelected: pl => win.loadPlaylistTracks(pl)
                    }

                    SpotifyMainGrid {
                        id: mainGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tracks: win.currentTracks
                        currentTrack: win.currentTrack
                        isPlaying: win.isPlaying
                        sectionTitle: win.currentTab === "ytmusic" ? "YouTube Music (Online)" : "Downloads & Local Library"
                        isLoading: win.isSearchingYT

                        onTrackPlayRequested: trk => {
                            if (trk && trk.path && trk.path.startsWith("ytdl://")) {
                                win.playOnlineTrack(trk);
                            } else {
                                win.playTrack(trk);
                            }
                        }
                        onTrackDetailsRequested: trk => {
                            win.currentTrack = trk;
                            win.showAmberolDetails = true;
                        }
                    }
                }

                // Column 3: Amberol Detail View (Right Collapsible Panel)
                AmberolDetailView {
                    id: amberolView
                    visible: win.showAmberolDetails
                    Layout.fillHeight: true
                    Layout.fillWidth: win.width < 1020
                    Layout.preferredWidth: win.width >= 1020 ? 360 : -1
                    Layout.maximumWidth: win.width >= 1020 ? 380 : -1
                    Layout.minimumWidth: win.width >= 1020 ? 320 : -1
                    track: win.currentTrack
                    currentTime: win.currentTime
                    isPlaying: win.isPlaying

                    onCloseRequested: win.showAmberolDetails = false
                    onSeekRequested: sec => win.seekAudio(sec)
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
                onToggleShuffle: {
                    win.isShuffle = !win.isShuffle;
                    win.saveSettings();
                }
                onToggleRepeat: {
                    win.isRepeat = !win.isRepeat;
                    win.saveSettings();
                }
                onSeekRequested: sec => win.seekAudio(sec)
                onReqVolumeChange: vol => win.setVolume(vol)
                onOpenDetailsRequested: win.showAmberolDetails = !win.showAmberolDetails
            }
        }

        // YouTube Music Settings / Google Account Modal
        SettingsModal {
            id: settingsModal
            isLoggedIn: win.isAuthLoggedIn
            accountName: win.authAccountName
            accountThumb: win.authAccountThumb

            onCloseRequested: settingsModal.visible = false
            onConnectRequested: rawAuth => {
                settingsModal.isProcessing = true;
                settingsModal.statusMessage = "Connecting and validating credentials...";
                saveAuthProc.running = false;
                saveAuthProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "save_auth", rawAuth];
                saveAuthProc.running = true;
            }
            onLogoutRequested: {
                settingsModal.isProcessing = true;
                settingsModal.statusMessage = "Logging out...";
                logoutProc.running = false;
                logoutProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "logout"];
                logoutProc.running = true;
            }
        }
    }

    Timer {
        id: delayedSettingsRead
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            win.loadSettings();
        }
    }

    FileView {
        id: settingsFileView
        path: Quickshell.env("HOME") + "/.config/noctalia/frostify_settings.json"
        watchChanges: true
        onFileChanged: {
            reload();
            delayedSettingsRead.restart();
        }
        onLoadedChanged: {
            if (loaded) win.loadSettings();
        }
        Component.onCompleted: {
            if (loaded) win.loadSettings();
        }
    }

    function loadSettings() {
        var raw = settingsFileView.text();
        if (!raw || raw.trim() === "") return;
        try {
            var obj = JSON.parse(raw);
            if (obj.isShuffle !== undefined) win.isShuffle = !!obj.isShuffle;
            if (obj.isRepeat !== undefined) win.isRepeat = !!obj.isRepeat;
            console.log("DEBUG Frostify settings loaded: isShuffle=" + win.isShuffle + ", isRepeat=" + win.isRepeat);
        } catch(e) {}
    }

    function saveSettings() {
        var data = JSON.stringify({
            isShuffle: win.isShuffle,
            isRepeat: win.isRepeat
        });
        Quickshell.execDetached(["python3", "-c",
            "import sys, os\np = os.path.expanduser('~/.config/noctalia/frostify_settings.json')\nos.makedirs(os.path.dirname(p), exist_ok=True)\nwith open(p, 'w', encoding='utf-8') as f: f.write(sys.argv[1])",
            data
        ]);
    }

    FileView {
        id: authChangeFileView
        path: "/tmp/frostify_auth_changed"
        watchChanges: true
        onFileChanged: {
            reload();
            win.checkAuthStatus();
            win.loadHomeFeed();
        }
    }

    FileView {
        id: sessionFileView
        path: "/tmp/frostify_current_track.json"
        watchChanges: true
        onFileChanged: {
            reload();
            try {
                var raw = text();
                if (!raw || raw.trim() === "") return;
                var meta = JSON.parse(raw);
                if (meta && meta.title) {
                    if (!win.currentTrack || win.currentTrack.name !== meta.title) {
                        win.currentTrack = {
                            name: meta.title,
                            title: meta.title,
                            artist: meta.artist || "Unknown Artist",
                            image: meta.artUrl || "",
                            path: meta.path || ""
                        };
                    }
                }
            } catch(e) {}
        }
    }

    // Library Data Loader
    LibraryLoader {
        id: libLoader
        onLoaded: {
            win.playlists = libLoader.playlists;
            win.allTracks = libLoader.allTracks;
            win.currentTracks = win.allTracks;

            var restored = false;
            if (sessionFileView.text()) {
                try {
                    var sData = JSON.parse(sessionFileView.text());
                    if (sData.path) {
                        var found = win.allTracks.find(t => t.path === sData.path || (t.filename && sData.path.endsWith(t.filename)));
                        if (found) {
                            win.currentTrack = found;
                            win.totalDuration = (found.durationMs || 0) / 1000.0;
                            restored = true;
                        }
                    }
                } catch(e) {}
            }

            if (!statusProcess.running) {
                statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                statusProcess.running = true;
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
        win.currentTab = tab;
        win.showAmberolDetails = false;
        if (tab === "all") {
            win.currentTracks = win.allTracks;
        } else if (tab === "music") {
            win.currentTracks = win.allTracks.filter(t => t.source === "SimpMusic" || t.source === "Downloads");
        } else if (tab === "ado") {
            win.currentTracks = win.allTracks.filter(t => (t.artist && t.artist.toLowerCase().includes("ado")) || (t.name && t.name.toLowerCase().includes("ado")));
        } else if (tab === "ytmusic") {
            if (win.ytMusicTracks.length > 0) {
                win.currentTracks = win.ytMusicTracks;
            } else {
                win.performYTSearch("Trending");
            }
        }
    }

    function filterBySearch(q) {
        if (q && q.trim() !== "") {
            win.currentView = "library";
            win.showAmberolDetails = false;
            mainGrid.sectionTitle = 'Search: "' + q + '"';
        } else {
            mainGrid.sectionTitle = win.currentTab === "ytmusic" ? "YouTube Music (Online)" : "Downloads & Local Library";
        }
        if (win.currentTab === "ytmusic") {
            win.lastYTQuery = q;
            ytSearchDebounce.restart();
            return;
        }
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

        var curIdx = win.currentTracks.findIndex(t => t.path === trk.path);
        if (curIdx < 0) curIdx = 0;

        var paths = [];
        for (var i = 0; i < win.currentTracks.length; i++) {
            if (win.currentTracks[i] && win.currentTracks[i].path) {
                paths.push(win.currentTracks[i].path);
            }
        }
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "set_playlist", String(curIdx), JSON.stringify(paths)]);
        pollTimer.restart();
    }

    function togglePlay() {
        if (!win.currentTrack && win.currentTracks.length > 0) {
            win.playTrack(win.currentTracks[0]);
            return;
        }
        if (!win.currentTrack) return;
        var targetPath = win.currentTrack.path || "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "toggle", targetPath]);
        win.isPlaying = !win.isPlaying;
        pollTimer.restart();
    }

    function playNext() {
        if (win.currentTracks.length === 0) return;
        var curIdx = win.currentTracks.findIndex(t => win.currentTrack && (t.path === win.currentTrack.path || (t.videoId && win.currentTrack.videoId === t.videoId)));
        var nextIdx = 0;
        if (win.isShuffle && win.currentTracks.length > 1) {
            nextIdx = curIdx;
            while (nextIdx === curIdx) {
                nextIdx = Math.floor(Math.random() * win.currentTracks.length);
            }
        } else {
            nextIdx = (curIdx + 1) % win.currentTracks.length;
        }
        var nextTrk = win.currentTracks[nextIdx];
        if (nextTrk.path && nextTrk.path.startsWith("ytdl://")) {
            win.playOnlineTrack(nextTrk);
        } else {
            win.playTrack(nextTrk);
        }
    }

    function playPrev() {
        if (win.currentTracks.length === 0) return;
        if (win.currentTime > 3.0) {
            win.seekAudio(0.0);
            return;
        }
        var curIdx = win.currentTracks.findIndex(t => win.currentTrack && (t.path === win.currentTrack.path || (t.videoId && win.currentTrack.videoId === t.videoId)));
        var prevIdx = (curIdx - 1 + win.currentTracks.length) % win.currentTracks.length;
        var prevTrk = win.currentTracks[prevIdx];
        if (prevTrk.path && prevTrk.path.startsWith("ytdl://")) {
            win.playOnlineTrack(prevTrk);
        } else {
            win.playTrack(prevTrk);
        }
    }

    function seekAudio(sec) {
        win.currentTime = sec;
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "seek", String(sec)]);
    }

    function setVolume(vol) {
        win.volume = vol;
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "volume", String(vol)]);
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

    IpcHandler {
        target: "frostify"
        function openWindow() {
            win.visible = true;
            if (!statusProcess.running) {
                statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                statusProcess.running = true;
            }
            Qt.callLater(function() { amberolView.updateActiveLyric(true); });
        }
        function closeWindow() {
            win.visible = false;
        }
        function toggle() {
            win.visible = !win.visible;
            if (win.visible) {
                if (!statusProcess.running) {
                    statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                    statusProcess.running = true;
                }
                Qt.callLater(function() { amberolView.updateActiveLyric(true); });
            }
        }
        function toggleDetails() {
            win.showAmberolDetails = !win.showAmberolDetails;
        }
        function openSettings() {
            settingsModal.visible = true;
        }
        function closeSettings() {
            settingsModal.visible = false;
        }
        function showLibrary() {
            win.currentView = "library";
            win.currentTracks = win.allTracks;
            mainGrid.sectionTitle = "Downloads (Local)";
        }
        function showHome() {
            win.currentView = "home";
        }
        function selectMood(title: string, params: string) {
            win.selectMood(title, params);
        }
    }

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

