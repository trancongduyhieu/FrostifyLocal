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

    property string currentView: "home" // "home", "library", "playlist", "search"
    property string previousView: "home"
    property var homeMoods: []
    property string selectedMood: "All"
    property var homeSections: []
    property var homeQuickPicks: []
    property var homeFeaturedPlaylists: []
    property bool isLoadingHome: false
    property string activePlaylistId: ""
    property string playingPlaylistId: ""
    property bool isLoadingAudio: false

    property real trackChangeTimestamp: 0
    property var moodCache: ({})
    property string pendingSearchQuery: ""
    property string pendingSearchMode: "online"

    property bool isAuthLoggedIn: false
    property string authAccountName: ""
    property string authAccountThumb: ""
    property bool syncHistoryToGoogle: true
    property bool showSidebar: true
    readonly property bool isContextMenuActive: trackContextMenu.isOpen || trackContextMenu.closingGuard

    property var playlists: []
    property var customPlaylists: []
    property var allTracks: []
    property var currentTracks: []
    property var browsingTracks: []
    property int selectedPlaylistIndex: 0
    property string currentTab: "all"
    property var ytMusicTracks: []
    property bool isSearchingYT: false
    property string lastYTQuery: ""
    property string mainSectionTitle: "Downloads"

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

    Timer {
        id: suggestionsDebounce
        interval: 200
        repeat: false
        onTriggered: {
            if (win.pendingSearchMode === "online") {
                win.fetchSearchSuggestions(win.pendingSearchQuery);
            } else {
                win.filterLocalSuggestions(win.pendingSearchQuery);
            }
        }
    }

    Process {
        id: searchSuggestionsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr)) {
                        topHeader.suggestions = arr;
                    }
                } catch(e) {}
            }
        }
    }

    function fetchSearchSuggestions(q) {
        if (!q || q.trim() === "") {
            topHeader.suggestions = [];
            return;
        }
        searchSuggestionsProc.running = false;
        searchSuggestionsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "suggestions", q.trim()];
        searchSuggestionsProc.running = true;
    }

    function filterLocalSuggestions(q) {
        if (!q || q.trim() === "") {
            topHeader.suggestions = [];
            return;
        }
        var lower = q.toLowerCase();
        var matches = [];
        for (var i = 0; i < win.allTracks.length; i++) {
            var t = win.allTracks[i];
            var name = t.name || t.title || "";
            if (name.toLowerCase().includes(lower) && matches.indexOf(name) === -1) {
                matches.push(name);
                if (matches.length >= 8) break;
            }
        }
        topHeader.suggestions = matches;
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
                        win.browsingTracks = arr;
                        win.currentView = "search";
                        mainGrid.sectionTitle = 'Results for "' + (win.lastYTQuery || "Search") + '"';
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
        if (win.currentView !== "search" && win.currentView !== "playlist") {
            win.previousView = win.currentView;
        }
        win.currentView = "search";
        win.lastYTQuery = q || "Trending";
        mainGrid.sectionTitle = 'Results for "' + win.lastYTQuery + '"';
        ytSearchProc.running = false;
        ytSearchProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "search", win.lastYTQuery];
        ytSearchProc.running = true;
    }

    function filterLocalSearch(q) {
        win.currentView = "library";
        if (!q || q.trim() === "") {
            mainGrid.sectionTitle = "Downloads & Local Library";
            win.browsingTracks = win.allTracks;
            return;
        }
        mainGrid.sectionTitle = 'Local Search: "' + q + '"';
        var lower = q.toLowerCase();
        win.browsingTracks = win.allTracks.filter(t => (t.name && t.name.toLowerCase().includes(lower)) || (t.artist && t.artist.toLowerCase().includes(lower)));
    }

    Process {
        id: homeProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res.moods && Array.isArray(res.moods)) win.homeMoods = res.moods;
                    if (res.sections && Array.isArray(res.sections)) win.homeSections = res.sections;
                    if (res.quick_picks && Array.isArray(res.quick_picks)) win.homeQuickPicks = res.quick_picks;
                    if (res.featured_playlists && Array.isArray(res.featured_playlists)) win.homeFeaturedPlaylists = res.featured_playlists;
                    win.moodCache["All"] = {
                        sections: win.homeSections,
                        quick_picks: win.homeQuickPicks,
                        featured_playlists: win.homeFeaturedPlaylists
                    };
                    if (res.preloaded_moods) {
                        for (var m in res.preloaded_moods) {
                            win.moodCache[m] = res.preloaded_moods[m];
                        }
                    }
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
                    var qp = (res.quick_picks && Array.isArray(res.quick_picks)) ? res.quick_picks : [];
                    var fp = (res.featured_playlists && Array.isArray(res.featured_playlists)) ? res.featured_playlists : (Array.isArray(res) ? res : []);
                    var sec = (res.sections && Array.isArray(res.sections)) ? res.sections : [];
                    win.moodCache[win.selectedMood] = {
                        sections: sec,
                        quick_picks: qp,
                        featured_playlists: fp
                    };
                    win.homeSections = sec;
                    win.homeQuickPicks = qp;
                    win.homeFeaturedPlaylists = fp;
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
                        var userQueued = [];
                        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
                        if (curIdx >= 0 && curIdx < win.currentTracks.length - 1) {
                            userQueued = win.currentTracks.slice(curIdx + 1);
                        }
                        var filteredRadio = arr.filter(rt => !win.isSameTrack(rt, win.currentTrack) && !userQueued.some(uq => win.isSameTrack(uq, rt)));
                        var base = win.currentTrack ? [win.currentTrack] : [];
                        win.currentTracks = base.concat(userQueued).concat(filteredRadio);
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
                        win.browsingTracks = arr;
                        win.currentView = "playlist";
                        win.mainSectionTitle = playlistTracksProc.targetTitle;
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

    Process {
        id: browserLoginProc
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
                        settingsModal.statusMessage = "Login: " + (res.error || "Failed");
                    }
                } catch(e) {
                    settingsModal.statusMessage = "Error: " + e;
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
        id: playbackTrackingProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res && res.success) {
                        win.onPlaybackTracked(res);
                    }
                } catch(e) {}
            }
        }
    }

    function trackPlayback(trk) {
        if (!win.syncHistoryToGoogle || !trk) return;
        var vid = trk.videoId || trk.path || "";
        var title = trk.title || trk.name || "";
        var artist = trk.artist || "";
        playbackTrackingProc.running = false;
        playbackTrackingProc.command = [
            "python3", "-u", win.appDir + "/backend/ytmusic_helper.py",
            "track_playback", vid, title, artist
        ];
        playbackTrackingProc.running = true;
    }

    function onPlaybackTracked(res) {
        if (!win.homeSections || win.homeSections.length === 0) return;
        var firstSec = win.homeSections[0];
        if (firstSec && firstSec.title && firstSec.title.toLowerCase().includes("listen again") && Array.isArray(firstSec.items)) {
            var items = firstSec.items.slice();
            items = items.filter(it => (it.videoId && it.videoId !== res.videoId) || (it.title !== res.title));
            var newTrackItem = {
                title: res.title || (win.currentTrack ? (win.currentTrack.title || win.currentTrack.name) : "Track"),
                name: res.title || (win.currentTrack ? (win.currentTrack.title || win.currentTrack.name) : "Track"),
                artist: res.artist || (win.currentTrack ? win.currentTrack.artist : "Artist"),
                videoId: res.videoId,
                path: "ytdl://" + res.videoId,
                image: win.currentTrack ? (win.currentTrack.image || "") : "",
                type: "track"
            };
            items.unshift(newTrackItem);
            firstSec.items = items;
            var updated = win.homeSections.slice();
            updated[0] = firstSec;
            win.homeSections = updated;
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
        if (win.moodCache[title]) {
            var cachedData = win.moodCache[title];
            win.homeSections = cachedData.sections || [];
            win.homeQuickPicks = cachedData.quick_picks || [];
            win.homeFeaturedPlaylists = cachedData.featured_playlists || [];
            win.isLoadingHome = false;
            return;
        }
        win.homeSections = [];
        if (title === "All" || !params) {
            win.loadHomeFeed();
            return;
        }
        win.isLoadingHome = true;
        moodProc.running = false;
        moodProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "mood", params, title];
        moodProc.running = true;
    }

    function isSameTrack(a, b) {
        if (!a || !b) return false;
        if (a.path && b.path && a.path === b.path) return true;
        var vidA = a.videoId || (a.path && a.path.startsWith("ytdl://") ? a.path.replace("ytdl://", "") : "");
        var vidB = b.videoId || (b.path && b.path.startsWith("ytdl://") ? b.path.replace("ytdl://", "") : "");
        if (vidA && vidB && vidA === vidB) return true;
        var nameA = a.title || a.name || "";
        var nameB = b.title || b.name || "";
        if (nameA && nameB && nameA === nameB && a.artist && b.artist && a.artist === b.artist) return true;
        return false;
    }

    function playOnlineTrack(trk, startRadio) {
        if (!trk) return;
        if (startRadio === undefined) startRadio = false;
        win.trackChangeTimestamp = Date.now();
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.isLoadingAudio = true;
        win.totalDuration = 0.0;
        win.isPlaying = true;
        win.showAmberolDetails = true;

        if (win.syncHistoryToGoogle) {
            win.trackPlayback(trk);
        }

        if (!win.currentTracks || win.currentTracks.length === 0) {
            win.currentTracks = [trk];
        }

        var streamPath = trk.path || ("ytdl://" + trk.videoId);
        var tTitle = trk.title || trk.name || "";
        var tArtist = trk.artist || "";
        var tImage = trk.image || "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "play", streamPath, tTitle, tArtist, tImage]);

        // Pre-warm the next track's direct stream URL in background so switching is instant
        if (win.currentTracks && win.currentTracks.length > 1) {
            var curIdx = -1;
            for (var ci = 0; ci < win.currentTracks.length; ci++) {
                if (win.isSameTrack(win.currentTracks[ci], trk)) {
                    curIdx = ci;
                    break;
                }
            }
            var nextIdx = (curIdx !== -1 && curIdx + 1 < win.currentTracks.length) ? (curIdx + 1) : 0;
            var nextTrk = win.currentTracks[nextIdx];
            var nextVid = (nextTrk && (nextTrk.videoId || (nextTrk.path && nextTrk.path.startsWith("ytdl://"))))
                ? (nextTrk.videoId || nextTrk.path.replace("ytdl://", ""))
                : "";
            if (nextVid) {
                Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "prewarm", nextVid]);
            }
        }

        if (startRadio && trk.videoId) {
            radioProc.running = false;
            radioProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "radio", trk.videoId];
            radioProc.running = true;
        }
        pollTimer.restart();
    }

    function startRadioFromTrack(trk) {
        if (!trk) return;
        win.currentTracks = [trk];
        win.playOnlineTrack(trk, true);
    }

    function loadPlaylistTracks(pl) {
        if (!pl) return;
        var pid = pl.playlistId || pl.id || pl.browseId || "";
        if (!pid) return;
        win.activePlaylistId = pid;
        if (win.currentView !== "search" && win.currentView !== "playlist") {
            win.previousView = win.currentView;
        }
        win.currentView = "playlist";
        win.mainSectionTitle = pl.title || pl.name || "Playlist";
        mainGrid.sectionTitle = pl.title || pl.name || "Playlist";

        // Check if custom / local playlist
        var isCustomPl = !!pl.isCustom || String(pid).startsWith("custom_pl_") || (pl.tracks && pl.tracks.length >= 0 && pl.isLocal);
        if (isCustomPl) {
            var foundTracks = pl.tracks || [];
            if (win.customPlaylists) {
                for (var i = 0; i < win.customPlaylists.length; i++) {
                    if (win.customPlaylists[i].id === pid) {
                        foundTracks = win.customPlaylists[i].tracks || [];
                        break;
                    }
                }
            }
            win.browsingTracks = foundTracks;
            win.isSearchingYT = false;
            return;
        }

        win.browsingTracks = [];
        win.isSearchingYT = true;
        playlistTracksProc.running = false;
        playlistTracksProc.targetTitle = pl.title || "Playlist";
        playlistTracksProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "playlist", pid];
        playlistTracksProc.running = true;
    }

    function deleteCustomPlaylist(plId) {
        if (!plId) return;
        Quickshell.execDetached([
            "python3", win.appDir + "/backend/playlist_manager.py", "delete", plId
        ]);
        refreshPlaylistsTimer.restart();
        if (win.activePlaylistId === plId && win.currentView === "playlist") {
            win.currentView = "home";
        }
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
        win.loadCustomPlaylists();
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
                isSidebarVisible: win.showSidebar

                onTabSelected: tab => win.filterByTab(tab)
                onToggleSidebarRequested: {
                    win.showSidebar = !win.showSidebar;
                }

                onBackRequested: {
                    if (win.currentView === "playlist" || win.currentView === "search") {
                        win.currentView = (win.previousView && win.previousView !== win.currentView) ? win.previousView : "home";
                    } else if (win.currentView === "library" && win.previousView === "home") {
                        win.currentView = "home";
                    } else {
                        win.currentView = "home";
                    }
                }

                onSearchRequested: (query, mode) => {
                    win.pendingSearchQuery = query;
                    win.pendingSearchMode = mode;
                    if (!query || query.trim() === "") {
                        topHeader.suggestions = [];
                        if (mode === "offline") {
                            win.currentTracks = win.allTracks;
                        }
                        return;
                    }
                    suggestionsDebounce.restart();
                    if (mode === "offline") {
                        win.filterLocalSearch(query);
                    }
                }

                onSearchSubmitted: (query, mode) => {
                    if (mode === "online" || win.currentView === "home" || win.currentView === "search" || win.currentView === "playlist") {
                        if (query && query.trim().length > 0) {
                            win.performYTSearch(query.trim());
                        }
                    } else {
                        win.filterLocalSearch(query);
                    }
                }
                onDownloadPopoverRequested: {
                    downloadPopover.isOpen = !downloadPopover.isOpen;
                }
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
                    readonly property bool shouldBeVisible: win.showSidebar && (!win.showAmberolDetails || win.width >= 900)
                    visible: shouldBeVisible
                    Layout.preferredWidth: shouldBeVisible ? 240 : 0
                    Layout.maximumWidth: shouldBeVisible ? 240 : 0
                    Layout.minimumWidth: shouldBeVisible ? 240 : 0
                    playlists: win.playlists
                    onlinePlaylists: win.homeFeaturedPlaylists
                    customPlaylists: win.customPlaylists
                    queueTracks: win.currentTracks
                    currentTrack: win.currentTrack
                    isPlaying: win.isPlaying
                    activePlaylistId: win.activePlaylistId
                    playingPlaylistId: win.playingPlaylistId
                    selectedIndex: win.selectedPlaylistIndex
                    currentView: win.currentView

                    onHomeSelected: {
                        if (win.currentView !== "home") win.previousView = win.currentView;
                        win.currentView = "home";
                        win.mainSectionTitle = "Home";
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                    onLibrarySelected: {
                        if (win.currentView !== "library") win.previousView = win.currentView;
                        win.currentView = "library";
                        win.browsingTracks = win.allTracks;
                        win.mainSectionTitle = "Downloads";
                        mainGrid.sectionTitle = "Downloads";
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                    onSettingsRequested: {
                        settingsModal.visible = true;
                    }
                    onPlaylistSelected: (idx, pl) => {
                        if (pl && (pl.playlistId || pl.id)) {
                            win.loadPlaylistTracks(pl);
                        } else {
                            if (win.currentView !== "library") win.previousView = win.currentView;
                            win.currentView = "library";
                            win.selectedPlaylistIndex = idx;
                            if (pl && pl.id) win.selectPlaylist(pl.id);
                        }
                    }
                    onOnlinePlaylistSelected: pl => {
                        win.loadPlaylistTracks(pl);
                        if (win.width < 1020) win.showAmberolDetails = false;
                    }
                    onCustomPlaylistDeleteRequested: plId => {
                        win.deleteCustomPlaylist(plId);
                    }
                    onTrackSelected: trk => {
                        if (trk && ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId)) {
                            win.playOnlineTrack(trk);
                        } else {
                            win.playTrack(trk);
                        }
                    }
                    onTrackContextMenuRequested: (trk, gx, gy, isQ) => trackContextMenu.openAt(trk, gx, gy, isQ)
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
                        sections: win.homeSections
                        quickPicks: win.homeQuickPicks
                        featuredPlaylists: win.homeFeaturedPlaylists
                        isLoading: win.isLoadingHome
                        currentTrack: win.currentTrack
                        isPlaying: win.isPlaying

                        onMoodSelected: (title, params) => win.selectMood(title, params)
                        onTrackPlayRequested: trk => win.startRadioFromTrack(trk)
                        onPlaylistSelected: pl => win.loadPlaylistTracks(pl)
                        onTrackContextMenuRequested: (trk, gx, gy) => trackContextMenu.openAt(trk, gx, gy, false)
                    }

                    SpotifyMainGrid {
                        id: mainGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tracks: win.browsingTracks
                        currentTrack: win.currentTrack
                        isPlaying: win.isPlaying
                        sectionTitle: win.mainSectionTitle
                        isLoading: win.isSearchingYT

                        onPlayAllRequested: {
                            if (!mainGrid.sortedTracks || mainGrid.sortedTracks.length === 0) return;
                            win.currentTracks = mainGrid.sortedTracks.slice();
                            if (win.currentView === "playlist") {
                                win.playingPlaylistId = win.activePlaylistId;
                            } else {
                                win.playingPlaylistId = "";
                            }
                            var first = win.currentTracks[0];
                            if (first) {
                                if ((first.path && first.path.startsWith("ytdl://")) || first.videoId) {
                                    win.playOnlineTrack(first, false);
                                } else {
                                    win.playTrack(first);
                                }
                            }
                        }
                        onTrackPlayRequested: trk => {
                            if (win.isContextMenuActive) return;
                            if (win.browsingTracks && win.browsingTracks.length > 0) {
                                win.currentTracks = win.browsingTracks;
                            }
                            if (win.currentView === "playlist") {
                                win.playingPlaylistId = win.activePlaylistId;
                            } else {
                                win.playingPlaylistId = "";
                            }
                            if (trk && ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId)) {
                                win.playOnlineTrack(trk, false);
                            } else {
                                win.playTrack(trk);
                            }
                        }
                        onTrackDetailsRequested: trk => {
                            win.currentTrack = trk;
                            win.showAmberolDetails = true;
                        }
                        onTrackContextMenuRequested: (trk, gx, gy) => trackContextMenu.openAt(trk, gx, gy, false)
                        onShufflePlayRequested: win.shufflePlayBrowsing()
                        onBatchDeleteRequested: paths => win.batchDeleteTracks(paths)
                        onCreatePlaylistRequested: trks => win.createCustomPlaylistFromTracks(trks)
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
                isLoadingAudio: win.isLoadingAudio
                currentTime: win.currentTime
                totalDuration: win.totalDuration
                volume: win.volume
                isShuffle: win.isShuffle
                isRepeat: win.isRepeat
                isLyricsActive: win.showAmberolDetails
                isQueueActive: win.showSidebar

                onPlayPauseClicked: win.togglePlay()
                onNextClicked: win.playNext()
                onPrevClicked: win.playPrev()
                onOpenDetailsRequested: {
                    win.showAmberolDetails = !win.showAmberolDetails;
                }
                onQueueClicked: {
                    win.showSidebar = !win.showSidebar;
                }
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
            }
        }

        // YouTube Music Settings / Google Account Modal
        SettingsModal {
            id: settingsModal
            isLoggedIn: win.isAuthLoggedIn
            accountName: win.authAccountName
            accountThumb: win.authAccountThumb
            syncHistoryToGoogle: win.syncHistoryToGoogle

            onCloseRequested: settingsModal.visible = false
            onToggleSyncHistoryRequested: enabled => {
                win.syncHistoryToGoogle = enabled;
                win.saveSettings();
            }
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
            onLaunchBrowserLoginRequested: {
                settingsModal.isProcessing = true;
                settingsModal.statusMessage = "Opening Google login window... Please sign in in the popup.";
                browserLoginProc.running = false;
                browserLoginProc.command = ["python3", "-u", win.appDir + "/backend/browser_login.py"];
                browserLoginProc.running = true;
            }
        }

        TrackContextMenu {
            id: trackContextMenu
            dlMgr: downloadManager
            customPlaylists: win.customPlaylists
            onPlayNextRequested: trk => win.insertTrackPlayNext(trk)
            onAddToQueueRequested: trk => win.appendTrackToQueue(trk)
            onStartRadioRequested: trk => {
                if (trk) win.startRadioFromTrack(trk)
            }
            onOpenFolderRequested: trk => win.openTrackFolder(trk)
            onDownloadTrackRequested: trk => win.downloadTrack(trk)
            onRemoveFromQueueRequested: trk => win.removeTrackFromQueue(trk)
            onRemoveFromPlaylistRequested: (trk, plId) => win.removeTrackFromCustomPlaylist(plId, trk)
            onDeleteTrackRequested: trk => win.deleteLocalTrack(trk)
            onAddToPlaylistRequested: (trk, plId) => win.addTrackToCustomPlaylist(plId, trk)
            onCreatePlaylistWithTrackRequested: trk => win.createCustomPlaylistFromTracks([trk])
        }

        DownloadManager {
            id: downloadManager
            onTaskCompleted: (videoId, title, path) => {
                libLoader.reload();
            }
        }

        DownloadQueuePopover {
            id: downloadPopover
            dlMgr: downloadManager
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
            if (obj.syncHistoryToGoogle !== undefined) win.syncHistoryToGoogle = !!obj.syncHistoryToGoogle;
            console.log("DEBUG Frostify settings loaded: isShuffle=" + win.isShuffle + ", isRepeat=" + win.isRepeat + ", syncHistoryToGoogle=" + win.syncHistoryToGoogle);
        } catch(e) {}
    }

    function saveSettings() {
        var data = JSON.stringify({
            isShuffle: win.isShuffle,
            isRepeat: win.isRepeat,
            syncHistoryToGoogle: win.syncHistoryToGoogle
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
        watchChanges: false
    }

    // Library Data Loader
    LibraryLoader {
        id: libLoader
        onLoaded: {
            win.playlists = (libLoader.playlists || []).concat(win.customPlaylists || []);
            win.allTracks = libLoader.allTracks;
            if (win.currentView === "library" || !win.browsingTracks || win.browsingTracks.length === 0) {
                win.browsingTracks = win.allTracks;
            }
            if (!win.currentTracks || win.currentTracks.length === 0) {
                win.currentTracks = win.allTracks;
            }

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
            win.browsingTracks = win.allTracks;
            mainGrid.sectionTitle = "Downloads & All Tracks";
        } else if (pid === "simp") {
            win.browsingTracks = win.allTracks.filter(t => t.source === "SimpMusic");
            mainGrid.sectionTitle = "SimpMusic Tracks";
        } else if (pid === "downloads") {
            win.browsingTracks = win.allTracks.filter(t => t.source === "Downloads");
            mainGrid.sectionTitle = "Downloads";
        } else if (pid === "ado") {
            win.browsingTracks = win.allTracks.filter(t => (t.artist && t.artist.toLowerCase().includes("ado")) || (t.name && t.name.toLowerCase().includes("ado")));
            mainGrid.sectionTitle = "Ado Collection";
        } else if (pid && pid.startsWith("custom_pl_")) {
            for (var i = 0; i < win.customPlaylists.length; i++) {
                if (win.customPlaylists[i].id === pid) {
                    win.browsingTracks = win.customPlaylists[i].tracks || [];
                    mainGrid.sectionTitle = win.customPlaylists[i].title || "Playlist";
                    break;
                }
            }
        }
    }

    function filterByTab(tab) {
        win.currentTab = tab;
        win.showAmberolDetails = false;
        if (tab === "all") {
            win.browsingTracks = win.allTracks;
        } else if (tab === "music") {
            win.browsingTracks = win.allTracks.filter(t => t.source === "SimpMusic" || t.source === "Downloads");
        } else if (tab === "ado") {
            win.browsingTracks = win.allTracks.filter(t => (t.artist && t.artist.toLowerCase().includes("ado")) || (t.name && t.name.toLowerCase().includes("ado")));
        } else if (tab === "ytmusic") {
            if (win.ytMusicTracks.length > 0) {
                win.browsingTracks = win.ytMusicTracks;
            } else {
                win.performYTSearch("Trending");
            }
        }
    }

    function filterBySearch(q) {
        if (q && q.trim() !== "") {
            win.currentView = "library";
            win.showAmberolDetails = false;
            win.mainSectionTitle = 'Search: "' + q + '"';
            mainGrid.sectionTitle = 'Search: "' + q + '"';
        } else {
            win.mainSectionTitle = win.currentTab === "ytmusic" ? "YouTube Music" : "Downloads";
            mainGrid.sectionTitle = win.mainSectionTitle;
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
        win.trackChangeTimestamp = Date.now();
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.isLoadingAudio = false;
        win.totalDuration = (trk.durationMs || 0) / 1000.0;
        win.isPlaying = true;

        if (win.syncHistoryToGoogle) {
            win.trackPlayback(trk);
        }

        var tTitle = trk.title || trk.name || "";
        var tArtist = trk.artist || "";
        var tImage = trk.image || "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "play", trk.path, tTitle, tArtist, tImage]);
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
        if (!win.currentTracks || win.currentTracks.length === 0) return;
        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        var nextIdx = 0;
        if (win.isShuffle && win.currentTracks.length > 1) {
            nextIdx = curIdx;
            while (nextIdx === curIdx) {
                nextIdx = Math.floor(Math.random() * win.currentTracks.length);
            }
        } else {
            nextIdx = (curIdx >= 0) ? (curIdx + 1) : 0;
            if (nextIdx >= win.currentTracks.length) {
                nextIdx = 0;
            }
        }
        var nextTrk = win.currentTracks[nextIdx];
        if (nextTrk) {
            if ((nextTrk.path && nextTrk.path.startsWith("ytdl://")) || nextTrk.videoId) {
                win.playOnlineTrack(nextTrk, false);
            } else {
                win.playTrack(nextTrk);
            }
        }
    }

    function playPrev() {
        if (!win.currentTracks || win.currentTracks.length === 0) return;
        if (win.currentTime > 3.0) {
            win.seekAudio(0.0);
            return;
        }
        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        var prevIdx = (curIdx - 1 + win.currentTracks.length) % win.currentTracks.length;
        var prevTrk = win.currentTracks[prevIdx];
        if (prevTrk) {
            if ((prevTrk.path && prevTrk.path.startsWith("ytdl://")) || prevTrk.videoId) {
                win.playOnlineTrack(prevTrk, false);
            } else {
                win.playTrack(prevTrk);
            }
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

    function insertTrackPlayNext(trk) {
        if (!trk) return;

        // If currently playing track is selected, do not duplicate or restart
        if (win.isSameTrack(trk, win.currentTrack)) {
            return;
        }

        if (!win.currentTracks || win.currentTracks.length === 0) {
            if (win.currentTrack) {
                win.currentTracks = [win.currentTrack, trk];
            } else {
                win.currentTracks = [trk];
                if ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId) win.playOnlineTrack(trk, false);
                else win.playTrack(trk);
            }
            return;
        }

        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        var insertAt = (curIdx >= 0) ? (curIdx + 1) : 1;
        var updated = win.currentTracks.slice();
        var dupIdx = updated.findIndex(t => win.isSameTrack(t, trk));
        if (dupIdx >= 0) {
            updated.splice(dupIdx, 1);
            if (dupIdx < insertAt) insertAt--;
        }
        updated.splice(insertAt, 0, trk);
        win.currentTracks = updated;
    }

    function appendTrackToQueue(trk) {
        if (!trk) return;
        if (!win.currentTracks || win.currentTracks.length === 0) {
            if (win.currentTrack) {
                win.currentTracks = [win.currentTrack, trk];
            } else {
                win.currentTracks = [trk];
                if ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId) win.playOnlineTrack(trk, false);
                else win.playTrack(trk);
            }
            return;
        }
        var updated = win.currentTracks.slice();
        var dupIdx = updated.findIndex(t => win.isSameTrack(t, trk));
        if (dupIdx >= 0) {
            updated.splice(dupIdx, 1);
        }
        updated.push(trk);
        win.currentTracks = updated;
    }

    function removeTrackFromQueue(trk) {
        if (!trk || !win.currentTracks) return;
        var idx = win.currentTracks.findIndex(t => win.isSameTrack(t, trk));
        if (idx >= 0) {
            var updated = win.currentTracks.slice();
            updated.splice(idx, 1);
            win.currentTracks = updated;
        }
    }

    function deleteLocalTrack(trk) {
        if (!trk) return;
        var p = trk.path || "";
        var fn = trk.filename || "";
        var title = trk.title || trk.name || "";

        var wasPlaying = win.isPlaying;
        var isCurrent = win.isSameTrack(win.currentTrack, trk);

        // Remove from current queue first so indices and playlist stay consistent
        win.currentTracks = win.currentTracks.filter(t => !win.isSameTrack(t, trk));

        // Immediately update reactive arrays for 0ms UI update
        win.allTracks = win.allTracks.filter(t => !win.isSameTrack(t, trk));
        win.browsingTracks = win.browsingTracks.filter(t => !win.isSameTrack(t, trk));

        // If the deleted track was loaded in the player
        if (isCurrent) {
            if (wasPlaying && win.currentTracks && win.currentTracks.length > 0) {
                win.playNext();
            } else {
                win.isPlaying = false;
                win.currentTrack = null;
                win.currentTime = 0.0;
                Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "stop"]);
            }
        }

        // Call backend/library.py to delete file, delete .lrc, and update library.json permanently
        if (!p.startsWith("ytdl://") && (p || fn || title)) {
            Quickshell.execDetached([
                "python3", win.appDir + "/backend/library.py", "delete",
                p, fn, title
            ]);
        }
    }

    function openTrackFolder(trk) {
        if (!trk || !trk.path) return;
        Quickshell.execDetached(["sh", "-c", 'xdg-open "$(dirname "$1")"', "sh", trk.path]);
    }

    function downloadTrack(trk) {
        if (!trk) return;
        downloadManager.enqueue(trk);
    }

    function shufflePlayBrowsing() {
        var sourceTracks = (win.browsingTracks && win.browsingTracks.length > 0) ? win.browsingTracks : win.allTracks;
        if (!sourceTracks || sourceTracks.length === 0) return;
        var shuffled = sourceTracks.slice();
        for (var i = shuffled.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var temp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = temp;
        }
        win.currentTracks = shuffled;
        if (win.currentView === "playlist") {
            win.playingPlaylistId = win.activePlaylistId;
        } else {
            win.playingPlaylistId = "";
        }
        var firstTrk = shuffled[0];
        if (firstTrk && ((firstTrk.path && firstTrk.path.startsWith("ytdl://")) || firstTrk.videoId)) {
            win.playOnlineTrack(firstTrk, false);
        } else {
            win.playTrack(firstTrk);
        }
    }

    function shufflePlayDownloads() {
        win.shufflePlayBrowsing();
    }

    function batchDeleteTracks(paths) {
        if (!paths || paths.length === 0) return;
        var pathSet = {};
        for (var i = 0; i < paths.length; i++) {
            pathSet[paths[i]] = true;
        }

        var currentDeleted = win.currentTrack && pathSet[win.currentTrack.path];

        win.currentTracks = win.currentTracks.filter(t => !pathSet[t.path]);
        win.allTracks = win.allTracks.filter(t => !pathSet[t.path]);
        win.browsingTracks = win.browsingTracks.filter(t => !pathSet[t.path]);

        if (currentDeleted) {
            if (win.isPlaying && win.currentTracks.length > 0) {
                win.playNext();
            } else {
                win.isPlaying = false;
                win.currentTrack = null;
                win.currentTime = 0.0;
                Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "stop"]);
            }
        }

        Quickshell.execDetached([
            "python3", win.appDir + "/backend/library.py", "batch_delete",
            JSON.stringify(paths)
        ]);
    }

    Process {
        id: customPlaylistsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr)) {
                        win.customPlaylists = arr;
                        win.playlists = (libLoader.playlists || []).concat(arr);
                    }
                } catch(e) {
                    console.log("customPlaylistsProc error:", e);
                }
            }
        }
    }

    Timer {
        id: refreshPlaylistsTimer
        interval: 300
        repeat: false
        onTriggered: win.loadCustomPlaylists()
    }

    function loadCustomPlaylists() {
        customPlaylistsProc.running = false;
        customPlaylistsProc.command = ["python3", "-u", win.appDir + "/backend/playlist_manager.py", "list"];
        customPlaylistsProc.running = true;
    }

    function createCustomPlaylistFromTracks(tracks) {
        if (!tracks || tracks.length === 0) return;
        var plName = "Playlist #" + ((win.customPlaylists ? win.customPlaylists.length : 0) + 1);
        Quickshell.execDetached([
            "python3", win.appDir + "/backend/playlist_manager.py", "create",
            plName, JSON.stringify(tracks)
        ]);
        refreshPlaylistsTimer.restart();
    }

    function addTrackToCustomPlaylist(plId, track) {
        if (!plId || !track) return;
        Quickshell.execDetached([
            "python3", win.appDir + "/backend/playlist_manager.py", "add",
            plId, JSON.stringify([track])
        ]);
        refreshPlaylistsTimer.restart();
    }

    function removeTrackFromCustomPlaylist(plId, track) {
        if (!plId || !track) return;
        var p = track.path || "";
        Quickshell.execDetached([
            "python3", win.appDir + "/backend/playlist_manager.py", "remove",
            plId, p
        ]);
        refreshPlaylistsTimer.restart();
        win.browsingTracks = win.browsingTracks.filter(t => t.path !== p);
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
                    var elapsed = Date.now() - win.trackChangeTimestamp;

                    if (win.isLoadingAudio) {
                        // While loading:
                        // 1. Daemon says is_loading, OR
                        // 2. Not enough time elapsed (< 400ms), OR
                        // 3. MPV hasn't started playing positive time (time_pos <= 0)
                        if (s.is_loading || elapsed < 400 || !s.time_pos || s.time_pos <= 0) {
                            win.currentTime = 0.0;
                            return;
                        }
                        // New track has begun streaming and playing!
                        win.isLoadingAudio = false;
                        win.currentTime = s.time_pos;
                        if (s.duration !== undefined && s.duration > 0) win.totalDuration = s.duration;
                        if (s.is_playing !== undefined) win.isPlaying = s.is_playing;
                    } else {
                        if (s.is_playing !== undefined) win.isPlaying = s.is_playing;
                        if (s.time_pos !== undefined && s.time_pos > 0) {
                            win.currentTime = s.time_pos;
                        }
                        if (s.duration !== undefined && s.duration > 0) win.totalDuration = s.duration;
                    }

                    // Sync track from filename if playing (cold start recovery only when currentTrack is null)
                    if (!win.currentTrack && s.filename && win.allTracks && win.allTracks.length > 0) {
                        var matched = win.allTracks.find(t => t.path && t.path.endsWith(s.filename));
                        if (matched) win.currentTrack = matched;
                    }

                    // Auto-advance or Repeat at song end
                    if (!win.isLoadingAudio && win.totalDuration > 3 && win.currentTime >= win.totalDuration - 0.4) {
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
            win.browsingTracks = win.allTracks;
            mainGrid.sectionTitle = "Downloads (Local)";
        }
        function showHome() {
            win.currentView = "home";
        }
        function selectMood(title: string, params: string) {
            win.selectMood(title, params);
        }
        function openContextMenuForTest(isQueue: bool, forceLocal: bool) {
            var trk = null;
            if (forceLocal && win.allTracks && win.allTracks.length > 0) {
                trk = win.allTracks[0];
            } else {
                trk = win.currentTrack || (win.homeQuickPicks && win.homeQuickPicks.length > 0 ? win.homeQuickPicks[0] : null) || (win.allTracks && win.allTracks.length > 0 ? win.allTracks[0] : null);
            }
            if (trk) {
                trackContextMenu.openAt(trk, 600, 320, isQueue);
            }
        }
        function closeContextMenu() {
            trackContextMenu.closeMenu();
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

