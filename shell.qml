import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Effects
import "./components"

Scope {
    id: appScope

    FloatingWindow {
        id: win
        title: Quickshell.env("NUTSTY_PROFILE") ? ("Nutsty (" + Quickshell.env("NUTSTY_PROFILE") + ")") : "Nutsty"
        implicitWidth: Quickshell.env("NUTSTY_PROFILE") ? 810 : 1280
        implicitHeight: Quickshell.env("NUTSTY_PROFILE") ? 800 : 820
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
                Qt.callLater(function() { if (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ytNowPlayingView.updateActiveLyric(true); });
            }
        }

        property var activeLyrics: (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ? ytNowPlayingView.activeLyrics : []

    readonly property string appDir: Quickshell.env("NUTSTY_APP_DIR") || (Quickshell.env("HOME") + "/Applications/FrostifyLocal")

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
    property string playingSourceTitle: ""
    property bool isLoadingAudio: false

    property real trackChangeTimestamp: 0
    property real postLoadGraceTimestamp: 0
    property var moodCache: ({})
    property string pendingSearchQuery: ""
    property string pendingSearchMode: "online"

    property bool isAuthLoggedIn: false
    property string authAccountName: ""
    property string authAccountThumb: ""
    property string authAccountEmail: ""
    property bool syncHistoryToGoogle: true
    property bool desktopLyricsEnabled: true
    property bool animatedCoverEnabled: true
    property int desktopLyricsPreset: 2 // 1: Gacha Anime, 2: Apple Music 5-Line Parametric, 3: Broadway Pop, 4: Anime MV Kinetic
    property int desktopLyricsCustomX: -1
    property int desktopLyricsCustomY: -1
    property var desktopLyricsWallpaperPositions: ({})
    property bool isSleepTimerActive: false
    property int sleepTimerRemainingSeconds: 0
    property string sleepTimerMode: "" // "duration" or "end_of_track"
    property bool sleepTimerFadeTriggered: false
    property string currentLanguage: I18n.locale
    property string streamingQuality: "high_opus"
    property string downloadQuality: "high_opus"
    property bool showSidebar: true
    property var friendsNotes: []
    property var friendsList: []
    property var friendsDetails: []
    property var pendingFriendRequests: []
    property int unreadFriendRequestsCount: 0
    property var myLatestNote: null
    property var listeningAlongFriend: null
    property real pendingListenAlongSeekPosition: 0.0
    property real lastTrackSwitchTimestamp: 0.0
    property string toastMessage: ""
    property bool toastVisible: false
    property string notesApiUrl: Quickshell.env("NUTSTY_WORKER_URL") || "http://127.0.0.1:17890"
    property real lastNowPlayingSyncTime: 0
    property bool isFetchingNotesFast: false
    property bool isSyncingFromFriend: false
    property var activeCoListeners: []
    property var activeCoListenersDetails: []
    readonly property bool isCoListeningActive: (win.listeningAlongFriend !== null && win.listeningAlongFriend !== undefined) || (win.activeCoListeners && win.activeCoListeners.length > 0)
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
    property var currentArtistData: null
    property var artistHistoryStack: []
    property bool isLoadingArtist: false
    property var followedArtists: []
    property color wallpaperAccentColor: "#f4afb3"
    property color songAccentColor: "#f4afb3"
    readonly property color effectiveAccentColor: (win.currentTrack && win.isPlaying) ? win.songAccentColor : win.wallpaperAccentColor
    property color accentColor: effectiveAccentColor
    Behavior on accentColor {
        ColorAnimation {
            duration: 400
            easing.type: Easing.InOutQuad
        }
    }
    property string currentWallpaperPath: ""
    onCurrentWallpaperPathChanged: {
        if (currentWallpaperPath) {
            syncLyricsPositionForWallpaper(currentWallpaperPath);
        }
    }

    function getWallpaperKey(path) {
        if (!path || typeof path !== "string" || path.trim() === "") return "default";
        var clean = path.trim();
        var parts = clean.split("/");
        var filename = parts[parts.length - 1];
        return filename || "default";
    }

    function syncLyricsPositionForWallpaper(wpPath) {
        var wpKey = getWallpaperKey(wpPath);
        if (win.desktopLyricsWallpaperPositions && win.desktopLyricsWallpaperPositions[wpKey]) {
            var saved = win.desktopLyricsWallpaperPositions[wpKey];
            if (saved && saved.x !== undefined && saved.y !== undefined) {
                win.desktopLyricsCustomX = Number(saved.x);
                win.desktopLyricsCustomY = Number(saved.y);
                return;
            }
        }
        win.desktopLyricsCustomX = -1;
        win.desktopLyricsCustomY = -1;
    }

    property var categorizedSearchData: null
    property string searchViewMode: "results" // "results", "suggestions"
    property var searchSuggestions: []
    property var searchRecommendedSuggestions: []
    property var trackBeforeNotePreview: null
    property bool wasPlayingBeforeNotePreview: false
    property var queueBeforeNotePreview: null

    Process {
        id: songPaletteProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var parsed = JSON.parse(data);
                    if (parsed && parsed.highlightColor) {
                        win.songAccentColor = parsed.highlightColor;
                    }
                } catch(e) {}
            }
        }
    }

    function getTrackCoverUrl(trk) {
        if (!trk) return "";
        if (trk.cover && typeof trk.cover === "string" && trk.cover.trim() !== "") return trk.cover.trim();
        if (trk.image && typeof trk.image === "string" && trk.image.trim() !== "") return trk.image.trim();
        if (trk.artUrl && typeof trk.artUrl === "string" && trk.artUrl.trim() !== "") return trk.artUrl.trim();
        if (trk.thumbnail && typeof trk.thumbnail === "string" && trk.thumbnail.trim() !== "") return trk.thumbnail.trim();
        if (win.currentResolvedCover && win.isSameTrack(trk, win.currentTrack)) return win.currentResolvedCover;
        return "";
    }

    function fetchSongPalette(imgUrl) {
        if (!imgUrl || typeof imgUrl !== "string" || imgUrl.trim() === "") {
            win.songAccentColor = win.wallpaperAccentColor;
            return;
        }
        songPaletteProc.running = false;
        songPaletteProc.command = [
            "python3", "-u",
            win.appDir + "/backend/palette_extractor.py",
            "song_palette",
            imgUrl
        ];
        songPaletteProc.running = true;
    }

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
        interval: 120
        repeat: false
        onTriggered: {
            if (win.pendingSearchMode === "online") {
                win.fetchSearchSuggestions(win.pendingSearchQuery);
            } else {
                win.filterLocalSuggestions(win.pendingSearchQuery);
            }
        }
    }

    property var suggestionsCache: ({})

    Process {
        id: searchSuggestionsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (Array.isArray(res)) {
                        topHeader.suggestions = res;
                        if (searchView) searchView.suggestions = res;
                    } else if (res && typeof res === "object") {
                        topHeader.suggestions = res.queries || [];
                        if (searchView) {
                            searchView.suggestions = res.queries || [];
                            searchView.recommendedSuggestions = res.recommended || [];
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function fetchSearchSuggestions(q) {
        console.log("[DEBUG] fetchSearchSuggestions called with q=" + q);
        if (!q || q.trim() === "") {
            win.searchSuggestions = [];
            win.searchRecommendedSuggestions = [];
            topHeader.suggestions = [];
            return;
        }
        var cleanQ = q.trim();
        if (win.suggestionsCache && win.suggestionsCache[cleanQ]) {
            var cached = win.suggestionsCache[cleanQ];
            console.log("[DEBUG] fetchSearchSuggestions cache hit: " + JSON.stringify(cached));
            win.searchSuggestions = cached.queries || [];
            win.searchRecommendedSuggestions = cached.recommended || [];
            topHeader.suggestions = cached.queries || [];
            return;
        }

        try {
            var xhr = new XMLHttpRequest();
            var url = "http://127.0.0.1:17890/api/suggestions?q=" + encodeURIComponent(cleanQ);
            console.log("[DEBUG] Sending XHR to " + url);
            xhr.open("GET", url, true);
            xhr.onreadystatechange = function() {
                console.log("[DEBUG] XHR readyState=" + xhr.readyState + " status=" + xhr.status);
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            var queries = [];
                            var recs = [];
                            if (Array.isArray(res)) {
                                queries = res;
                            } else if (res && typeof res === "object") {
                                queries = res.queries || [];
                                recs = res.recommended || [];
                            }
                            if (!win.suggestionsCache) win.suggestionsCache = {};
                            win.suggestionsCache[cleanQ] = { queries: queries, recommended: recs };
                            win.searchSuggestions = queries;
                            win.searchRecommendedSuggestions = recs;
                            topHeader.suggestions = queries;
                            console.log("[DEBUG] Got " + queries.length + " queries and " + recs.length + " recs");
                        } catch(e) {
                            console.error("Parse suggestions error: " + e);
                        }
                    } else {
                        console.log("[DEBUG] XHR status not 200, fallback to python CLI");
                        searchSuggestionsProc.running = false;
                        searchSuggestionsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "suggestions", cleanQ];
                        searchSuggestionsProc.running = true;
                    }
                }
            };
            xhr.onerror = function(err) {
                console.log("[DEBUG] XHR error: " + err);
                searchSuggestionsProc.running = false;
                searchSuggestionsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "suggestions", cleanQ];
                searchSuggestionsProc.running = true;
            };
            xhr.send();
        } catch(xhrErr) {
            console.log("[DEBUG] XHR exception: " + xhrErr + ", fallback to CLI");
            searchSuggestionsProc.running = false;
            searchSuggestionsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "suggestions", cleanQ];
            searchSuggestionsProc.running = true;
        }
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
                    var obj = JSON.parse(data);
                    if (obj && typeof obj === "object") {
                        if (win.lastYTQuery && obj.query && obj.query.trim().toLowerCase() !== win.lastYTQuery.trim().toLowerCase()) {
                            return;
                        }
                        win.categorizedSearchData = obj;
                        var songs = obj.songs || [];
                        win.ytMusicTracks = songs;
                        win.browsingTracks = songs;
                        win.currentView = "search";
                        win.searchViewMode = "results";
                        searchView.viewMode = "results";
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
        win.searchViewMode = "results";
        if (win.currentView !== "search" && win.currentView !== "playlist") {
            win.previousView = win.currentView;
        }
        win.currentView = "search";
        win.lastYTQuery = q || "Trending";
        if (q && q !== "Trending" && typeof searchView !== "undefined" && searchView) {
            if (typeof searchView.addSearchHistory === "function") {
                searchView.addSearchHistory(q);
            }
            searchView.searchInputText = q;
        }
        mainGrid.sectionTitle = 'Results for "' + win.lastYTQuery + '"';
        ytSearchProc.running = false;
        ytSearchProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "categorized_search", win.lastYTQuery];
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
                    homeLoadingSafetyTimer.stop();
                }
            }
        }
        onExited: {
            win.isLoadingHome = false;
            homeLoadingSafetyTimer.stop();
        }
    }

    Timer {
        id: homeLoadingSafetyTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (win.isLoadingHome) {
                win.isLoadingHome = false;
            }
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
        id: albumDetailsProc
        property string targetTitle: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res && res.tracks && Array.isArray(res.tracks)) {
                        win.currentAlbumMetadata = res.metadata || null;
                        win.browsingTracks = res.tracks;
                        win.currentView = "playlist";
                        win.mainSectionTitle = (res.metadata && res.metadata.title) ? res.metadata.title : albumDetailsProc.targetTitle;
                        mainGrid.sectionTitle = win.mainSectionTitle;
                        mainGrid.albumMetadata = win.currentAlbumMetadata;
                    }
                } catch(e) {
                    console.log("albumDetailsProc error:", e);
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
        id: localAlbumsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    if (Array.isArray(arr)) {
                        win.localAlbums = arr;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: artistDetailsProc
        property string targetArtist: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res && res.metadata) {
                        win.currentArtistData = res;
                    }
                } catch(e) {
                    console.log("artistDetailsProc parse error:", e);
                } finally {
                    win.isLoadingArtist = false;
                }
            }
        }
        onExited: {
            win.isLoadingArtist = false;
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
                    win.authAccountEmail = s.email || "";
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

    Process {
        id: fetchFriendsNotesProc
        command: ["python3", "-u", win.appDir + "/backend/social_notes.py", "get"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        win.friendsNotes = parsed;
                    } else if (parsed && typeof parsed === "object") {
                        if (Array.isArray(parsed.notes)) {
                            win.friendsNotes = parsed.notes;
                        } else if (Array.isArray(parsed.friends)) {
                            win.friendsNotes = parsed.friends;
                        }
                        if (parsed.my_note !== undefined) {
                            win.myLatestNote = parsed.my_note;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: postNoteProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data);
                    if (res && res.success && res.note) {
                        win.myLatestNote = res.note;
                    }
                } catch(e) {}
            }
        }
        onExited: {
            if (!fetchFriendsNotesProc.running) {
                fetchFriendsNotesProc.running = true;
            }
        }
    }

    Process {
        id: deleteNoteProc
        onExited: {
            if (!fetchFriendsNotesProc.running) {
                fetchFriendsNotesProc.running = true;
            }
        }
    }

    Process {
        id: sendSocialEventProc
    }

    Process {
        id: fetchSocialEventsProc
        command: ["python3", "-u", win.appDir + "/backend/social_notes.py", "get_events"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var events = JSON.parse(data);
                    if (Array.isArray(events)) {
                        for (var i = 0; i < events.length; i++) {
                            var ev = events[i];
                            if (ev && ev.event === "leave") {
                                var fromName = ev.from_name || ev.from_email || I18n.tr("Bạn bè", "Friend");
                                win.showToast(I18n.tr(fromName + " đã dừng nghe cùng bạn", fromName + " stopped listening along with you"));
                                if (win.listeningAlongFriend && (win.listeningAlongFriend.user_email === ev.from_email || win.listeningAlongFriend.user_name === ev.from_name)) {
                                    win.listeningAlongFriend = null;
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 3200
        onTriggered: win.toastVisible = false
    }

    Timer {
        id: listenAlongSeekSafetyTimer
        property real targetPos: 0
        interval: 1500
        repeat: false
        onTriggered: {
            // Disabled: StatusProcess handles accurate seek once MPV has finished loading (!s.is_loading)
        }
    }

    function formatPlaybackTime(sec) {
        if (isNaN(sec) || sec < 0) return "0:00";
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function sendSocialEventFast(ev_type, to_email, extra_data) {
        if (!to_email) return;
        var myEmail = win.authAccountEmail;
        if (!myEmail) {
            var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
            myEmail = (profile === "user2") ? "hiutrn@gmail.com" : (profile === "user1" ? "@shiraori618" : "");
        }
        var myName = win.authAccountName;
        if (!myName) {
            var profileN = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
            myName = (profileN === "user2") ? "Hiếu Trần" : (profileN === "user1" ? "Shiraori" : "Nutsty User");
        }
        var myAvatar = win.authAccountAvatar || "";
        if (!myAvatar && win.myLatestNote && win.myLatestNote.avatar_url) {
            myAvatar = win.myLatestNote.avatar_url;
        }
        var payload = {
            event: ev_type,
            from_email: myEmail,
            from_name: myName,
            from_avatar: myAvatar,
            to_email: to_email,
            data: extra_data || null
        };
        var xhr = new XMLHttpRequest();
        xhr.open("POST", (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/notes/events", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(payload));
    }

    function sendOfflineSignal() {
        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/users/offline";
        var payload = JSON.stringify({ profile: profile, user_email: email });
        Quickshell.execDetached(["curl", "-s", "-X", "POST", apiUrl, "-H", "Content-Type: application/json", "-d", payload]);
        Quickshell.execDetached(["python3", win.appDir + "/backend/social_notes.py", "offline"]);
    }

    function syncNowPlaying(force) {
        var now = Date.now();
        if (!force && (now - win.lastNowPlayingSyncTime < 4000)) return;
        win.lastNowPlayingSyncTime = now;

        var email = win.authAccountEmail;
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        if (!email) {
            email = (profile === "user2") ? "hiutrn@gmail.com" : (profile === "user1" ? "@shiraori618" : "");
        }
        if (!email) return;

        var cur = win.currentTrack;
        var npData = null;
        if (cur) {
            var vid = cur.videoId || cur.id || (cur.path && cur.path.startsWith("ytdl://") ? cur.path.replace("ytdl://", "") : "");
            if (vid && vid.startsWith("yt_")) vid = vid.replace(/^yt_/, "");
            var cov = win.getTrackCoverUrl(cur);
            npData = {
                id: vid,
                videoId: vid,
                path: cur.path || (vid ? ("ytdl://" + vid) : ""),
                title: cur.title || cur.name || "Track",
                artist: cur.artist || "Artist",
                cover: cov,
                image: cov,
                accent_color: win.songAccentColor ? win.songAccentColor.toString() : "",
                position: win.currentTime || 0,
                duration: win.totalDuration || cur.duration || 0,
                is_playing: win.isPlaying,
                timestamp: Date.now() / 1000.0
            };
        }

        var xhr = new XMLHttpRequest();
        xhr.open("POST", (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/now_playing", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({
            profile: profile,
            user_email: email,
            user_name: win.authAccountName || "",
            avatar_url: win.authAccountThumb || "",
            now_playing: npData
        }));
    }

    function getCurrentUserEmail() {
        if (win.authAccountEmail && win.authAccountEmail.includes("@")) {
            return win.authAccountEmail;
        }
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        if (profile) return profile;
        return win.currentUserTag || "nutsty_user";
    }

    function getCurrentUserName() {
        if (win.currentUserName) return win.currentUserName;
        if (win.authAccountName) return win.authAccountName;
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        if (profile === "user2") return "Hiếu Trần";
        if (profile === "user1") return "Shiraori";
        return I18n.tr("Khách", "Guest");
    }

    function getCurrentUserAvatar() {
        if (win.authAccountThumb) return win.authAccountThumb;
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        if (profile === "user1") {
            return "https://yt3.ggpht.com/yti/ANjgQV87mKpSJkLdeIPde7wHxvnE5VCdypuOrjkni974j7oLkaJ2=s108-c-k-c0x00ffffff-no-rj";
        }
        if (profile === "user2") {
            return "https://yt3.ggpht.com/yti/ANjgQV-gmgVqqr67jTVBtevq6YMeZh0jpxYB0_EOiLb7uSg=s108-c-k-c0x00ffffff-no-rj";
        }
        return "";
    }

    property string currentUserName: ""
    property string currentUserPin: ""
    property string currentUserTag: ""
    property string currentUserCloudId: ""

    function fetchCurrentUserProfile() {
        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/users/me?user_email=" + encodeURIComponent(email) + "&profile=" + encodeURIComponent(profile);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText);
                    if (res && res.success && res.profile) {
                        win.currentUserPin = res.profile.discriminator || res.profile.pin_code || "";
                        win.currentUserTag = res.profile.tag || res.profile.nutsty_tag || "";
                        win.currentUserCloudId = res.profile.user_id || res.profile.id || "";
                        if (res.profile.username) {
                            win.currentUserName = res.profile.username;
                        }
                    }
                } catch(e) {}
            }
        };
        xhr.send();
    }

    function updateUserProfile(newUsername, newDiscriminator, callback) {
        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/users/update_profile";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var res = null;
                try {
                    res = JSON.parse(xhr.responseText);
                } catch(e) {}
                if (xhr.status === 200 && res && res.success && res.user) {
                    try {
                        win.currentUserPin = res.user.discriminator || "";
                        win.currentUserTag = res.user.tag || "";
                        win.currentUserName = res.user.username || "";
                        win.showToast(I18n.tr("Đã cập nhật: " + res.user.tag, "Updated: " + res.user.tag));
                    } catch(err) {
                        console.error("[updateUserProfile error]", err);
                    }
                    if (typeof callback === "function") callback(true, res);
                } else {
                    var err = (res && res.error) ? res.error : "Failed";
                    if (res && res.suggested_tag) {
                        err += " (" + I18n.tr("Gợi ý: ", "Suggested: ") + res.suggested_tag + ")";
                    }
                    win.showToast(err);
                    if (typeof callback === "function") callback(false, res);
                }
            }
        };
        xhr.send(JSON.stringify({
            user_email: email,
            profile: profile,
            new_username: newUsername,
            new_discriminator: newDiscriminator
        }));
    }

    function regenerateUserPin() {
        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/users/regenerate_pin";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText);
                    if (res && res.success && res.pin_code) {
                        win.currentUserPin = res.pin_code;
                        if (res.nutsty_tag) win.currentUserTag = res.nutsty_tag;
                        win.showToast(I18n.tr("Đã tạo Tag mới: #" + res.pin_code, "New Tag generated: #" + res.pin_code));
                    }
                } catch(e) {}
            }
        };
        xhr.send(JSON.stringify({ user_email: email, profile: profile }));
    }

    function fetchFriendsDataFast(callback) {
        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/friends?user_email=" + encodeURIComponent(email) + (profile ? ("&profile=" + encodeURIComponent(profile)) : "");

        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var parsed = JSON.parse(xhr.responseText);
                        if (parsed && typeof parsed === "object") {
                            if (Array.isArray(parsed.friends)) {
                                win.friendsDetails = parsed.friends;
                                win.friendsList = parsed.friends.map(function(f) { return f.email || f.tag; });
                            }
                            if (Array.isArray(parsed.incoming_requests)) {
                                win.pendingFriendRequests = parsed.incoming_requests;
                                win.unreadFriendRequestsCount = parsed.incoming_requests.length;
                            }
                        }
                    } catch(e) {}
                }
                if (typeof callback === "function") callback();
            }
        };
        xhr.send();
    }

    function fetchFriendsNotesFast() {
        if (win.isFetchingNotesFast) return;
        win.isFetchingNotesFast = true;

        var email = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var friendsParam = (win.friendsList && win.friendsList.length > 0)
            ? win.friendsList.join(",")
            : "";

        var url = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/notes?friends=" + encodeURIComponent(friendsParam) + (email ? ("&user_email=" + encodeURIComponent(email)) : "") + (profile ? ("&profile=" + encodeURIComponent(profile)) : "");

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                win.isFetchingNotesFast = false;
                if (xhr.status === 200) {
                    try {
                        var parsed = JSON.parse(xhr.responseText);
                        if (parsed && typeof parsed === "object") {
                            if (Array.isArray(parsed.notes)) {
                                win.friendsNotes = parsed.notes;
                            }
                            if (parsed.my_note !== undefined) {
                                win.myLatestNote = parsed.my_note;
                            }

                            // Auto-follow and real-time co-listening synchronization (Play/Pause/Seek)
                            if (win.listeningAlongFriend && Array.isArray(parsed.notes)) {
                                if (Date.now() - win.lastTrackSwitchTimestamp < 4000) {
                                    return;
                                }
                                var targetEmail = (win.listeningAlongFriend.user_email || "").toLowerCase();
                                var targetName = win.listeningAlongFriend.user_name;
                                var updated = parsed.notes.find(function(f) {
                                    return (targetEmail && f.user_email && f.user_email.toLowerCase() === targetEmail) ||
                                           (targetName && f.user_name === targetName);
                                });
                                if (updated && updated.now_playing) {
                                    win.listeningAlongFriend = updated;
                                    var np = updated.now_playing;
                                    var npVid = np.videoId || np.id || "";
                                    if (npVid.startsWith("yt_")) npVid = npVid.replace(/^yt_/, "");
                                    var curVid = win.currentTrack ? (win.currentTrack.videoId || win.currentTrack.id || "") : "";
                                    if (curVid.startsWith("yt_")) curVid = curVid.replace(/^yt_/, "");

                                    if (npVid && curVid && npVid !== curVid) {
                                        // Host switched to a new track!
                                        win.isSyncingFromFriend = true;
                                        win.startListeningAlong(updated);
                                        win.isSyncingFromFriend = false;
                                    } else if (npVid && curVid && npVid === curVid) {
                                        // Same track: Reconcile Play/Pause and Seek Drift!
                                        win.isSyncingFromFriend = true;

                                        // 1. Play / Pause State Machine Sync
                                        if (np.is_playing === false && win.isPlaying === true) {
                                            win.isPlaying = false;
                                            win.isLoadingAudio = false;
                                            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
                                        } else if (np.is_playing === true && win.isPlaying === false) {
                                            win.isPlaying = true;
                                            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "resume", win.currentTrack.path || ""]);
                                        }

                                        // 2. Real-time Seek Drift Reconciliation (Tua nhạc đồng bộ an toàn)
                                        var expectedPos = Number(np.position || 0);
                                        if (np.is_playing === true && np.timestamp) {
                                            var nowSec = Date.now() / 1000.0;
                                            var recordSec = (np.timestamp > 1000000000000) ? (np.timestamp / 1000.0) : Number(np.timestamp);
                                            var elapsed = nowSec - recordSec;
                                            if (elapsed > 0 && elapsed < (win.totalDuration || 600)) {
                                                expectedPos += elapsed;
                                            }
                                        }
                                        if (win.isLoadingAudio) {
                                            // Đang nạp stream: Chỉ lưu vị trí chờ nạp xong, không tua MPV để tránh reset nạp lại từ đầu!
                                            win.pendingListenAlongSeekPosition = expectedPos;
                                        } else {
                                            var drift = Math.abs(win.currentTime - expectedPos);
                                            if (drift > 2.5 && expectedPos >= 0) {
                                                win.seekLocalOnly(expectedPos);
                                            }
                                        }

                                        win.isSyncingFromFriend = false;
                                    }
                                }
                            }
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.send();

        // Fetch social events fast (instant peer actions: pause, play, seek, leave)
        if (email) {
            var evUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/notes/events?user_email=" + encodeURIComponent(email);
            var evXhr = new XMLHttpRequest();
            evXhr.open("GET", evUrl, true);
            evXhr.onreadystatechange = function() {
                if (evXhr.readyState === XMLHttpRequest.DONE && evXhr.status === 200) {
                    try {
                        var evData = JSON.parse(evXhr.responseText);
                        var events = (evData && Array.isArray(evData.events)) ? evData.events : [];
                        for (var i = 0; i < events.length; i++) {
                            var ev = events[i];
                            if (!ev) continue;
                            if (ev.event === "join") {
                                var jEmail = (ev.from_email || "").trim().toLowerCase();
                                if (jEmail) {
                                    var existing = win.activeCoListeners ? win.activeCoListeners.slice(0) : [];
                                    var isNewListener = (existing.indexOf(jEmail) === -1);
                                    if (isNewListener) {
                                        existing.push(jEmail);
                                        win.activeCoListeners = existing;
                                    }
                                    var jName = ev.from_name || jEmail;
                                    var jAvatar = ev.from_avatar || "";
                                    if (!jAvatar && win.friendsNotes && Array.isArray(win.friendsNotes)) {
                                        var matchNote = win.friendsNotes.find(function(n) {
                                            return (n.user_email && n.user_email.toLowerCase() === jEmail) ||
                                                   (n.user_name && n.user_name === jName);
                                        });
                                        if (matchNote) {
                                            jAvatar = matchNote.avatar_url || "";
                                            if (!ev.from_name && matchNote.user_name) jName = matchNote.user_name;
                                        }
                                    }
                                    var curDetails = win.activeCoListenersDetails ? win.activeCoListenersDetails.slice(0) : [];
                                    var existIdx = curDetails.findIndex(function(d) { return d.email === jEmail; });
                                    if (existIdx === -1) {
                                        curDetails.push({ email: jEmail, name: jName, avatar: jAvatar });
                                    } else {
                                        curDetails[existIdx] = { email: jEmail, name: jName, avatar: jAvatar };
                                    }
                                    win.activeCoListenersDetails = curDetails;

                                    // Chỉ hiện Toast thông báo khi người nghe mới tham gia lần đầu
                                    if (isNewListener) {
                                        win.showToast(I18n.tr(jName + " đang nghe cùng bạn", jName + " is listening along with you"));
                                    }
                                    win.syncNowPlaying(true);
                                    if (win.currentTrack) {
                                        win.sendSocialEventFast(win.isPlaying ? "play" : "pause", jEmail);
                                        win.sendSocialEventFast("seek", jEmail, { position: win.currentTime });
                                    }
                                }
                            } else if (ev.event === "leave" || ev.event === "kick") {
                                var lEmail = (ev.from_email || "").trim().toLowerCase();
                                if (lEmail) {
                                    if (win.activeCoListeners) {
                                        win.activeCoListeners = win.activeCoListeners.filter(function(e) { return (e || "").toLowerCase() !== lEmail; });
                                    }
                                    if (win.activeCoListenersDetails) {
                                        win.activeCoListenersDetails = win.activeCoListenersDetails.filter(function(d) { return (d.email || "").toLowerCase() !== lEmail; });
                                    }
                                    if (coListenersPopover.visible) {
                                        coListenersPopover.openAt(win.activeCoListenersDetails);
                                    }
                                }
                                var fromName = ev.from_name || ev.from_email || I18n.tr("Bạn bè", "Friend");
                                if (win.listeningAlongFriend && (((win.listeningAlongFriend.user_email || "").toLowerCase() === lEmail) || win.listeningAlongFriend.user_name === ev.from_name)) {
                                    win.listeningAlongFriend = null;
                                    var leaveMsg = (ev.event === "kick")
                                        ? I18n.tr("Bạn đã bị mời ra khỏi phòng nghe cùng", "You were removed from the co-listening session")
                                        : I18n.tr(fromName + " đã dừng phát cùng bạn", fromName + " stopped co-listening with you");
                                    win.showToast(leaveMsg);
                                } else {
                                    win.showToast(I18n.tr(fromName + " đã dừng nghe cùng bạn", fromName + " stopped listening along with you"));
                                }
                            } else if (ev.event === "pause") {
                                if (win.isPlaying) {
                                    win.isSyncingFromFriend = true;
                                    win.isPlaying = false;
                                    win.isLoadingAudio = false;
                                    Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
                                    win.isSyncingFromFriend = false;
                                }
                                var pName = ev.from_name || I18n.tr("Bạn bè", "Friend");
                                win.showToast(I18n.tr(pName + " đã tạm dừng bài hát", pName + " paused playback"));
                            } else if (ev.event === "play" || ev.event === "resume") {
                                if (!win.isPlaying && win.currentTrack) {
                                    win.isSyncingFromFriend = true;
                                    win.isPlaying = true;
                                    Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "resume", win.currentTrack.path || ""]);
                                    win.isSyncingFromFriend = false;
                                }
                                var rName = ev.from_name || I18n.tr("Bạn bè", "Friend");
                                win.showToast(I18n.tr(rName + " đã tiếp tục phát bài hát", rName + " resumed playback"));
                            } else if (ev.event === "seek") {
                                var sPos = (ev.data && ev.data.position !== undefined) ? Number(ev.data.position) : (ev.position !== undefined ? Number(ev.position) : -1);
                                if (sPos >= 0) {
                                    win.isSyncingFromFriend = true;
                                    if (win.isLoadingAudio) {
                                        win.pendingListenAlongSeekPosition = sPos;
                                    } else {
                                        win.seekLocalOnly(sPos);
                                    }
                                    win.isSyncingFromFriend = false;
                                    var skName = ev.from_name || I18n.tr("Bạn bè", "Friend");
                                    var timeStr = win.formatPlaybackTime(sPos);
                                    win.showToast(I18n.tr(skName + " đã tua đến " + timeStr, skName + " seeked to " + timeStr));
                                }
                            } else if (ev.event === "track_change") {
                                // CHỈ NGƯỜI NGHE mới nhận lệnh chuyển bài từ Host (Host là người duy nhất điều khiển bài hát)
                                if (ev.data && ev.data.track && win.listeningAlongFriend) {
                                    var newTrk = ev.data.track;
                                    var newVid = newTrk.videoId || newTrk.id || "";
                                    if (newVid.startsWith("yt_")) newVid = newVid.replace(/^yt_/, "");
                                    var myVid = win.currentTrack ? (win.currentTrack.videoId || win.currentTrack.id || "") : "";
                                    if (myVid.startsWith("yt_")) myVid = myVid.replace(/^yt_/, "");
                                    if (newVid !== myVid) {
                                        win.isSyncingFromFriend = true;
                                        win.pendingListenAlongSeekPosition = 0;
                                        win.lastTrackSwitchTimestamp = Date.now();
                                        if ((newTrk.path && newTrk.path.startsWith("ytdl://")) || newTrk.videoId) {
                                            win.playOnlineTrack(newTrk, false);
                                        } else {
                                            win.playTrack(newTrk);
                                        }
                                        win.isSyncingFromFriend = false;
                                        var tcName = ev.from_name || I18n.tr("Host", "Host");
                                        win.showToast(I18n.tr(tcName + " đã chuyển bài hát", tcName + " changed track"));
                                    }
                                }
                            } else if (ev.event === "track_suggest") {
                                if (ev.data && ev.data.track) {
                                    var sFrom = ev.from_name || I18n.tr("Bạn bè", "Friend");
                                    var sAvatar = ev.from_avatar || "";
                                    if (!sAvatar && win.friendsNotes && Array.isArray(win.friendsNotes)) {
                                        var matchS = win.friendsNotes.find(function(n) {
                                            return (ev.from_email && n.user_email && n.user_email.toLowerCase() === ev.from_email.toLowerCase()) ||
                                                   (n.user_name && n.user_name === sFrom);
                                        });
                                        if (matchS) sAvatar = matchS.avatar_url || "";
                                    }
                                    suggestTrackToast.showSuggestion(sFrom, sAvatar, ev.data.track);
                                }
                            } else if (ev.event === "chat_message") {
                                var cFrom = ev.from_name || I18n.tr("Bạn bè", "Friend");
                                var cAvatar = ev.from_avatar || "";
                                var cText = (ev.data && ev.data.text) ? ev.data.text : (ev.data && ev.data.message ? ev.data.message : "");
                                if (!cAvatar && win.friendsNotes && Array.isArray(win.friendsNotes)) {
                                    var matchC = win.friendsNotes.find(function(n) {
                                        return (ev.from_email && n.user_email && n.user_email.toLowerCase() === ev.from_email.toLowerCase()) ||
                                               (n.user_name && n.user_name === cFrom);
                                    });
                                    if (matchC) cAvatar = matchC.avatar_url || "";
                                }
                                if (cText) {
                                    floatingChatContainer.spawnBubble(cFrom, cAvatar, cText);
                                }
                            } else if (ev.event === "friend_request") {
                                win.fetchFriendsDataFast();
                                var frName = ev.from_name || ev.from_email || I18n.tr("Ai đó", "Someone");
                                win.showToast(I18n.tr(frName + " đã gửi lời mời kết bạn", frName + " sent a friend request"));
                            } else if (ev.event === "friend_accepted") {
                                win.fetchFriendsDataFast();
                                win.fetchFriendsNotesFast();
                                var faName = ev.from_name || ev.from_email || I18n.tr("Bạn bè", "Friend");
                                win.showToast(I18n.tr(faName + " đã chấp nhận lời mời kết bạn", faName + " accepted friend request"));
                            } else if (ev.event === "friend_removed") {
                                win.fetchFriendsDataFast();
                                win.fetchFriendsNotesFast();
                            }
                        }
                    } catch(e) {}
                }
            };
            evXhr.send();
        }
    }

    Timer {
        id: friendsNotesTimer
        interval: win.isCoListeningActive ? 800 : 3500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            win.fetchFriendsNotesFast();
            win.syncNowPlaying(false);
        }
    }

    Timer {
        id: friendsSyncTimer
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            win.fetchFriendsDataFast();
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
        if (!res || !res.videoId) return;
        var newTrackItem = {
            title: res.title || (win.currentTrack ? (win.currentTrack.title || win.currentTrack.name) : "Track"),
            name: res.title || (win.currentTrack ? (win.currentTrack.title || win.currentTrack.name) : "Track"),
            artist: res.artist || (win.currentTrack ? win.currentTrack.artist : "Artist"),
            videoId: res.videoId,
            path: "ytdl://" + res.videoId,
            image: win.currentTrack ? (win.currentTrack.image || "") : "",
            type: "track"
        };

        function updateSectionList(secList) {
            if (!secList || !Array.isArray(secList) || secList.length === 0) return secList;
            var updated = secList.slice();
            for (var i = 0; i < updated.length; i++) {
                var s = updated[i];
                if (!s || !s.title || !Array.isArray(s.items)) continue;
                var t = s.title.toLowerCase();
                if (t.includes("listen again") || t.includes("nghe lại") || t.includes("gần đây") || t.includes("recent") || t.includes("history") || i === 0) {
                    var items = s.items.filter(it => (it.videoId && it.videoId !== res.videoId) || (it.title !== res.title));
                    items.unshift(newTrackItem);
                    var newSec = Object.assign({}, s, { items: items });
                    updated[i] = newSec;
                    break;
                }
            }
            return updated;
        }

        if (win.homeSections && win.homeSections.length > 0) {
            win.homeSections = updateSectionList(win.homeSections);
        }

        // Synchronize across active mood, "All" tab, and all cached mood shelves
        if (win.moodCache) {
            for (var m in win.moodCache) {
                if (win.moodCache[m] && win.moodCache[m].sections) {
                    win.moodCache[m].sections = updateSectionList(win.moodCache[m].sections);
                }
            }
        }
    }

    function loadHomeFeed() {
        win.isLoadingHome = true;
        homeLoadingSafetyTimer.restart();
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
        if (win.listeningAlongFriend && !win.isSyncingFromFriend) {
            var hostObj = win.listeningAlongFriend;
            var hostTrack = hostObj.now_playing || hostObj.track;
            var hostVid = hostTrack ? (hostTrack.videoId || hostTrack.id || "") : "";
            if (hostVid.startsWith("yt_")) hostVid = hostVid.replace(/^yt_/, "");
            var myVid = trk.videoId || trk.id || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
            if (myVid.startsWith("yt_")) myVid = myVid.replace(/^yt_/, "");

            // Nếu người nghe chọn bài khác với bài Host đang phát: Chặn lại hoàn toàn, không đụng tới Host!
            if ((hostVid && myVid && hostVid !== myVid) || (win.currentTrack && !win.isSameTrack(win.currentTrack, trk))) {
                var hName = hostObj.user_name || I18n.tr("Host", "Host");
                win.showToast(I18n.tr("Đang nghe cùng " + hName + " (Host điều khiển bài hát)", "Listening along with " + hName + " (Host controls tracks)"));
                return;
            }
        }
        if (!win.isSyncingFromFriend) {
            win.pendingListenAlongSeekPosition = 0.0;
            win.lastTrackSwitchTimestamp = Date.now();
        }
        var rVid = trk.videoId || trk.id || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
        if (rVid && rVid.startsWith("yt_")) {
            rVid = rVid.replace(/^yt_/, "");
        }
        if (!rVid) {
            if (trk.path && !trk.path.startsWith("ytdl://")) {
                win.playTrack(trk);
                return;
            }
            if (trk.title) {
                var searchQuery = trk.title + (trk.artist ? (" " + trk.artist) : "");
                var xhr = new XMLHttpRequest();
                var searchUrl = "http://127.0.0.1:17890/api/filter_search?q=" + encodeURIComponent(searchQuery) + "&filter=songs";
                xhr.open("GET", searchUrl, true);
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            if (Array.isArray(res) && res.length > 0 && (res[0].videoId || res[0].id)) {
                                win.playOnlineTrack(res[0], startRadio);
                            }
                        } catch(e) {
                            console.warn("Nutsty: fallback search parse error", e);
                        }
                    }
                };
                xhr.send();
                return;
            }
            console.warn("Nutsty: playOnlineTrack called without valid videoId or local path", JSON.stringify(trk));
            return;
        }
        if (!trk.videoId && rVid) {
            trk.videoId = rVid;
        }
        if (!trk.path && rVid) {
            trk.path = "ytdl://" + rVid;
        }
        if (!trk.image && trk.cover) {
            trk.image = trk.cover;
        }
        if (win.isLoadingAudio && win.currentTrack && win.isSameTrack(win.currentTrack, trk)) {
            // Already resolving / loading this track, do not spawn duplicate player process
            return;
        }
        if (startRadio === undefined) startRadio = false;
        win.trackChangeTimestamp = Date.now();
        win.postLoadGraceTimestamp = Date.now();
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.isLoadingAudio = true;
        win.totalDuration = 0.0;
        win.isPlaying = true;
        if (win.currentView !== "search") {
            win.showAmberolDetails = true;
        } else {
            win.showAmberolDetails = false;
        }

        if (win.syncHistoryToGoogle) {
            win.trackPlayback(trk);
        }

        if (startRadio || !win.currentTracks || win.currentTracks.length === 0) {
            win.currentTracks = [trk];
        } else {
            var foundIdx = -1;
            for (var qi = 0; qi < win.currentTracks.length; qi++) {
                if (win.isSameTrack(win.currentTracks[qi], trk)) {
                    foundIdx = qi;
                    break;
                }
            }
            if (foundIdx === -1) {
                win.currentTracks = [trk];
            }
        }

        var streamPath = "ytdl://" + rVid;
        var tTitle = trk.title || trk.name || "";
        var tArtist = trk.artist || "";
        var tImage = trk.image || trk.cover || "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "play", streamPath, tTitle, tArtist, tImage]);
        win.syncNowPlaying(true);
        if (!win.isSyncingFromFriend && win.activeCoListeners && win.activeCoListeners.length > 0) {
            for (var cli = 0; cli < win.activeCoListeners.length; cli++) {
                win.sendSocialEventFast("track_change", win.activeCoListeners[cli], { track: trk });
            }
        }

        // Pre-warm the next track after 4s delay so current track has 100% bandwidth to start
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
                prewarmTimer.targetVid = nextVid;
                prewarmTimer.restart();
            }
        }

        if (startRadio && rVid) {
            radioProc.running = false;
            radioProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "radio", rVid];
            radioProc.running = true;
        }
        pollTimer.restart();
    }

    function startRadioFromTrack(trk) {
        if (!trk) return;
        var rVid = trk.videoId || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
        if (!rVid) {
            console.warn("Nutsty: startRadioFromTrack called without valid videoId", JSON.stringify(trk));
            return;
        }
        win.currentTracks = [trk];
        win.playingPlaylistId = "";
        win.playingSourceTitle = "";
        win.playOnlineTrack(trk, true);
    }

    function playFriendTrack(trk) {
        if (!trk) return;
        var rVid = trk.id || trk.videoId || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
        if (rVid) {
            win.currentTracks = [trk];
            win.playingPlaylistId = "";
            win.playingSourceTitle = I18n.tr("Nghe cùng bạn bè", "Listening with friend");
            win.playOnlineTrack(trk, true);
        } else {
            var q = (trk.title || "") + " " + (trk.artist || "");
            if (q.trim()) {
                win.executeSearch(q.trim());
            }
        }
    }

    function postDailyNote(text, track) {
        var cleanText = text ? String(text).replace(/[\r\n]+/g, " ").trim() : "";
        if (!cleanText && !track) return;

        var rId = track ? (track.videoId || track.id || (track.path && track.path.startsWith("ytdl://") ? track.path.replace("ytdl://", "") : "")) : "";
        if (rId && rId.startsWith("yt_")) {
            rId = rId.replace(/^yt_/, "");
        }
        var tCov = track ? win.getTrackCoverUrl(track) : "";
        var tAccent = (track && track.accent_color && String(track.accent_color).trim() !== "")
            ? track.accent_color
            : (win.songAccentColor && win.songAccentColor !== win.wallpaperAccentColor ? win.songAccentColor.toString() : "");

        var trackObj = track ? {
            id: rId,
            videoId: rId,
            path: (rId ? ("ytdl://" + rId) : (track.path || "")),
            title: track.title || track.name || "",
            artist: track.artist || "",
            cover: tCov,
            image: tCov,
            accent_color: tAccent
        } : null;

        var myNp = (win.currentTrack && win.songAccentColor) ? {
            title: win.currentTrack.title || win.currentTrack.name || "",
            artist: win.currentTrack.artist || "",
            cover: win.getTrackCoverUrl(win.currentTrack),
            accent_color: win.songAccentColor ? win.songAccentColor.toString() : ""
        } : null;

        win.myLatestNote = {
            note_text: cleanText,
            track: trackObj,
            accent_color: tAccent,
            now_playing: myNp,
            created_at: new Date().toISOString()
        };

        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var email = win.getCurrentUserEmail();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/notes";

        var payload = {
            profile: profile,
            user_email: email,
            user_name: win.getCurrentUserName(),
            avatar_url: win.getCurrentUserAvatar(),
            note_text: cleanText,
            track: trackObj,
            now_playing: myNp
        };

        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res && res.note) {
                            win.myLatestNote = res.note;
                        }
                    } catch(e) {}
                }
                win.fetchFriendsNotesFast();
                win.fetchFriendsList();
            }
        };
        xhr.send(JSON.stringify(payload));

        postNoteProc.running = false;
        postNoteProc.command = ["python3", "-u", win.appDir + "/backend/social_notes.py", "post", cleanText || " ", JSON.stringify(trackObj || {})];
        postNoteProc.running = true;
        win.syncNowPlaying(true);
        Qt.callLater(function() { win.fetchFriendsNotesFast(); });
    }

    function deleteMyNote() {
        win.myLatestNote = null;
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var email = win.getCurrentUserEmail();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/notes/delete";

        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                win.fetchFriendsNotesFast();
                win.fetchFriendsList();
            }
        };
        xhr.send(JSON.stringify({ profile: profile, user_email: email }));

        deleteNoteProc.running = false;
        deleteNoteProc.command = ["python3", "-u", win.appDir + "/backend/social_notes.py", "delete"];
        deleteNoteProc.running = true;
        Qt.callLater(function() { win.fetchFriendsNotesFast(); });
        win.showToast(I18n.tr("Đã xóa ghi chú", "Note deleted"));
    }

    function promptAddFriend() {
        manageFriendsModal.openModal();
    }

    function sendFriendRequest(targetEmail) {
        var fromEmail = win.getCurrentUserEmail();
        var fromName = win.getCurrentUserName();
        var fromAvatar = win.getCurrentUserAvatar();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/friends/request";

        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.accepted) {
                            win.showToast(I18n.tr("Hai bạn đã trở thành bạn bè!", "You are now friends!"));
                            win.fetchFriendsDataFast();
                            win.fetchFriendsNotesFast();
                        } else {
                            win.showToast(I18n.tr("Đã gửi lời mời kết bạn", "Friend request sent"));
                        }
                    } catch(e) {
                        win.showToast(I18n.tr("Đã gửi lời mời kết bạn", "Friend request sent"));
                    }
                } else {
                    try {
                        var errRes = JSON.parse(xhr.responseText);
                        win.showToast(errRes.error || I18n.tr("Không thể gửi lời mời", "Failed to send request"));
                    } catch(e) {
                        win.showToast(I18n.tr("Lỗi khi gửi lời mời", "Error sending request"));
                    }
                }
            }
        };
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        xhr.send(JSON.stringify({
            profile: profile,
            from_email: fromEmail,
            from_name: fromName,
            from_avatar: fromAvatar,
            to_email: targetEmail
        }));
    }

    function respondFriendRequest(requestId, fromEmail, action) {
        var userEmail = win.getCurrentUserEmail();
        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/friends/respond";

        // Optimistic UI update: Remove pending request immediately so notification popover cleans up instantly (0ms)
        if (win.pendingFriendRequests && Array.isArray(win.pendingFriendRequests)) {
            win.pendingFriendRequests = win.pendingFriendRequests.filter(function(r) {
                var rid = String(r.id || "");
                var targetId = String(requestId || "");
                var rem = (r.from_email || r.from_tag || "").toLowerCase();
                var targetEm = (fromEmail || "").toLowerCase();
                return rid !== targetId && (!targetEm || rem !== targetEm);
            });
            win.unreadFriendRequestsCount = win.pendingFriendRequests.length;
            if (friendRequestsPopover && friendRequestsPopover.isOpen) {
                friendRequestsPopover.requests = win.pendingFriendRequests;
            }
        }

        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    if (action === "accept") {
                        win.showToast(I18n.tr("Đã kết bạn thành công!", "Friend request accepted!"));
                    } else {
                        win.showToast(I18n.tr("Đã từ chối lời mời", "Friend request declined"));
                    }
                    win.fetchFriendsDataFast(function() {
                        win.fetchFriendsNotesFast();
                    });
                } else {
                    win.fetchFriendsDataFast();
                }
            }
        };
        xhr.send(JSON.stringify({
            user_email: userEmail,
            profile: profile,
            request_id: requestId,
            action: action
        }));
    }

    function unfriendUser(targetEmail) {
        if (!targetEmail) return;
        var userEmail = win.getCurrentUserEmail();
        var targetLower = targetEmail.trim().toLowerCase();

        // Optimistic UI Update: Cập nhật biến state ngay lập tức không cần chờ network roundtrip (0ms)
        if (win.friendsList && Array.isArray(win.friendsList)) {
            win.friendsList = win.friendsList.filter(function(e) {
                return (e || "").trim().toLowerCase() !== targetLower;
            });
        }
        if (win.friendsDetails && Array.isArray(win.friendsDetails)) {
            win.friendsDetails = win.friendsDetails.filter(function(f) {
                return (f.email || "").trim().toLowerCase() !== targetLower;
            });
        }
        if (win.friendsNotes && Array.isArray(win.friendsNotes)) {
            win.friendsNotes = win.friendsNotes.filter(function(n) {
                return (n.user_email || "").trim().toLowerCase() !== targetLower;
            });
        }

        var apiUrl = (win.notesApiUrl || "http://127.0.0.1:17890") + "/api/friends/remove";

        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    win.showToast(I18n.tr("Đã hủy kết bạn", "Unfriended"));
                    win.fetchFriendsDataFast();
                    win.fetchFriendsNotesFast();
                }
            }
        };
        xhr.send(JSON.stringify({
            user_email: userEmail,
            target_email: targetEmail
        }));
    }

    function showToast(msg) {
        if (!msg) return;
        win.toastMessage = msg;
        win.toastVisible = true;
        toastTimer.restart();
    }

    function startListeningAlong(friend) {
        if (!friend) return;
        var wasAlreadyListening = (win.listeningAlongFriend !== null && win.listeningAlongFriend !== undefined &&
            ((win.listeningAlongFriend.user_email && friend.user_email && win.listeningAlongFriend.user_email.toLowerCase() === friend.user_email.toLowerCase()) ||
             (win.listeningAlongFriend.user_name && friend.user_name && win.listeningAlongFriend.user_name === friend.user_name)));

        win.listeningAlongFriend = friend;
        var activeTrackObj = null;
        if (friend.now_playing && (friend.now_playing.title || friend.now_playing.name) && friend.now_playing.is_playing !== false) {
            activeTrackObj = friend.now_playing;
        } else if (friend.track && (friend.track.title || friend.track.name)) {
            activeTrackObj = friend.track;
        } else if (friend.now_playing && (friend.now_playing.title || friend.now_playing.name)) {
            activeTrackObj = friend.now_playing;
        }
        if (activeTrackObj) {
            var vid = activeTrackObj.videoId || activeTrackObj.id || activeTrackObj.video_id || "";
            if (vid && vid.startsWith("yt_")) vid = vid.replace(/^yt_/, "");
            var path = activeTrackObj.path || (vid ? ("ytdl://" + vid) : "");
            var trk = {
                id: vid || ("social_" + Date.now()),
                videoId: vid,
                title: activeTrackObj.title || activeTrackObj.name || "Track",
                artist: activeTrackObj.artist || friend.user_name || "Artist",
                image: activeTrackObj.cover || activeTrackObj.image || activeTrackObj.cover_url || activeTrackObj.thumbnail || "",
                cover: activeTrackObj.cover || activeTrackObj.image || activeTrackObj.cover_url || activeTrackObj.thumbnail || "",
                duration: activeTrackObj.duration || 0,
                path: path
            };

            // Tính toán tiến độ thời gian thực 1:1 (SimpMusic realtime sync)
            var targetPos = 0;
            if (activeTrackObj.position !== undefined && activeTrackObj.position !== null) {
                targetPos = Number(activeTrackObj.position);
            } else if (friend.progress_seconds !== undefined) {
                targetPos = Number(friend.progress_seconds);
            }
            var ts = activeTrackObj.timestamp || friend.updated_at_ts || friend.last_updated || 0;
            if (ts > 0 && activeTrackObj.is_playing !== false) {
                var nowSec = Date.now() / 1000.0;
                var recordSec = (ts > 1000000000000) ? (ts / 1000.0) : Number(ts);
                var elapsed = nowSec - recordSec;
                if (elapsed > 0 && elapsed < (trk.duration || 600)) {
                    targetPos += elapsed;
                }
            }

            if (win.currentTrack && win.isSameTrack(win.currentTrack, trk)) {
                if (targetPos > 0 && Math.abs(win.currentTime - targetPos) > 3.0) {
                    if (!win.isLoadingAudio) {
                        win.seekLocalOnly(targetPos);
                    } else {
                        win.pendingListenAlongSeekPosition = targetPos;
                    }
                }
                if (!win.isPlaying) win.togglePlay();
            } else {
                win.pendingListenAlongSeekPosition = targetPos;
                win.isSyncingFromFriend = true;
                win.playOnlineTrack(trk, false);
                win.isSyncingFromFriend = false;
            }
        }
        win.isNowPlayingOpen = true;
        if (!wasAlreadyListening) {
            var friendName = friend.user_name || I18n.tr("Bạn bè", "Friend");
            win.showToast(I18n.tr("Đang nghe cùng " + friendName, "Listening along with " + friendName));
            if (friend.user_email) {
                win.sendSocialEventFast("join", friend.user_email);
            }
        }
    }

    function exitListeningAlong() {
        if (!win.listeningAlongFriend) return;
        var friend = win.listeningAlongFriend;
        var friendEmail = friend.user_email || "";
        var friendName = friend.user_name || I18n.tr("Bạn bè", "Friend");
        win.listeningAlongFriend = null;
        win.showToast(I18n.tr("Đã rời chế độ nghe cùng với " + friendName, "Left listen along with " + friendName));
        if (friendEmail) {
            win.sendSocialEventFast("leave", friendEmail);
        }
    }

    function stopAllCoListening() {
        if (win.activeCoListeners && win.activeCoListeners.length > 0) {
            for (var i = 0; i < win.activeCoListeners.length; i++) {
                win.sendSocialEventFast("leave", win.activeCoListeners[i]);
            }
        }
        win.activeCoListeners = [];
        win.activeCoListenersDetails = [];
        win.showToast(I18n.tr("Đã dừng phát cùng tất cả bạn bè", "Ended co-listening session with all friends"));
    }

    function kickCoListener(kEmail, kName) {
        if (!kEmail) return;
        var cleanEmail = kEmail.toLowerCase().trim();
        if (win.activeCoListeners) {
            win.activeCoListeners = win.activeCoListeners.filter(function(e) { return (e || "").toLowerCase() !== cleanEmail; });
        }
        if (win.activeCoListenersDetails) {
            win.activeCoListenersDetails = win.activeCoListenersDetails.filter(function(d) { return (d.email || "").toLowerCase() !== cleanEmail; });
        }
        win.sendSocialEventFast("kick", kEmail);
        win.sendSocialEventFast("leave", kEmail);
        if (coListenersPopover.visible) {
            coListenersPopover.openAt(win.activeCoListenersDetails);
        }
        var displayName = kName || kEmail;
        win.showToast(I18n.tr("Đã mời " + displayName + " ra khỏi phiên nghe cùng", "Removed " + displayName + " from co-listening session"));
    }

    function suggestTrackToHost(trk) {
        if (!win.listeningAlongFriend || !win.listeningAlongFriend.user_email) return;
        var hostEmail = win.listeningAlongFriend.user_email;
        var hostName = win.listeningAlongFriend.user_name || I18n.tr("Host", "Host");
        win.sendSocialEventFast("track_suggest", hostEmail, { track: trk });
        win.showToast(I18n.tr("Đã gửi đề xuất bài hát cho " + hostName, "Suggested track to " + hostName));
    }

    function sendChatMessage(text) {
        if (!text || text.trim() === "") return;
        var cleanText = text.trim();
        var myName = win.authAccountName;
        if (!myName) {
            var profileN = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
            myName = (profileN === "user2") ? "Hiếu Trần" : (profileN === "user1" ? "Shiraori" : I18n.tr("Tôi", "Me"));
        }
        var myAvatar = win.authAccountAvatar || "";
        if (!myAvatar && win.myLatestNote && win.myLatestNote.avatar_url) {
            myAvatar = win.myLatestNote.avatar_url;
        }

        // 1. Gửi cho Host (nếu mình là Listener)
        if (win.listeningAlongFriend && win.listeningAlongFriend.user_email) {
            win.sendSocialEventFast("chat_message", win.listeningAlongFriend.user_email, { text: cleanText });
        }

        // 2. Gửi cho các Listeners (nếu mình là Host)
        if (win.activeCoListeners && win.activeCoListeners.length > 0) {
            for (var ci = 0; ci < win.activeCoListeners.length; ci++) {
                win.sendSocialEventFast("chat_message", win.activeCoListeners[ci], { text: cleanText });
            }
        }

        // 3. Hiển thị bong bóng bay của chính mình
        floatingChatContainer.spawnBubble(myName, myAvatar, cleanText);
    }

    function playArtistShuffle(artistItem, candidateTracks) {
        if (!artistItem) return;
        var aName = artistItem.name || artistItem.title || artistItem.artist || "";
        var bId = artistItem.browseId || artistItem.channelId || "";
        win.mainSectionTitle = aName;

        // 1. Immediate instant shuffle playback from candidate pool
        var pool = [];
        if (candidateTracks && Array.isArray(candidateTracks) && candidateTracks.length > 0) {
            pool = candidateTracks.slice();
        } else if (artistItem.top_tracks && Array.isArray(artistItem.top_tracks) && artistItem.top_tracks.length > 0) {
            pool = artistItem.top_tracks.slice();
        } else if (artistItem.popular && Array.isArray(artistItem.popular) && artistItem.popular.length > 0) {
            pool = artistItem.popular.slice();
        }

        // Filter out disliked songs
        pool = pool.filter(function(t) {
            if (!t) return false;
            var vid = t.videoId || (t.path && t.path.startsWith("ytdl://") ? t.path.replace("ytdl://", "") : "");
            return (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ? !ytNowPlayingView.isTrackDisliked(vid) : true;
        });

        if (pool.length > 0) {
            var randIdx = Math.floor(Math.random() * pool.length);
            var chosen = pool[randIdx];
            var rest = pool.filter(function(_, idx) { return idx !== randIdx; });
            for (var i = rest.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1));
                var tmp = rest[i];
                rest[i] = rest[j];
                rest[j] = tmp;
            }
            win.currentTracks = [chosen].concat(rest);
            win.playingPlaylistId = "";
            win.playingSourceTitle = aName;
            win.playOnlineTrack(chosen, false);
        }

        // 2. Open Now Playing view and switch to UP NEXT tab (as in Image 5)
        win.isNowPlayingOpen = true;
        if (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) {
            ytNowPlayingView.activeTab = "up_next";
        }

        // 3. Fetch official full YouTube Music artist shuffle playlist in background
        var xhr = new XMLHttpRequest();
        var url = "http://127.0.0.1:17890/api/artist_shuffle?name=" + encodeURIComponent(aName) + "&browseId=" + encodeURIComponent(bId);
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText);
                    var fullTracks = (res && res.tracks) ? res.tracks : (Array.isArray(res) ? res : []);
                    if (fullTracks && fullTracks.length > 0) {
                        var cur = win.currentTrack;
                        if (cur) {
                            var curVid = cur.videoId || (cur.path && cur.path.startsWith("ytdl://") ? cur.path.replace("ytdl://", "") : "");
                            var filtered = fullTracks.filter(function(t) {
                                if (!t) return false;
                                var tVid = t.videoId || (t.path && t.path.startsWith("ytdl://") ? t.path.replace("ytdl://", "") : "");
                                if (curVid && tVid && curVid === tVid) return false;
                                return (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ? !ytNowPlayingView.isTrackDisliked(tVid) : true;
                            });
                            win.currentTracks = [cur].concat(filtered);
                        } else {
                            var rIdx = Math.floor(Math.random() * fullTracks.length);
                            var ch = fullTracks[rIdx];
                            var rRest = fullTracks.filter(function(_, idx) { return idx !== rIdx; });
                            win.currentTracks = [ch].concat(rRest);
                            win.playingPlaylistId = "";
                            win.playOnlineTrack(ch, false);
                        }
                    }
                } catch (e) {
                    console.warn("Nutsty: parse error in artist_shuffle", e);
                }
            }
        };
        xhr.send();
    }

    property var currentAlbumMetadata: null
    property var localAlbums: []

    function refreshLocalAlbums() {
        localAlbumsProc.running = false;
        localAlbumsProc.command = ["python3", "-u", win.appDir + "/backend/library.py", "albums"];
        localAlbumsProc.running = true;
    }

    function addTracksToQueue(tracks) {
        if (!tracks || tracks.length === 0) return;
        var cur = win.currentTracks ? win.currentTracks.slice() : [];
        for (var i = 0; i < tracks.length; i++) {
            cur.push(tracks[i]);
        }
        win.currentTracks = cur;
    }

    function downloadEntireAlbum(tracks) {
        if (!tracks || tracks.length === 0) return;
        for (var i = 0; i < tracks.length; i++) {
            var t = tracks[i];
            if (typeof downloadManager !== "undefined" && downloadManager) {
                downloadManager.enqueueDownload(t);
            }
        }
    }

    function loadArtistDetails(artistNameOrId) {
        if (!artistNameOrId) return;
        var artTarget = String(artistNameOrId).trim();
        if (!artTarget) return;

        if (win.currentView !== "artist") {
            win.artistHistoryStack = [{ view: win.currentView, artist: null }];
        } else if (win.currentArtistData && win.currentArtistData.metadata) {
            win.artistHistoryStack.push({ view: "artist", artist: win.currentArtistData });
        }

        win.previousView = (win.currentView !== "artist") ? win.currentView : win.previousView;
        win.currentView = "artist";
        win.isLoadingArtist = true;
        win.currentArtistData = null;

        artistDetailsProc.running = false;
        artistDetailsProc.targetArtist = artTarget;
        artistDetailsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "artist", artTarget];
        artistDetailsProc.running = true;
    }

    function goBackFromArtist() {
        if (win.artistHistoryStack && win.artistHistoryStack.length > 0) {
            var prev = win.artistHistoryStack.pop();
            if (prev && prev.view === "artist" && prev.artist) {
                win.currentArtistData = prev.artist;
                win.currentView = "artist";
                return;
            } else if (prev && prev.view) {
                win.currentView = prev.view;
                return;
            }
        }
        win.currentView = win.previousView || "home";
    }

    function loadAlbumDetails(alb) {
        if (!alb) return;
        if (typeof alb === "string") alb = { browseId: alb };
        var albId = alb.browseId || alb.playlistId || alb.id || "";
        win.activePlaylistId = albId;
        if (win.currentView !== "search" && win.currentView !== "playlist") {
            win.previousView = win.currentView;
        }
        win.currentView = "playlist";
        win.mainSectionTitle = alb.title || alb.name || "Album";
        mainGrid.sectionTitle = win.mainSectionTitle;

        // If local album:
        if (alb.isLocal || (alb.tracks && alb.tracks.length > 0 && String(albId).startsWith("local_alb_"))) {
            win.currentAlbumMetadata = alb;
            mainGrid.albumMetadata = alb;
            win.browsingTracks = alb.tracks || [];
            win.isSearchingYT = false;
            return;
        }

        win.currentAlbumMetadata = null;
        mainGrid.albumMetadata = null;
        win.browsingTracks = [];
        win.isSearchingYT = true;

        albumDetailsProc.running = false;
        albumDetailsProc.targetTitle = alb.title || alb.name || "Album";
        albumDetailsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "album", albId];
        albumDetailsProc.running = true;
    }

    function loadPlaylistTracks(pl) {
        if (!pl) return;
        var pid = pl.playlistId || pl.id || pl.browseId || "";
        if (!pid) return;

        // Check if Artist
        if (pl.type === "artist" || String(pid).startsWith("UC") || String(pid).startsWith("FEmusic_library_privately_owned_artist_detail")) {
            win.loadArtistDetails(pid || pl.name || pl.title);
            return;
        }

        // Check if Album
        if (String(pid).startsWith("MPREb_") || pl.type === "album" || (pl.isLocal && String(pid).startsWith("local_alb_"))) {
            win.loadAlbumDetails(pl);
            return;
        }

        win.currentAlbumMetadata = null;
        mainGrid.albumMetadata = null;
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
    property string currentResolvedCover: ""
    onCurrentTrackChanged: {
        win.currentResolvedCover = "";
        var coverUrl = win.getTrackCoverUrl(win.currentTrack);
        if (coverUrl) {
            win.fetchSongPalette(coverUrl);
        } else {
            win.songAccentColor = win.wallpaperAccentColor;
        }
        win.syncNowPlaying(true);
    }
    property bool isPlaying: false
    onIsPlayingChanged: {
        if (win.isPlaying && win.currentTrack) {
            var coverUrl = win.getTrackCoverUrl(win.currentTrack);
            if (coverUrl && (!win.songAccentColor || win.songAccentColor === win.wallpaperAccentColor)) {
                win.fetchSongPalette(coverUrl);
            }
        }
        win.syncNowPlaying(true);
    }
    property real currentTime: 0.0
    property real totalDuration: 0.0
    property real volume: 100.0

    property bool isShuffle: false
    property bool isRepeat: false
    property bool isNowPlayingOpen: false
    property alias showAmberolDetails: win.isNowPlayingOpen
    property real widgetX: 60
    property real widgetY: 820

    readonly property var nextTrack: {
        if (!win.currentTrack || !win.currentTracks || win.currentTracks.length <= 1) return null;
        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        if (curIdx === -1) return null;
        var nextIdx = (curIdx + 1) % win.currentTracks.length;
        return win.currentTracks[nextIdx] || null;
    }

    Shortcut {
        sequences: ["F11", "Shift+F11"]
        onActivated: win.maximized = !win.maximized
    }

    Shortcut {
        sequence: "Space"
        enabled: !((searchView && searchView.isInputActiveFocus) || (win.activeFocusItem && (win.activeFocusItem.hasOwnProperty("cursorPosition") || win.activeFocusItem.hasOwnProperty("selectedText"))))
        onActivated: win.togglePlay()
    }

    Component.onCompleted: {
        win.loadHomeFeed();
        win.checkAuthStatus();
        win.loadCustomPlaylists();
        win.refreshLocalAlbums();
        win.fetchFriendsDataFast();
        win.fetchCurrentUserProfile();
    }

    Component.onDestruction: {
        win.sendOfflineSignal();
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
    }

    // Master Container with Nutsty Calm Deep Acrylic Aesthetic
    Rectangle {
        id: masterContainer
        anchors.fill: parent
        radius: (win.maximized || win.fullscreen) ? 0 : 16
        color: Qt.rgba(0.04, 0.04, 0.06, 0.58)
        border.color: "transparent"
        border.width: 0
        clip: true
        focus: true

        // =====================================================================
        // Dynamic Playing Backdrop Cover:
        // 1. PAUSED / STOPPED / IDLE:
        //    Opacity is 0.0. The window is 100% translucent acrylic (masterContainer 0.58),
        //    allowing the desktop wallpaper to be seen directly beneath wherever you move the app.
        // 2. PLAYING MUSIC:
        //    Smoothly transitions in to opacity 1.0 over 900ms (Easing.InOutQuad).
        //    Completely covers the desktop wallpaper underneath with a solid dark foundation,
        //    so the wallpaper and artwork NEVER clash or overlay each other.
        //    Applies ultra-diffuse blur (blurMax: 96) to turn the song's artwork into
        //    a pure, rich, velvet aurora glow.
        // =====================================================================
        Item {
            id: playingBackdropCover
            anchors.fill: parent
            z: 0
            visible: opacity > 0.001
            opacity: (win.currentTrack && win.isPlaying) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.InOutQuad
                }
            }

            // Solid dark base to completely block the desktop wallpaper underneath while playing!
            Rectangle {
                anchors.fill: parent
                color: "#0a0b0e"
            }

            // Song Artwork Atmosphere Wrapper - clipped & zoomed 1.7x to push out YouTube pillarbox/letterbox black bars
            Item {
                id: songAtmosphereWrapper
                anchors.fill: parent
                clip: true
                visible: false

                Image {
                    id: songAtmosphereImg
                    anchors.centerIn: parent
                    width: parent.width * 1.75
                    height: parent.height * 1.75
                    source: win.getTrackCoverUrl(win.currentTrack)
                    sourceSize: Qt.size(512, 512)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Ultra-diffuse Velvet MultiEffect Blur (blurMax: 64)
            MultiEffect {
                id: songAtmosphereEffect
                anchors.fill: parent
                source: songAtmosphereWrapper
                visible: songAtmosphereImg.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 1.45
                brightness: -0.15
                opacity: 0.60
            }

            // Adaptive Dark Scrim (10% reduced opacity for subtle, comfortable ambient blur)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: win.isNowPlayingOpen ? Qt.rgba(0.02, 0.02, 0.04, 0.79) : Qt.rgba(0.02, 0.02, 0.04, 0.70)
                        Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    }
                    GradientStop {
                        position: 0.40
                        color: win.isNowPlayingOpen ? Qt.rgba(0.01, 0.01, 0.02, 0.83) : Qt.rgba(0.01, 0.01, 0.02, 0.76)
                        Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    }
                    GradientStop {
                        position: 1.0
                        color: win.isNowPlayingOpen ? Qt.rgba(0.01, 0.01, 0.02, 0.86) : Qt.rgba(0.01, 0.01, 0.02, 0.81)
                        Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        // Ambient Edge Vignette (Option 2 - Cinematic Spatial Depth)
        Item {
            id: ambientVignette
            anchors.fill: parent
            z: 0
            opacity: 0.35

            // Top subtle shade
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 80
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.0, 0.02, 0.45) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Bottom subtle shade (soft ambient gradient behind floating player bar)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.02, 0.12) }
                }
            }

            // Left edge subtle shade
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 60
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.0, 0.02, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Right edge subtle shade
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 60
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.02, 0.35) }
                }
            }
        }

        // =====================================================================
        // Dynamic Composite Backdrop Source for Liquid Glass (Triple-Tier)
        // Tier 1: Live UI Content & Track Cards (mainContentBackdrop)
        // Tier 2: Active Now Playing Artwork (when music is playing)
        // Tier 3: Desktop Wallpaper (when idle / no music playing)
        // =====================================================================
        Item {
            id: glassCompositeBackdrop
            anchors.fill: parent
            z: -999
            opacity: 0.001

            // 1. Fallback Background Layer (Smooth Cross-dissolving Wallpaper vs Artwork)
            Item {
                id: fallbackBackdropContainer
                anchors.fill: parent

                Item {
                    id: fallbackImagesComposite
                    anchors.fill: parent

                    // Dark foundation underneath to block wallpaper completely when playing
                    Rectangle {
                        anchors.fill: parent
                        color: "#0a0b0e"
                    }

                    // Bottom Layer: Desktop Wallpaper (fades out completely when playing song!)
                    Image {
                        id: fallbackWallpaperImg
                        anchors.fill: parent
                        source: win.currentWallpaperPath ? ("file://" + win.currentWallpaperPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: (win.currentTrack && win.isPlaying) ? 0.0 : 1.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    // Top Layer: Active Song Artwork (Crossfades gently over 400ms)
                    Image {
                        id: fallbackPlayingImg
                        anchors.fill: parent
                        source: win.getTrackCoverUrl(win.currentTrack)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: (win.currentTrack && win.isPlaying) ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: fallbackImagesComposite
                    blurEnabled: true
                    blur: 0.50
                    blurMax: 32
                    saturation: 1.15
                    brightness: 0.02
                }
            }

            // 2. Live Content Layer (Card bài hát, header, etc.)
            ShaderEffectSource {
                id: liveContentTexture
                anchors.fill: parent
                sourceItem: mainContentBackdrop
                live: true
                hideSource: false
                smooth: true
            }
        }

        // =====================================================================
        // Pure Nutsty App Surface (Isolated from Desktop Wallpaper)
        // Used specifically for Modals & Dialogs (SettingsModal, etc.)
        // Ensures the modal's Liquid Glass only blurs Nutsty UI & song cards,
        // without desktop wallpaper bleeding in.
        // =====================================================================
        Item {
            id: nutstyAppSurface
            anchors.fill: parent
            z: -998
            opacity: 0.001

            // 1. Dark Acrylic Window Foundation
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.06, 0.07, 0.10, 0.96)
            }

            // 2. Active Song Atmosphere Aurora Glow (when playing)
            Item {
                anchors.fill: parent
                opacity: (win.currentTrack && win.isPlaying) ? 0.70 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                }

                Image {
                    id: nutstySurfaceArtwork
                    anchors.fill: parent
                    source: win.getTrackCoverUrl(win.currentTrack)
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: nutstySurfaceArtwork
                    visible: nutstySurfaceArtwork.status === Image.Ready
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    saturation: 1.40
                    brightness: -0.20
                }
            }

            // 3. Live UI Content Layer with Rich Frosted Bokeh Blur (MultiEffect blurMax: 64)
            ShaderEffectSource {
                id: liveContentRaw
                anchors.fill: parent
                sourceItem: mainContentBackdrop
                live: true
                hideSource: false
                smooth: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: liveContentRaw
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 1.20
                brightness: -0.10
            }
        }

        // =====================================================================
        // Dedicated Frosted Backdrop for SleepTimerPopover (Deep Bokeh Blur)
        // Blurs underlying lyrics and track cards much more than playerbar
        // for pristine legibility and fluid Keo 502 resin optics.
        // =====================================================================
        Item {
            id: frostedSleepTimerBackdrop
            anchors.fill: parent
            z: -997
            opacity: 0.001

            // 1. Semi-translucent dark foundation for enhanced contrast
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.04, 0.05, 0.08, 0.65)
            }

            // 2. Active Song Atmosphere / Wallpaper with deep blur (blurMax: 64)
            Item {
                id: sleepTimerBgArtworkComposite
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: win.currentWallpaperPath ? ("file://" + win.currentWallpaperPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: (win.currentTrack && win.isPlaying) ? 0.0 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: win.getTrackCoverUrl(win.currentTrack)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: (win.currentTrack && win.isPlaying) ? 0.85 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: sleepTimerBgArtworkComposite
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 1.30
                brightness: -0.05
            }

            // 3. Live UI Content (Lyrics, Cards) heavily blurred (blurMax: 64)
            ShaderEffectSource {
                id: sleepTimerLiveContentRaw
                anchors.fill: parent
                sourceItem: mainContentBackdrop
                live: (typeof sleepTimerPopover !== "undefined" && sleepTimerPopover.opacity > 0.01)
                hideSource: false
                smooth: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: sleepTimerLiveContentRaw
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 1.20
                brightness: -0.10
            }
        }

        // 1. Main Application Backdrop & Scrolling Content
        Item {
            id: mainContentBackdrop
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

            // Top Nutsty Header & Search
            TopHeaderBar {
                id: topHeader
                Layout.fillWidth: true
                currentTab: win.currentTab
                currentView: win.currentView
                isSidebarVisible: win.showSidebar
                isMaximized: win.visibility === 4 || win.maximized
                accentColor: win.accentColor
                backgroundSourceItem: glassCompositeBackdrop

                onHomeClicked: {
                    win.isNowPlayingOpen = false;
                    if (win.currentView !== "home") win.previousView = win.currentView;
                    win.currentView = "home";
                    win.mainSectionTitle = "Home";
                }
                onSearchClicked: {
                    win.isNowPlayingOpen = false;
                    if (win.currentView !== "search") win.previousView = win.currentView;
                    win.currentView = "search";
                    win.searchViewMode = "suggestions";
                    Qt.callLater(function() {
                        if (searchView) searchView.focusInput();
                    });
                }
                onLibraryClicked: {
                    win.isNowPlayingOpen = false;
                    if (win.currentView !== "library") win.previousView = win.currentView;
                    win.currentView = "library";
                    win.currentAlbumMetadata = null;
                    mainGrid.albumMetadata = null;
                    mainGrid.downloadsSubTab = "tracks";
                    libLoader.reload();
                    win.browsingTracks = win.allTracks;
                    win.mainSectionTitle = "Downloads";
                    mainGrid.sectionTitle = "Downloads";
                    win.refreshLocalAlbums();
                }
                onSettingsClicked: {
                    settingsModal.visible = true;
                }
                unreadNotificationsCount: win.unreadFriendRequestsCount
                onNotificationsClicked: (xPos, yPos) => {
                    friendRequestsPopover.toggleAt(win.pendingFriendRequests, xPos, yPos);
                }

                onTabSelected: tab => win.filterByTab(tab)
                onCloseWindowRequested: {
                    if (typeof __NutstyBridge !== "undefined") {
                        Qt.quit();
                    } else {
                        var profile = (Quickshell.env("NUTSTY_PROFILE") || "").toLowerCase();
                        if (profile && profile !== "user1") {
                            win.sendOfflineSignal();
                            Qt.quit();
                        } else {
                            win.visible = false;
                        }
                    }
                }
                onMinimizeWindowRequested: {
                    if (typeof win.showMinimized === "function") {
                        win.showMinimized();
                    } else {
                        win.visibility = 3;
                    }
                }
                onMaximizeWindowRequested: {
                    if (win.visibility === 4) {
                        if (typeof win.showNormal === "function") win.showNormal();
                        else win.maximized = false;
                    } else {
                        if (typeof win.showMaximized === "function") win.showMaximized();
                        else win.maximized = true;
                    }
                }
                onToggleSidebarRequested: {
                    win.showSidebar = !win.showSidebar;
                }

                onBackRequested: {
                    if (win.isNowPlayingOpen) {
                        win.isNowPlayingOpen = false;
                        return;
                    }
                    win.currentAlbumMetadata = null;
                    mainGrid.albumMetadata = null;
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
                            win.browsingTracks = win.allTracks;
                        }
                        if (win.currentView === "search" && (!win.categorizedSearchData || !win.categorizedSearchData.songs || win.categorizedSearchData.songs.length === 0)) {
                            win.searchViewMode = "suggestions";
                        }
                        return;
                    }
                    if (mode === "online" || win.currentView === "home" || win.currentView === "search") {
                        if (win.currentView !== "search" && win.currentView !== "playlist") {
                            win.previousView = win.currentView;
                        }
                        win.currentView = "search";
                        win.searchViewMode = "suggestions";
                        win.lastYTQuery = query;
                    }
                    suggestionsDebounce.restart();
                    if (mode === "offline") {
                        win.filterLocalSearch(query);
                    }
                }

                onSearchSubmitted: (query, mode) => {
                    win.isNowPlayingOpen = false;
                    win.searchViewMode = "results";
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

            // Main Content Area: YouTube Music Split Experience OR Full-Width Browsing
            Item {
                id: mainContentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                clip: true

                // 1. Browsing Area (Home Feed, Local Library/Downloads, or Artist Page)
                Item {
                    id: browsingContainer
                    anchors.fill: parent
                    visible: opacity > 0.01
                    opacity: win.isNowPlayingOpen ? 0.0 : 1.0
                    enabled: !win.isNowPlayingOpen
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    StackLayout {
                        id: centerStack
                        anchors.fill: parent
                        currentIndex: win.currentView === "home" ? 0 : (win.currentView === "artist" ? 2 : (win.currentView === "search" ? 3 : 1))

                        HomeFeedView {
                            id: homeView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            backgroundSourceItem: glassCompositeBackdrop
                            moods: win.homeMoods
                            selectedMood: win.selectedMood
                            sections: win.homeSections
                            quickPicks: win.homeQuickPicks
                            featuredPlaylists: win.homeFeaturedPlaylists
                            isLoading: win.isLoadingHome
                            currentTrack: win.currentTrack
                            isPlaying: win.isPlaying
                            isLoadingAudio: win.isLoadingAudio
                            accentColor: win.accentColor
                            accountName: win.authAccountName
                            accountThumb: win.authAccountThumb
                            friendsNotes: win.friendsNotes
                            myLatestNote: win.myLatestNote

                            onMoodSelected: (title, params) => win.selectMood(title, params)
                            onTrackPlayRequested: trk => {
                                win.startRadioFromTrack(trk);
                            }
                            onPlaySectionRequested: trks => {
                                if (!trks || trks.length === 0) return;
                                win.currentTracks = trks.slice();
                                win.playingPlaylistId = "";
                                win.playingSourceTitle = "";
                                win.startRadioFromTrack(trks[0]);
                            }
                            onPlaylistSelected: pl => win.loadPlaylistTracks(pl)
                            onTrackContextMenuRequested: (trk, gx, gy) => trackContextMenu.openAt(trk, gx, gy, false)
                            onPostNoteRequested: postNoteModal.openModal()
                            onUserNoteDetailRequested: userNoteDetailModal.openModal(win.myLatestNote)
                            onPlayFriendTrackRequested: trk => win.playFriendTrack(trk)
                            onAddFriendRequested: win.promptAddFriend()
                            onOpenStoryRequested: (friendData, idx) => friendStoryModal.openWithIndex(idx)
                        }

                        MainTrackGrid {
                            id: mainGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            tracks: win.browsingTracks
                            currentTrack: win.currentTrack
                            isPlaying: win.isPlaying
                            isLoadingAudio: win.isLoadingAudio
                            sectionTitle: win.mainSectionTitle
                            isLoading: win.isSearchingYT
                            albumMetadata: win.currentAlbumMetadata
                            localAlbums: win.localAlbums
                            accentColor: win.accentColor

                            onAddAlbumToQueueRequested: trks => win.addTracksToQueue(trks)
                            onDownloadAlbumRequested: trks => win.downloadEntireAlbum(trks)
                            onAlbumSelected: alb => win.loadAlbumDetails(alb)

                            onPlayAllRequested: {
                                if (!mainGrid.sortedTracks || mainGrid.sortedTracks.length === 0) return;
                                win.currentTracks = mainGrid.sortedTracks.slice();
                                if (win.currentView === "playlist") {
                                    win.playingPlaylistId = win.activePlaylistId;
                                    win.playingSourceTitle = win.mainSectionTitle;
                                } else {
                                    win.playingPlaylistId = "";
                                    win.playingSourceTitle = (win.currentView === "artist") ? win.mainSectionTitle : "";
                                }
                                var first = win.currentTracks[0];
                                if (first) {
                                    if ((first.path && first.path.startsWith("ytdl://")) || first.videoId) {
                                        win.playOnlineTrack(first, false);
                                    } else {
                                        win.playTrack(first);
                                    }
                                }
                                win.isNowPlayingOpen = true;
                            }
                            onTrackPlayRequested: trk => {
                                if (win.isContextMenuActive) return;
                                if (trk && (trk.type === "album" || (trk.browseId && String(trk.browseId).startsWith("MPREb_")))) {
                                    win.loadAlbumDetails(trk);
                                    return;
                                }
                                if (win.browsingTracks && win.browsingTracks.length > 0) {
                                    win.currentTracks = win.browsingTracks;
                                }
                                if (win.currentView === "playlist") {
                                    win.playingPlaylistId = win.activePlaylistId;
                                    win.playingSourceTitle = win.mainSectionTitle;
                                } else {
                                    win.playingPlaylistId = "";
                                    win.playingSourceTitle = (win.currentView === "artist") ? win.mainSectionTitle : "";
                                }
                                if (trk && ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId)) {
                                    win.playOnlineTrack(trk, false);
                                } else {
                                    win.playTrack(trk);
                                }
                                win.isNowPlayingOpen = true;
                            }
                            onTrackDetailsRequested: trk => {
                                win.currentTrack = trk;
                                win.isNowPlayingOpen = true;
                            }
                            onTrackContextMenuRequested: (trk, gx, gy) => trackContextMenu.openAt(trk, gx, gy, false)
                            onShufflePlayRequested: {
                                win.shufflePlayBrowsing();
                                win.isNowPlayingOpen = true;
                            }
                            onBatchDeleteRequested: paths => win.batchDeleteTracks(paths)
                            onCreatePlaylistRequested: trks => win.createCustomPlaylistFromTracks(trks)
                        }

                        ArtistDetailView {
                            id: artistView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            artistData: win.currentArtistData
                            isLoading: win.isLoadingArtist
                            currentTrack: win.currentTrack
                            isPlaying: win.isPlaying
                            followedArtists: win.followedArtists

                            onBackRequested: win.goBackFromArtist()
                            onPlayTrackRequested: (trk, index, trackList) => {
                                if (win.isContextMenuActive) return;
                                win.currentTracks = trackList.slice();
                                win.playingPlaylistId = "";
                                win.playingSourceTitle = (win.currentArtistData && win.currentArtistData.name) ? win.currentArtistData.name : "";
                                if (trk) {
                                    if ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId) {
                                        win.playOnlineTrack(trk, false);
                                    } else {
                                        win.playTrack(trk);
                                    }
                                }
                                win.isNowPlayingOpen = true;
                            }
                            onStartRadioRequested: item => {
                                if (item && item.id) {
                                    win.startRadioFromTrack(item);
                                    win.isNowPlayingOpen = true;
                                }
                            }
                            onShuffleArtistRequested: artistObj => {
                                win.playArtistShuffle(artistObj ? (artistObj.metadata || artistObj) : null, artistObj ? (artistObj.popular || []) : []);
                            }
                            onViewAlbumRequested: alb => win.loadAlbumDetails(alb)
                            onOpenArtistRequested: (name, chId) => win.loadArtistDetails(chId || name)
                            onTrackContextMenuRequested: (trk, gx, gy) => trackContextMenu.openAt(trk, gx, gy, false)
                            onToggleFollowRequested: (chId, aName, currFollowed) => win.toggleFollowArtist(chId, aName, currFollowed)
                        }

                        CategorizedSearchView {
                            id: searchView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            searchData: win.categorizedSearchData
                            isLoading: win.isSearchingYT
                            currentQuery: win.lastYTQuery
                            accentColor: win.accentColor
                            currentTrack: win.currentTrack
                            isPlaying: win.isPlaying
                            isLoadingAudio: win.isLoadingAudio
                            viewMode: win.searchViewMode
                            backgroundSourceItem: glassCompositeBackdrop

                            onTrackPlayRequested: trk => {
                                if (win.isContextMenuActive) return;
                                if (trk && (trk.type === "album" || (trk.browseId && String(trk.browseId).startsWith("MPREb_")))) {
                                    win.loadAlbumDetails(trk);
                                    return;
                                }
                                if (searchView.activeTab === "songs" && searchView.songsFilterItems && searchView.songsFilterItems.length > 0) {
                                    win.currentTracks = searchView.songsFilterItems;
                                } else if (win.categorizedSearchData && win.categorizedSearchData.songs && win.categorizedSearchData.songs.length > 0) {
                                    win.currentTracks = win.categorizedSearchData.songs;
                                }
                                win.playingPlaylistId = "";
                                win.playingSourceTitle = "";
                                if (trk && ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId)) {
                                    win.playOnlineTrack(trk, false);
                                } else {
                                    win.playTrack(trk);
                                }
                                win.isNowPlayingOpen = false;
                            }
                            onArtistShuffleRequested: (artistItem, candidateTracks) => {
                                win.playArtistShuffle(artistItem, candidateTracks);
                            }
                            onStartRadioRequested: trk => {
                                win.startRadioFromTrack(trk);
                                win.isNowPlayingOpen = false;
                            }
                            onArtistSelected: (aName, bId) => {
                                win.loadArtistDetails(bId || aName);
                            }
                            onAlbumSelected: alb => {
                                win.loadAlbumDetails(alb);
                            }
                            onPlaylistSelected: pl => {
                                win.loadPlaylistTracks(pl);
                            }
                            onTrackContextMenuRequested: (trk, gx, gy) => {
                                trackContextMenu.openAt(trk, gx, gy, false);
                            }
                            onSearchRequested: q => {
                                win.fetchSearchSuggestions(q);
                            }
                            onSearchSubmitted: q => {
                                win.isNowPlayingOpen = false;
                                win.searchViewMode = "results";
                                searchView.viewMode = "results";
                                win.lastYTQuery = q;
                                win.performYTSearch(q);
                            }
                            onSuggestionClicked: q => {
                                win.isNowPlayingOpen = false;
                                win.searchViewMode = "results";
                                searchView.viewMode = "results";
                                win.lastYTQuery = q;
                                win.performYTSearch(q);
                            }
                            onSuggestionFillRequested: q => {
                                searchView.setSearchInput(q);
                            }
                            onBackRequested: {
                                win.currentView = (win.previousView && win.previousView !== "search") ? win.previousView : "home";
                            }
                        }
                    }
                }

                // 2. YouTube Music Split-Screen Now Playing View (Full-Width Experience)
                YTMusicNowPlayingView {
                    id: ytNowPlayingView
                    anchors.fill: parent
                    visible: opacity > 0.01
                    opacity: win.isNowPlayingOpen ? 1.0 : 0.0
                    enabled: win.isNowPlayingOpen
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    track: win.currentTrack
                    animatedCoverEnabled: win.animatedCoverEnabled
                    currentTime: win.currentTime
                    totalDuration: win.totalDuration
                    isPlaying: win.isPlaying
                    queueTracks: win.currentTracks
                    playingPlaylistTitle: win.playingSourceTitle || I18n.tr("Hàng đợi", "Queue")
                    accentColor: win.accentColor
                    backgroundSourceItem: glassCompositeBackdrop
                    listeningAlongFriend: win.listeningAlongFriend

                    onExitListeningAlongRequested: win.exitListeningAlong()
                    onSeekRequested: sec => win.seekAudio(sec)
                    onPlayTrackRequested: (trk, index) => {
                        if (trk && ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId)) {
                            win.playOnlineTrack(trk, false);
                        } else {
                            win.playTrack(trk);
                        }
                    }
                    onTrackContextMenuRequested: (trk, gx, gy, isQ) => trackContextMenu.openAt(trk, gx, gy, isQ)
                    onPlaylistSelected: pl => {
                        win.loadPlaylistTracks(pl);
                        win.isNowPlayingOpen = false;
                    }
                    onArtistSelected: (name, chId) => {
                        win.loadArtistDetails(chId || name);
                        win.isNowPlayingOpen = false;
                    }
                    onCollapseRequested: {
                        win.isNowPlayingOpen = false;
                    }
                    onRateSongRequested: (vid, r) => win.rateSong(vid, r)
                    onSongDisliked: trk => win.handleDislikedTrack(trk)
                    onDownloadRequested: trk => win.downloadTrack(trk)
                    onQueueUpdated: newTracks => { win.currentTracks = newTracks; }
                    onSquareCoverResolved: (url, isSquare) => {
                        if (url) {
                            win.currentResolvedCover = url;
                            win.fetchSongPalette(url);
                        }
                    }
                }
            }
        }
    }

        // 2. Floating Liquid Glass Player Bar (Centered Glass Capsule Dock)
        PlayerBarBottom {
            id: bottomPlayer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(win.isCoListeningActive ? 670 : 600, parent.width - 48)
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            height: 66
            z: 50
            backgroundSourceItem: glassCompositeBackdrop

            currentTrack: win.currentTrack
            resolvedSquareImage: win.currentResolvedCover
            isPlaying: win.isPlaying
            isLoadingAudio: win.isLoadingAudio
            currentTime: win.currentTime
            totalDuration: win.totalDuration
            volume: win.volume
            isShuffle: win.isShuffle
            isRepeat: win.isRepeat
            isLyricsActive: win.isNowPlayingOpen
            isNowPlayingOpen: win.isNowPlayingOpen
            isQueueActive: false
            isSleepTimerActive: win.isSleepTimerActive
            sleepTimerRemainingSeconds: win.sleepTimerRemainingSeconds
            accentColor: win.accentColor
            listeningAlongFriend: win.listeningAlongFriend
            activeCoListenersDetails: win.activeCoListenersDetails

            onPlayPauseClicked: win.togglePlay()
            onNextClicked: win.playNext()
            onPrevClicked: win.playPrev()
            onOpenDetailsRequested: {
                win.isNowPlayingOpen = !win.isNowPlayingOpen;
            }
            onQueueClicked: {
                win.isNowPlayingOpen = !win.isNowPlayingOpen;
            }
            onToggleShuffle: {
                win.isShuffle = !win.isShuffle;
                win.saveSettings();
            }
            onToggleRepeat: {
                win.isRepeat = !win.isRepeat;
                win.saveSettings();
            }
            onOpenArtistRequested: (name, chId) => {
                win.loadArtistDetails(chId || name);
            }
            onSeekRequested: sec => win.seekAudio(sec)
            onReqVolumeChange: vol => win.setVolume(vol)
            onExitListeningAlongRequested: win.exitListeningAlong()
            onOpenCoListenersRequested: (tx, ty) => coListenersPopover.openAt(win.activeCoListenersDetails, tx, ty)
            onSendChatMessageRequested: text => win.sendChatMessage(text)
            onSleepTimerClicked: {
                if (sleepTimerPopover.isOpen) {
                    sleepTimerPopover.close();
                } else {
                    sleepTimerPopover.open();
                }
            }
        }

        // Google Account / Cloud Settings Modal
        SettingsModal {
            id: settingsModal
            backgroundSourceItem: nutstyAppSurface
            isLoggedIn: win.isAuthLoggedIn
            accountName: win.authAccountName
            accountThumb: win.authAccountThumb
            accountEmail: win.authAccountEmail
            syncHistoryToGoogle: win.syncHistoryToGoogle
            desktopLyricsEnabled: win.desktopLyricsEnabled
            animatedCoverEnabled: win.animatedCoverEnabled
            lyricsPreset: win.desktopLyricsPreset
            customX: win.desktopLyricsCustomX
            customY: win.desktopLyricsCustomY
            currentLanguage: win.currentLanguage
            streamingQuality: win.streamingQuality
            downloadQuality: win.downloadQuality

            onCloseRequested: settingsModal.visible = false
            onSelectLanguageRequested: lang => {
                win.currentLanguage = lang;
                I18n.locale = lang;
                win.saveSettings();
            }
            onSelectStreamingQualityRequested: qual => {
                win.streamingQuality = qual;
                win.saveSettings();
                Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "set_streaming_quality", qual]);
            }
            onSelectDownloadQualityRequested: qual => {
                win.downloadQuality = qual;
                win.saveSettings();
            }
            onToggleSyncHistoryRequested: enabled => {
                win.syncHistoryToGoogle = enabled;
                win.saveSettings();
            }
            onToggleAnimatedCoverRequested: enabled => {
                win.animatedCoverEnabled = enabled;
                win.saveSettings();
            }
            onToggleDesktopLyricsRequested: enabled => {
                win.desktopLyricsEnabled = enabled;
                win.saveSettings();
            }
            onSelectLyricsPresetRequested: preset => {
                win.desktopLyricsPreset = preset;
                win.saveSettings();
            }
            onResetLyricsPositionRequested: {
                win.desktopLyricsCustomX = -1;
                win.desktopLyricsCustomY = -1;
                var wpKey = win.getWallpaperKey(win.currentWallpaperPath);
                if (win.desktopLyricsWallpaperPositions && win.desktopLyricsWallpaperPositions[wpKey]) {
                    var updated = Object.assign({}, win.desktopLyricsWallpaperPositions);
                    delete updated[wpKey];
                    win.desktopLyricsWallpaperPositions = updated;
                }
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

        PostNoteModal {
            id: postNoteModal
            backgroundSourceItem: nutstyAppSurface
            currentTrack: win.currentTrack
            resolvedCover: win.currentResolvedCover
            availableTracks: (win.currentTracks && win.currentTracks.length > 0) ? win.currentTracks : (win.browsingTracks && win.browsingTracks.length > 0 ? win.browsingTracks : win.allTracks)
            userAvatar: win.authAccountThumb
            userName: win.authAccountName
            accentColor: win.accentColor
            isPreviewPlaying: win.isPlaying && win.isSameTrack(postNoteModal.previewingTrack, win.currentTrack)
            onCloseRequested: {
                if (postNoteModal.previewingTrack !== null) {
                    postNoteModal.restoreAudioBeforePreviewRequested();
                }
                postNoteModal.visible = false;
            }
            onNoteSubmitted: (text, trk) => {
                if (postNoteModal.previewingTrack !== null) {
                    win.currentTrack = postNoteModal.previewingTrack;
                    win.trackBeforeNotePreview = null;
                    win.wasPlayingBeforeNotePreview = true;
                    postNoteModal.previewingTrack = null;
                }
                win.postDailyNote(text, trk);
                postNoteModal.visible = false;
            }
            onPreviewTrackRequested: trk => {
                if (win.trackBeforeNotePreview === null) {
                    win.trackBeforeNotePreview = win.currentTrack;
                    win.wasPlayingBeforeNotePreview = win.isPlaying;
                    win.queueBeforeNotePreview = win.currentTracks ? win.currentTracks.slice() : [];
                }
                postNoteModal.previewingTrack = trk;
                win.playOnlineTrack(trk, false);
                win.showAmberolDetails = false;
            }
            onTogglePreviewRequested: {
                win.togglePlay();
            }
            onRestoreAudioBeforePreviewRequested: {
                postNoteModal.previewingTrack = null;
                if (win.trackBeforeNotePreview !== null) {
                    if (win.queueBeforeNotePreview !== null) {
                        win.currentTracks = win.queueBeforeNotePreview;
                        win.queueBeforeNotePreview = null;
                    }
                    if (win.wasPlayingBeforeNotePreview) {
                        win.playOnlineTrack(win.trackBeforeNotePreview, false);
                        win.showAmberolDetails = false;
                    } else {
                        if (win.isPlaying) win.togglePlay();
                        win.currentTrack = win.trackBeforeNotePreview;
                    }
                    win.trackBeforeNotePreview = null;
                    win.wasPlayingBeforeNotePreview = false;
                }
            }
        }

        UserNoteDetailModal {
            id: userNoteDetailModal
            backgroundSourceItem: nutstyAppSurface
            userAvatar: win.authAccountThumb
            userName: win.authAccountName
            accentColor: win.accentColor
            isTrackPlaying: win.isPlaying
            onChangeNoteRequested: {
                postNoteModal.openModal();
            }
            onDeleteNoteRequested: {
                win.deleteMyNote();
            }
            onPlayTrackRequested: trk => {
                win.playOnlineTrack(trk, true);
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
            onViewArtistRequested: trk => win.loadArtistDetails(trk.artist || trk.author)
        }

        DownloadManager {
            id: downloadManager
            onTaskCompleted: (videoId, title, path) => {
                libLoader.reload();
                Qt.callLater(function() {
                    libLoader.reload();
                });
            }
        }

        DownloadQueuePopover {
            id: downloadPopover
            dlMgr: downloadManager
            accentColor: win.accentColor
            backgroundSourceItem: glassCompositeBackdrop
        }

        SleepTimerPopover {
            id: sleepTimerPopover
            accentColor: win.accentColor
            backgroundSourceItem: frostedSleepTimerBackdrop
            targetAnchorItem: bottomPlayer
            isTimerActive: win.isSleepTimerActive
            remainingSeconds: win.sleepTimerRemainingSeconds
            timerMode: win.sleepTimerMode

            onSetTimerRequested: (minutes) => {
                win.startSleepTimer(minutes * 60, "duration");
            }
            onSetEndOfTrackRequested: () => {
                win.startSleepTimer(0, "end_of_track");
            }
            onCancelTimerRequested: () => {
                win.cancelSleepTimer();
            }
        }

        FriendStoryModal {
            id: friendStoryModal
            backgroundSourceItem: nutstyAppSurface
            friendsNotes: win.friendsNotes
            accentColor: win.accentColor
            onListenAlongRequested: friendData => {
                win.startListeningAlong(friendData);
            }
            onPlayTrackRequested: trk => {
                win.playOnlineTrack(trk, true);
            }
        }

        CoListenersPopover {
            id: coListenersPopover
            accentColor: win.accentColor
            backgroundSourceItem: glassCompositeBackdrop
            onStopAllRequested: win.stopAllCoListening()
            onKickRequested: (kEmail, kName) => win.kickCoListener(kEmail, kName)
        }

        FriendRequestsPopover {
            id: friendRequestsPopover
            accentColor: win.accentColor
            backgroundSourceItem: glassCompositeBackdrop
            onAcceptRequested: (reqId, fromEmail, fromName) => {
                win.respondFriendRequest(reqId, fromEmail, "accept");
            }
            onRejectRequested: (reqId, fromEmail) => {
                win.respondFriendRequest(reqId, fromEmail, "reject");
            }
        }

        ManageFriendsModal {
            id: manageFriendsModal
            accentColor: win.accentColor
            backgroundSourceItem: glassCompositeBackdrop
            currentUserEmail: win.getCurrentUserEmail()
            currentUserName: win.currentUserName ? win.currentUserName : win.getCurrentUserName()
            currentUserAvatar: win.getCurrentUserAvatar()
            currentUserPin: win.currentUserPin
            currentUserTag: win.currentUserTag
            friends: win.friendsDetails
            onSendFriendRequestRequested: targetEmail => {
                win.sendFriendRequest(targetEmail);
            }
            onUnfriendRequested: targetEmail => {
                win.unfriendUser(targetEmail);
            }
            onRefreshFriendsRequested: {
                win.fetchFriendsDataFast();
                win.fetchCurrentUserProfile();
            }
            onRegeneratePinRequested: {
                win.regenerateUserPin();
            }
        }

        SuggestTrackToast {
            id: suggestTrackToast
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            accentColor: win.accentColor
            onPlayNowRequested: trk => {
                if ((trk.path && trk.path.startsWith("ytdl://")) || trk.videoId) {
                    win.playOnlineTrack(trk, false);
                } else {
                    win.playTrack(trk);
                }
            }
            onPlayNextRequested: trk => {
                win.insertTrackPlayNext(trk);
                win.showToast(I18n.tr("Sẽ phát kế tiếp: " + (trk.title || trk.name || I18n.tr("Bài hát", "Track")), "Will play next: " + (trk.title || trk.name || "Track")));
            }
            onEnqueueRequested: trk => {
                win.appendTrackToQueue(trk);
                win.showToast(I18n.tr("Đã thêm vào hàng đợi", "Added to queue"));
            }
        }

        FloatingChatBubble {
            id: floatingChatContainer
            accentColor: win.accentColor
        }

        // Floating Toast Notification
        Rectangle {
            id: toastNotification
            z: 10000
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.toastVisible ? 24 : -50
            opacity: win.toastVisible ? 1.0 : 0.0
            visible: opacity > 0.01
            height: 38
            width: Math.min(480, toastRow.implicitWidth + 32)
            radius: 19
            color: Qt.rgba(0.08, 0.09, 0.12, 0.92)
            border.color: Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.45)
            border.width: 1
            clip: true

            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: win.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: win.toastMessage
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
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
        path: Quickshell.env("HOME") + "/.config/noctalia/nutsty_settings" + (Quickshell.env("NUTSTY_PROFILE") ? ("_" + Quickshell.env("NUTSTY_PROFILE").toLowerCase()) : "") + ".json"
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

    FileView {
        id: legacySettingsFileView
        path: Quickshell.env("HOME") + "/.config/noctalia/frostify_settings.json"
        onLoadedChanged: {
            if (loaded && (!settingsFileView.loaded || !settingsFileView.text() || settingsFileView.text().trim() === "")) {
                win.loadSettings();
            }
        }
    }

    FileView {
        id: paletteFileView
        path: Quickshell.env("HOME") + "/.config/noctalia/nutsty_palette.json"
        watchChanges: true
        onFileChanged: {
            reload();
            delayedPaletteTimer.restart();
        }
        onLoadedChanged: {
            if (loaded) parsePalette();
        }
        Component.onCompleted: {
            if (loaded) parsePalette();
        }

        function parsePalette() {
            var raw = text();
            if (!raw || raw.trim() === "") return;
            try {
                var p = JSON.parse(raw);
                if (p.wallpaper) {
                    win.currentWallpaperPath = p.wallpaper;
                    win.syncLyricsPositionForWallpaper(p.wallpaper);
                }
                var col = p.highlightColor || p.accentColor || "#deb06c";
                win.wallpaperAccentColor = col;
            } catch(e) {}
        }
    }

    Timer {
        id: delayedPaletteTimer
        interval: 100
        repeat: false
        onTriggered: paletteFileView.parsePalette()
    }

    function loadSettings() {
        var raw = settingsFileView.text();
        if (!raw || raw.trim() === "") {
            raw = legacySettingsFileView.text();
        }
        if (!raw || raw.trim() === "") return;
        try {
            var obj = JSON.parse(raw);
            if (obj.isShuffle !== undefined) win.isShuffle = !!obj.isShuffle;
            if (obj.isRepeat !== undefined) win.isRepeat = !!obj.isRepeat;
            if (obj.syncHistoryToGoogle !== undefined) win.syncHistoryToGoogle = !!obj.syncHistoryToGoogle;
            if (obj.followedArtists !== undefined && Array.isArray(obj.followedArtists)) {
                win.followedArtists = obj.followedArtists;
            }
            if (obj.widgetX !== undefined) win.widgetX = Number(obj.widgetX);
            if (obj.widgetY !== undefined) win.widgetY = Number(obj.widgetY);
            if (obj.desktopLyricsEnabled !== undefined) win.desktopLyricsEnabled = !!obj.desktopLyricsEnabled;
            if (obj.animatedCoverEnabled !== undefined) win.animatedCoverEnabled = !!obj.animatedCoverEnabled;
            if (obj.desktopLyricsPreset !== undefined) win.desktopLyricsPreset = Number(obj.desktopLyricsPreset);
            if (obj.desktopLyricsCustomX !== undefined) win.desktopLyricsCustomX = Number(obj.desktopLyricsCustomX);
            if (obj.desktopLyricsCustomY !== undefined) win.desktopLyricsCustomY = Number(obj.desktopLyricsCustomY);
            if (obj.desktopLyricsWallpaperPositions !== undefined && typeof obj.desktopLyricsWallpaperPositions === "object") {
                win.desktopLyricsWallpaperPositions = obj.desktopLyricsWallpaperPositions;
            }
            if (win.currentWallpaperPath) {
                var curWpKey = win.getWallpaperKey(win.currentWallpaperPath);
                if (win.desktopLyricsWallpaperPositions && win.desktopLyricsWallpaperPositions[curWpKey]) {
                    win.syncLyricsPositionForWallpaper(win.currentWallpaperPath);
                } else if (win.desktopLyricsCustomX >= 0 && win.desktopLyricsCustomY >= 0) {
                    var initWpPos = Object.assign({}, win.desktopLyricsWallpaperPositions || {});
                    initWpPos[curWpKey] = { x: win.desktopLyricsCustomX, y: win.desktopLyricsCustomY };
                    win.desktopLyricsWallpaperPositions = initWpPos;
                }
            }
            if (obj.language !== undefined && (obj.language === "vi" || obj.language === "en")) {
                win.currentLanguage = obj.language;
                I18n.locale = win.currentLanguage;
            } else {
                win.currentLanguage = I18n.locale;
            }
            if (obj.streamingQuality !== undefined && (obj.streamingQuality === "high_opus" || obj.streamingQuality === "high_aac" || obj.streamingQuality === "medium" || obj.streamingQuality === "low")) {
                win.streamingQuality = obj.streamingQuality;
            }
            if (obj.downloadQuality !== undefined && (obj.downloadQuality === "high_opus" || obj.downloadQuality === "high_aac" || obj.downloadQuality === "medium" || obj.downloadQuality === "low")) {
                win.downloadQuality = obj.downloadQuality;
            }
            console.log("DEBUG Nutsty settings loaded: isShuffle=" + win.isShuffle + ", isRepeat=" + win.isRepeat + ", lyricsPreset=" + win.desktopLyricsPreset + ", language=" + win.currentLanguage + ", streamingQuality=" + win.streamingQuality + ", downloadQuality=" + win.downloadQuality);
        } catch(e) {}
    }

    function saveSettings() {
        var data = JSON.stringify({
            isShuffle: win.isShuffle,
            isRepeat: win.isRepeat,
            syncHistoryToGoogle: win.syncHistoryToGoogle,
            followedArtists: win.followedArtists,
            widgetX: win.widgetX,
            widgetY: win.widgetY,
            desktopLyricsEnabled: win.desktopLyricsEnabled,
            animatedCoverEnabled: win.animatedCoverEnabled,
            desktopLyricsPreset: win.desktopLyricsPreset,
            desktopLyricsCustomX: win.desktopLyricsCustomX,
            desktopLyricsCustomY: win.desktopLyricsCustomY,
            desktopLyricsWallpaperPositions: win.desktopLyricsWallpaperPositions,
            language: win.currentLanguage,
            streamingQuality: win.streamingQuality,
            downloadQuality: win.downloadQuality
        });
        var profSuffix = Quickshell.env("NUTSTY_PROFILE") ? ("_" + Quickshell.env("NUTSTY_PROFILE").toLowerCase()) : "";
        Quickshell.execDetached(["python3", "-c",
            "import sys, os\np = os.path.expanduser('~/.config/noctalia/nutsty_settings" + profSuffix + ".json')\nos.makedirs(os.path.dirname(p), exist_ok=True)\nwith open(p, 'w', encoding='utf-8') as f: f.write(sys.argv[1])",
            data
        ]);
    }

    function toggleFollowArtist(channelId, artistName, isCurrentlyFollowed) {
        var chId = channelId || "";
        var aName = artistName || "";
        if (!chId && !aName) return;

        var nextState = !isCurrentlyFollowed;
        var list = win.followedArtists ? win.followedArtists.slice(0) : [];
        if (nextState) {
            var exists = false;
            for (var i = 0; i < list.length; i++) {
                if ((chId && list[i].channelId === chId) || (aName && (list[i].name || "").toLowerCase() === aName.toLowerCase())) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                list.push({ channelId: chId, name: aName, timestamp: Date.now() });
            }
        } else {
            var filtered = [];
            for (var j = 0; j < list.length; j++) {
                if ((chId && list[j].channelId === chId) || (aName && (list[j].name || "").toLowerCase() === aName.toLowerCase())) {
                    continue;
                }
                filtered.push(list[j]);
            }
            list = filtered;
        }
        win.followedArtists = list;
        win.saveSettings();

        // Sync subscription to cloud account if logged in and channelId is available
        if (win.isAuthLoggedIn && chId) {
            Quickshell.execDetached([
                "python3", win.appDir + "/backend/ytmusic_helper.py",
                "subscribe", chId, nextState ? "true" : "false"
            ]);
        }
    }

    FileView {
        id: authChangeFileView
        path: "/tmp/nutsty_auth_changed" + (Quickshell.env("NUTSTY_PROFILE") ? ("_" + Quickshell.env("NUTSTY_PROFILE").toLowerCase()) : "")
        watchChanges: true
        onFileChanged: {
            reload();
            win.checkAuthStatus();
            win.loadHomeFeed();
        }
    }

    FileView {
        id: sessionFileView
        path: "/tmp/nutsty_current_track" + (Quickshell.env("NUTSTY_PROFILE") ? ("_" + Quickshell.env("NUTSTY_PROFILE").toLowerCase()) : "") + ".json"
        watchChanges: false
    }

    // Library Data Loader
    LibraryLoader {
        id: libLoader
        onLoaded: {
            win.playlists = (libLoader.playlists || []).concat(win.customPlaylists || []);
            win.allTracks = libLoader.allTracks;
            if (win.currentView === "library") {
                win.browsingTracks = win.allTracks;
            }
            // Do not auto-populate win.currentTracks with allTracks!
            // Queue remains empty until user explicitly clicks a track, album or playlist.

            if (!statusProcess.running) {
                statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                statusProcess.running = true;
            }
            win.refreshLocalAlbums();
        }
    }

    function selectPlaylist(pid) {
        if (pid === "all") {
            win.browsingTracks = win.allTracks;
            mainGrid.sectionTitle = "Downloads & All Tracks";
        } else if (pid === "simp" || pid === "nutsty") {
            win.browsingTracks = win.allTracks.filter(t => t.source === "Nutsty Music" || t.source === "Nutsty" || t.source === "Nutsty");
            mainGrid.sectionTitle = "Nutsty Tracks";
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
            win.browsingTracks = win.allTracks.filter(t => t.source === "Nutsty Music" || t.source === "Downloads");
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
            win.mainSectionTitle = win.currentTab === "ytmusic" ? "Cloud Stream" : "Downloads";
            mainGrid.sectionTitle = win.mainSectionTitle;
        }
        if (win.currentTab === "ytmusic") {
            win.lastYTQuery = q;
            ytSearchDebounce.restart();
            return;
        }
        if (!q || q.trim() === "") {
            win.browsingTracks = win.allTracks;
            return;
        }
        var lower = q.toLowerCase();
        win.browsingTracks = win.allTracks.filter(t => (t.name && t.name.toLowerCase().includes(lower)) || (t.artist && t.artist.toLowerCase().includes(lower)));
    }

    function playTrack(trk) {
        if (!trk) return;
        if (win.listeningAlongFriend && !win.isSyncingFromFriend) {
            var hostObj2 = win.listeningAlongFriend;
            var hName2 = hostObj2.user_name || I18n.tr("Host", "Host");
            win.showToast(I18n.tr("Đang nghe cùng " + hName2 + " (Host điều khiển bài hát)", "Listening along with " + hName2 + " (Host controls tracks)"));
            return;
        }
        if (!win.isSyncingFromFriend) {
            win.pendingListenAlongSeekPosition = 0.0;
            win.lastTrackSwitchTimestamp = Date.now();
        }
        if (win.currentTrack && win.isSameTrack(win.currentTrack, trk) && win.isPlaying) {
            return;
        }
        win.trackChangeTimestamp = Date.now();
        win.postLoadGraceTimestamp = Date.now(); // Grace period bắt đầu ngay (bài local phát tức thì)
        win.currentTrack = trk;
        win.currentTime = 0.0;
        win.isLoadingAudio = false;
        win.totalDuration = (trk.durationMs || 0) / 1000.0;
        win.isPlaying = true;
        if (win.currentView !== "search") {
            win.isNowPlayingOpen = true;
        } else {
            win.isNowPlayingOpen = false;
        }

        if (win.syncHistoryToGoogle) {
            win.trackPlayback(trk);
        }

        var tTitle = trk.title || trk.name || "";
        var tArtist = trk.artist || "";
        var tImage = trk.image || "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "play", trk.path, tTitle, tArtist, tImage]);
        win.syncNowPlaying(true);
        if (!win.isSyncingFromFriend && win.activeCoListeners && win.activeCoListeners.length > 0) {
            for (var cli2 = 0; cli2 < win.activeCoListeners.length; cli2++) {
                win.sendSocialEventFast("track_change", win.activeCoListeners[cli2], { track: trk });
            }
        }
        pollTimer.restart();
    }

    function togglePlay() {
        if (!win.currentTrack) return;
        var targetPath = win.currentTrack.path || "";
        var isOnline = (targetPath && targetPath.startsWith("ytdl://")) || win.currentTrack.videoId;

        if (win.isLoadingAudio) {
            // User wants to cancel / pause while track is loading
            win.isLoadingAudio = false;
            win.isPlaying = false;
            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
            pollTimer.restart();
            win.syncNowPlaying(true);
            return;
        }

        if (!win.isPlaying) {
            // User is pressing Play from paused/idle state
            win.postLoadGraceTimestamp = Date.now();
            if (isOnline && (win.currentTime === 0.0 || win.totalDuration === 0.0)) {
                win.isLoadingAudio = true;
                win.trackChangeTimestamp = Date.now();
            }
            win.isPlaying = true;
            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "resume", targetPath]);
        } else {
            // User is pressing Pause
            win.isPlaying = false;
            win.isLoadingAudio = false;
            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
        }

        win.syncNowPlaying(true);

        if (!win.isSyncingFromFriend) {
            var evType = win.isPlaying ? "play" : "pause";
            if (win.listeningAlongFriend && win.listeningAlongFriend.user_email) {
                win.sendSocialEventFast(evType, win.listeningAlongFriend.user_email);
            }
            if (win.activeCoListeners && win.activeCoListeners.length > 0) {
                for (var li = 0; li < win.activeCoListeners.length; li++) {
                    win.sendSocialEventFast(evType, win.activeCoListeners[li]);
                }
            }
        }

        pollTimer.restart();
    }

    function playNext() {
        if (win.listeningAlongFriend && !win.isSyncingFromFriend) {
            var hObj = win.listeningAlongFriend;
            var hN = hObj.user_name || I18n.tr("Host", "Host");
            win.showToast(I18n.tr("Chỉ Host mới có quyền chuyển bài hát", "Only the Host can skip tracks"));
            return;
        }
        if (win.isSleepTimerActive && win.sleepTimerMode === "end_of_track") {
            // Guard: sleep timer instructed to stop at end of current track
            win.isSleepTimerActive = false;
            win.sleepTimerFadeTriggered = false;
            win.sleepTimerMode = "";
            win.sleepTimerRemainingSeconds = 0;
            win.isPlaying = false;
            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
            return;
        }
        if (!win.currentTrack || !win.currentTracks || win.currentTracks.length === 0) return;
        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        if (curIdx === -1) return;
        var nextIdx = 0;
        if (win.isShuffle && win.currentTracks.length > 1) {
            nextIdx = curIdx;
            while (nextIdx === curIdx) {
                nextIdx = Math.floor(Math.random() * win.currentTracks.length);
            }
        } else {
            nextIdx = curIdx + 1;
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
        if (win.listeningAlongFriend && !win.isSyncingFromFriend) {
            var hObj3 = win.listeningAlongFriend;
            var hN3 = hObj3.user_name || I18n.tr("Host", "Host");
            win.showToast(I18n.tr("Chỉ Host mới có quyền chuyển bài hát", "Only the Host can skip tracks"));
            return;
        }
        if (!win.currentTrack || !win.currentTracks || win.currentTracks.length === 0) return;
        if (win.currentTime > 3.0) {
            win.seekAudio(0.0);
            return;
        }
        var curIdx = win.currentTracks.findIndex(t => win.isSameTrack(t, win.currentTrack));
        if (curIdx === -1) return;
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

    function seekLocalOnly(sec) {
        win.currentTime = sec;
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "seek", String(sec)]);
    }

    function seekAudio(sec) {
        win.currentTime = sec;
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "seek", String(sec)]);
        win.syncNowPlaying(true);
        if (!win.isSyncingFromFriend) {
            // Chỉ Host mới gửi lệnh seek tới activeCoListeners. Listener tuyệt đối không tua Host!
            if (win.activeCoListeners && win.activeCoListeners.length > 0) {
                for (var si = 0; si < win.activeCoListeners.length; si++) {
                    win.sendSocialEventFast("seek", win.activeCoListeners[si], { position: sec });
                }
            }
        }
    }

    function setVolume(vol) {
        win.volume = vol;
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "volume", String(vol)]);
    }

    function startSleepTimer(seconds, mode) {
        win.sleepTimerMode = mode;
        if (mode === "end_of_track") {
            win.sleepTimerRemainingSeconds = Math.max(0, Math.round(win.totalDuration - win.currentTime));
        } else {
            win.sleepTimerRemainingSeconds = seconds;
        }
        win.sleepTimerFadeTriggered = false;
        win.isSleepTimerActive = true;
    }

    function cancelSleepTimer() {
        win.isSleepTimerActive = false;
        win.sleepTimerFadeTriggered = false;
        win.sleepTimerRemainingSeconds = 0;
        win.sleepTimerMode = "";
        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "cancel_fade"]);
    }

    Timer {
        id: sleepCountdownTimer
        interval: 1000
        repeat: true
        running: win.isSleepTimerActive
        onTriggered: {
            if (!win.isSleepTimerActive) return;

            if (win.sleepTimerMode === "duration") {
                if (win.sleepTimerRemainingSeconds > 0) {
                    win.sleepTimerRemainingSeconds--;
                }

                // Trigger 5-second Cosine Fade at 5s remaining
                if (win.sleepTimerRemainingSeconds === 5 && !win.sleepTimerFadeTriggered) {
                    win.sleepTimerFadeTriggered = true;
                    Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "fade_out_and_pause", "5.0"]);
                } else if (win.sleepTimerRemainingSeconds <= 0) {
                    win.isSleepTimerActive = false;
                    win.sleepTimerFadeTriggered = false;
                    win.sleepTimerMode = "";
                    win.isPlaying = false;
                    Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
                }
            } else if (win.sleepTimerMode === "end_of_track") {
                win.sleepTimerRemainingSeconds = Math.max(0, Math.round(win.totalDuration - win.currentTime));
                if (win.totalDuration > 5) {
                    var remaining = win.totalDuration - win.currentTime;
                    if (remaining <= 5.0 && remaining > 0.4 && !win.sleepTimerFadeTriggered) {
                        win.sleepTimerFadeTriggered = true;
                        Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "fade_out_and_pause", String(Math.max(1.0, remaining))]);
                    }
                }
            }
        }
    }

    function rateSong(vid, rating) {
        if (!vid) return;
        Quickshell.execDetached([
            "python3",
            win.appDir + "/backend/ytmusic_helper.py",
            "rate_song", vid, rating
        ]);
    }

    function handleDislikedTrack(trk) {
        if (!trk) return;
        var vid = trk.videoId || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
        if (vid) {
            rateSong(vid, "DISLIKE");
        }
        // 1. Remove from current playback queue
        var newQueue = [];
        for (var i = 0; i < win.currentTracks.length; i++) {
            var t = win.currentTracks[i];
            var tVid = t.videoId || (t.path && t.path.startsWith("ytdl://") ? t.path.replace("ytdl://", "") : "");
            if (tVid !== vid) {
                newQueue.push(t);
            }
        }
        win.currentTracks = newQueue;

        // 2. Remove from browsing tracks
        var newBrowse = [];
        for (var j = 0; j < win.browsingTracks.length; j++) {
            var bt = win.browsingTracks[j];
            var bVid = bt.videoId || (bt.path && bt.path.startsWith("ytdl://") ? bt.path.replace("ytdl://", "") : "");
            if (bVid !== vid) {
                newBrowse.push(bt);
            }
        }
        win.browsingTracks = newBrowse;

        // 3. Skip to next track immediately
        win.playNext();
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
            win.playingSourceTitle = win.mainSectionTitle;
        } else {
            win.playingPlaylistId = "";
            win.playingSourceTitle = "";
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
        id: prewarmTimer
        interval: 4000
        repeat: false
        property string targetVid: ""
        onTriggered: {
            if (targetVid) {
                Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "prewarm", targetVid]);
            }
        }
    }

    Timer {
        id: pollTimer
        interval: win.isPlaying ? 120 : (win.isLoadingAudio ? 200 : 400)
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
                        // Giữ loading cho đến khi MPV bắt đầu phát bài mục tiêu (!s.is_loading)
                        // HOẶC timeout 20s để tránh spinner treo vĩnh viễn nếu mạng rớt
                        if (elapsed > 20000) {
                            win.isLoadingAudio = false;
                            win.isPlaying = false;
                            return;
                        }
                        var hasStarted = !s.is_loading && (s.is_playing || (s.time_pos && s.time_pos > 0) || (s.duration && s.duration > 0));
                        if (!hasStarted) {
                            win.currentTime = 0.0;
                            return;
                        }
                        // Bài đã thực sự bắt đầu phát!
                        win.isLoadingAudio = false;
                        win.postLoadGraceTimestamp = Date.now();
                        win.isPlaying = true;
                        win.currentTime = s.time_pos || 0.0;
                        if (s.duration !== undefined && s.duration > 0) win.totalDuration = s.duration;
                        if (win.pendingListenAlongSeekPosition > 0) {
                            var p = win.pendingListenAlongSeekPosition;
                            win.pendingListenAlongSeekPosition = 0;
                            win.seekLocalOnly(p);
                        }
                    } else {
                        if (s.is_loading) {
                            win.isLoadingAudio = true;
                            win.trackChangeTimestamp = Date.now();
                            return;
                        }
                        if (s.is_playing) {
                            win.isPlaying = true;
                        } else if (s.is_paused) {
                            win.isPlaying = false;
                        }
                        // During brief file transitions when neither is_playing nor is_paused is true,
                        // preserve win.isPlaying to avoid local bounce and false pause loops!
                        if (s.time_pos !== undefined && s.time_pos > 0) {
                            win.currentTime = s.time_pos;
                        }
                        if (s.duration !== undefined && s.duration > 0) win.totalDuration = s.duration;
                    }


                    // Cold-start recovery
                    if (!win.currentTrack && (s.is_playing || s.is_paused || (s.time_pos && s.time_pos > 0))) {
                        if (s.filename && win.allTracks && win.allTracks.length > 0) {
                            var matched = win.allTracks.find(t => t.path && t.path.endsWith(s.filename));
                            if (matched) win.currentTrack = matched;
                        }
                        if (!win.currentTrack && sessionFileView.loaded && sessionFileView.text()) {
                            try {
                                var sTrack = JSON.parse(sessionFileView.text());
                                if (sTrack && (sTrack.title || sTrack.name)) {
                                    if (!sTrack.image && sTrack.artUrl) sTrack.image = sTrack.artUrl;
                                    if (!sTrack.cover && sTrack.artUrl) sTrack.cover = sTrack.artUrl;
                                    win.currentTrack = sTrack;
                                }
                            } catch(e) {}
                        }
                    }

                    // High-precision fade trigger cho sleep timer
                    if (win.isSleepTimerActive && win.sleepTimerMode === "end_of_track" && win.totalDuration > 5) {
                        var remToEnd = win.totalDuration - win.currentTime;
                        if (remToEnd <= 5.0 && remToEnd > 0.6 && !win.sleepTimerFadeTriggered) {
                            win.sleepTimerFadeTriggered = true;
                            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "fade_out_and_pause", String(Math.max(1.0, remToEnd))]);
                        }
                    }

                    // Auto-advance / Repeat khi hết bài
                    if (!win.isLoadingAudio && win.isPlaying && win.totalDuration > 3 && win.currentTime >= win.totalDuration - 0.5) {
                        if (win.isSleepTimerActive && win.sleepTimerMode === "end_of_track") {
                            win.isSleepTimerActive = false;
                            win.sleepTimerFadeTriggered = false;
                            win.sleepTimerMode = "";
                            win.sleepTimerRemainingSeconds = 0;
                            win.isPlaying = false;
                            Quickshell.execDetached(["python3", win.appDir + "/backend/player_daemon.py", "pause"]);
                        } else if (win.isRepeat) {
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
        target: "nutsty"
        function openWindow() { frostifyIpc.openWindow(); }
        function closeWindow() { frostifyIpc.closeWindow(); }
        function toggle() { frostifyIpc.toggle(); }
        function toggleDetails() { frostifyIpc.toggleDetails(); }
        function openArtwork() { frostifyIpc.openArtwork(); }
        function scrollArtworkDown() { frostifyIpc.scrollArtworkDown(); }
        function dislikeCurrentTrack() { frostifyIpc.dislikeCurrentTrack(); }
        function openSettings() { frostifyIpc.openSettings(); }
        function openLyricsSettings() { frostifyIpc.openLyricsSettings(); }
        function closeSettings() { frostifyIpc.closeSettings(); }
        function toggleStreamingQualityMenu() { frostifyIpc.toggleStreamingQualityMenu(); }
        function toggleDownloadQualityMenu() { frostifyIpc.toggleDownloadQualityMenu(); }
        function showLibrary() { frostifyIpc.showLibrary(); }
        function showHome() { frostifyIpc.showHome(); }
        function selectMood(title: string, params: string) { frostifyIpc.selectMood(title, params); }
        function openContextMenuForTest(isQueue: bool, forceLocal: bool) { frostifyIpc.openContextMenuForTest(isQueue, forceLocal); }
        function closeContextMenu() { frostifyIpc.closeContextMenu(); }
        function openArtist(artistNameOrId: string) { frostifyIpc.openArtist(artistNameOrId); }
        function openAlbum(browseId: string) { frostifyIpc.openAlbum(browseId); }
        function openPlaylist(pid: string, title: string) { frostifyIpc.openPlaylist(pid, title); }
        function setSortByInAlbum(s: string) { frostifyIpc.setSortByInAlbum(s); }
        function goBackFromArtist() { frostifyIpc.goBackFromArtist(); }
        function playTrackByIndex(idx: int) { frostifyIpc.playTrackByIndex(idx); }
        function playBrowsingTrack(idx: int) { frostifyIpc.playBrowsingTrack(idx); }
        function playTrackObj(title: string, artist: string, image: string, path: string) { frostifyIpc.playTrackObj(title, artist, image, path); }
        function switchNowPlayingTab(tab: string) { frostifyIpc.switchNowPlayingTab(tab); }
        function selectNowPlayingMood(index: int) { frostifyIpc.selectNowPlayingMood(index); }
        function testSelectMode() { frostifyIpc.testSelectMode(); }
        function setDownloadsSubTab(tab: string) { frostifyIpc.setDownloadsSubTab(tab); }
        function setSortBy(s: string) { frostifyIpc.setSortBy(s); }
        function toggleMaximize() { frostifyIpc.toggleMaximize(); }
        function togglePlay() { frostifyIpc.togglePlay(); }
        function playNext() { frostifyIpc.playNext(); }
        function playPrev() { frostifyIpc.playPrev(); }
        function typeSearch(q: string) { frostifyIpc.typeSearch(q); }
        function submitSearch(q: string) { frostifyIpc.submitSearch(q); }
        function switchSearchTab(tab: string) { frostifyIpc.switchSearchTab(tab); }
        function toggleSleepTimer() { frostifyIpc.toggleSleepTimer(); }
        function openPostNoteModal() { frostifyIpc.openPostNoteModal(); }
        function closePostNoteModal() { frostifyIpc.closePostNoteModal(); }
        function openUserNoteDetail() { frostifyIpc.openUserNoteDetail(); }
        function closeUserNoteDetail() { frostifyIpc.closeUserNoteDetail(); }
        function openFriendNote(idx: int) { frostifyIpc.openFriendNote(idx); }
        function closeFriendNote() { frostifyIpc.closeFriendNote(); }
        function testListenAlong() { frostifyIpc.testListenAlong(); }
        function testListenAlongFriend(emailOrName: string) { frostifyIpc.testListenAlongFriend(emailOrName); }
        function testExitListenAlong() { frostifyIpc.testExitListenAlong(); }
        function testPlayUserNote() { frostifyIpc.testPlayUserNote(); }
        function testPlayFriendNote() { frostifyIpc.testPlayFriendNote(); }
        function testSeekAudio(sec: real) { frostifyIpc.testSeekAudio(sec); }
        function testSendChatMessage(text: string) { frostifyIpc.testSendChatMessage(text); }
        function testSuggestTrack(title: string, artist: string, videoId: string) { frostifyIpc.testSuggestTrack(title, artist, videoId); }
    }

    IpcHandler {
        id: frostifyIpc
        target: "frostify"
        function testSendChatMessage(text: string) {
            win.sendChatMessage(text);
        }
        function testSuggestTrack(title: string, artist: string, videoId: string) {
            var trk = {
                title: title,
                artist: artist,
                videoId: videoId,
                id: videoId,
                path: "ytdl://" + videoId,
                image: "https://i.ytimg.com/vi/" + videoId + "/hqdefault.jpg"
            };
            win.suggestTrackToHost(trk);
        }
        function testPlayUserNote() {
            if (userNoteDetailModal.attachedTrack) {
                userNoteDetailModal.playTrackRequested(userNoteDetailModal.attachedTrack);
            }
        }
        function testPlayFriendNote() {
            if (friendStoryModal.attachedTrack) {
                friendStoryModal.playTrackRequested(friendStoryModal.attachedTrack);
            }
        }
        function openUserNoteDetail() { userNoteDetailModal.openModal(win.myLatestNote); }
        function closeUserNoteDetail() { userNoteDetailModal.closeModal(); }
        function openFriendNote(idx: int) { friendStoryModal.openWithIndex(idx); }
        function closeFriendNote() { friendStoryModal.close(); }
        function openManageFriends() { manageFriendsModal.openModal(); }
        function closeManageFriends() { manageFriendsModal.closeModal(); }
        function testToggleEditProfile() {
            manageFriendsModal.isEditingProfile = !manageFriendsModal.isEditingProfile;
        }
        function testSaveProfile(newName: string, newDisc: string) {
            win.updateUserProfile(newName, newDisc, function(ok, res) {
                if (ok && res && res.user) {
                    manageFriendsModal.isEditingProfile = false;
                    manageFriendsModal.currentUserName = res.user.username;
                    manageFriendsModal.currentUserPin = res.user.discriminator;
                    manageFriendsModal.currentUserTag = res.user.tag;
                }
            });
        }
        function testOpenNotifications() {
            win.fetchFriendsDataFast(function() {
                friendRequestsPopover.toggleAt(win.pendingFriendRequests, 600, 60);
            });
        }
        function testAcceptRequest(reqId: string, fromEmail: string) {
            win.respondFriendRequest(reqId, fromEmail, "accept");
        }
        function testCloseNotifications() {
            friendRequestsPopover.closePopover();
        }
        function testListenAlong() {
            if (win.friendsNotes && win.friendsNotes.length > 0) {
                var shira = win.friendsNotes.find(f => (f.user_email && f.user_email.indexOf("shiraori") !== -1) || (f.user_name && f.user_name.indexOf("Shiraori") !== -1));
                if (shira) {
                    win.startListeningAlong(shira);
                } else {
                    win.startListeningAlong(win.friendsNotes[0]);
                }
            }
        }
        function testListenAlongFriend(emailOrName: string) {
            if (win.friendsNotes && win.friendsNotes.length > 0) {
                var found = win.friendsNotes.find(f => (f.user_email && f.user_email.toLowerCase() === emailOrName.toLowerCase()) || (f.user_name && f.user_name.toLowerCase() === emailOrName.toLowerCase()));
                if (found) {
                    win.startListeningAlong(found);
                }
            }
        }
        function testExitListenAlong() {
            win.exitListeningAlong();
        }
        function testSeekAudio(sec: real) {
            win.seekAudio(sec);
        }
        function openPostNoteModal() { postNoteModal.openModal(); }
        function openPostNotePicker() { postNoteModal.openModal(); postNoteModal.isPickingTrack = true; }
        function testNoteSearch(query: string) {
            postNoteModal.openModal();
            postNoteModal.isPickingTrack = true;
            postNoteModal.trackSearchQuery = query;
            postNoteModal.performOnlineSearch();
        }
        function testPreviewNoteTrack(index: int) {
            if (postNoteModal.onlineSearchResults && postNoteModal.onlineSearchResults.length > index) {
                var trk = postNoteModal.onlineSearchResults[index];
                postNoteModal.previewTrackRequested(trk);
            }
        }
        function testSelectNoteTrack(index: int) {
            if (postNoteModal.onlineSearchResults && postNoteModal.onlineSearchResults.length > index) {
                var trk = postNoteModal.onlineSearchResults[index];
                postNoteModal.restoreAudioBeforePreviewRequested();
                postNoteModal.attachedTrack = trk;
                postNoteModal.isPickingTrack = false;
            }
        }
        function closePostNoteModal() { postNoteModal.visible = false; }
        function toggleSleepTimer() {
            if (sleepTimerPopover.isOpen) sleepTimerPopover.close();
            else sleepTimerPopover.open();
        }
        function playNext() { win.playNext(); }
        function playPrev() { win.playPrev(); }
        function toggleMaximize() {
            win.maximized = !win.maximized;
        }
        function openWindow() {
            win.visible = true;
            if (!statusProcess.running) {
                statusProcess.command = ["python3", win.appDir + "/backend/player_daemon.py", "status"];
                statusProcess.running = true;
            }
            Qt.callLater(function() { if (ytNowPlayingView) ytNowPlayingView.updateActiveLyric(true); });
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
                Qt.callLater(function() { if (ytNowPlayingView) ytNowPlayingView.updateActiveLyric(true); });
            }
        }
        function toggleDetails() {
            win.isNowPlayingOpen = !win.isNowPlayingOpen;
        }
        function openArtwork() {
            win.visible = true;
            win.isNowPlayingOpen = true;
        }
        function scrollArtworkDown() {
        }
        function dislikeCurrentTrack() {
            win.handleDislikedTrack(win.currentTrack);
        }
        function openSettings() {
            settingsModal.currentTab = 0;
            settingsModal.visible = true;
        }
        function openLyricsSettings() {
            settingsModal.visible = true;
            settingsModal.currentTab = 1;
        }
        function closeSettings() {
            settingsModal.visible = false;
        }
        function toggleStreamingQualityMenu() {
            win.visible = true;
            settingsModal.visible = true;
            settingsModal.currentTab = 0;
            settingsModal.toggleStreamingQualityMenu();
        }
        function toggleDownloadQualityMenu() {
            win.visible = true;
            settingsModal.visible = true;
            settingsModal.currentTab = 0;
            settingsModal.toggleDownloadQualityMenu();
        }
        function showLibrary() {
            win.showAmberolDetails = false;
            if (downloadPopover && downloadPopover.isOpen) downloadPopover.close();
            win.currentView = "library";
            libLoader.reload();
            win.browsingTracks = win.allTracks;
            mainGrid.downloadsSubTab = "tracks";
            mainGrid.sectionTitle = "Downloads";
        }
        function showHome() {
            win.isNowPlayingOpen = false;
            win.showAmberolDetails = false;
            win.currentView = "home";
            homeView.scrollToTop();
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
        function openArtist(artistNameOrId: string) {
            win.visible = true;
            win.loadArtistDetails(artistNameOrId);
        }
        function openAlbum(browseId: string) {
            win.visible = true;
            win.isNowPlayingOpen = false;
            win.loadAlbumDetails(browseId);
        }
        function openPlaylist(pid: string, title: string) {
            win.visible = true;
            win.isNowPlayingOpen = false;
            win.loadPlaylistTracks({ id: pid, playlistId: pid, browseId: pid, title: title || "Playlist" });
        }
        function setSortByInAlbum(s: string) {
            mainGrid.sortBy = s;
        }
        function goBackFromArtist() {
            win.goBackFromArtist();
        }
        function playTrackByIndex(idx: int) {
            if (win.allTracks && idx >= 0 && idx < win.allTracks.length) {
                win.currentTracks = win.allTracks;
                win.playTrack(win.allTracks[idx]);
            }
        }
        function playBrowsingTrack(idx: int) {
            if (win.browsingTracks && idx >= 0 && idx < win.browsingTracks.length) {
                mainGrid.trackPlayRequested(win.browsingTracks[idx]);
            }
        }
        function togglePlay() {
            win.togglePlay();
        }
        function playTrackObj(title: string, artist: string, image: string, path: string) {
            var trk = {
                id: "yt_test",
                title: title,
                name: title,
                artist: artist,
                image: image,
                path: path,
                videoId: (path && path.startsWith("ytdl://")) ? path.replace("ytdl://", "") : ""
            };
            if (path && path.startsWith("ytdl://")) {
                win.playOnlineTrack(trk, false);
            } else {
                win.playTrack(trk);
            }
        }
        function switchNowPlayingTab(tab: string) {
            if (ytNowPlayingView) ytNowPlayingView.activeTab = tab;
        }
        function selectNowPlayingMood(index: int) {
            if (ytNowPlayingView) ytNowPlayingView.selectMoodChip(index);
        }
        function testSelectMode() {
            win.isNowPlayingOpen = false;
            win.currentView = "library";
            win.browsingTracks = win.allTracks;
            mainGrid.sectionTitle = "Downloads";
            mainGrid.isSelectionMode = true;
            if (win.allTracks && win.allTracks.length > 0) {
                mainGrid.selectedTrackPaths = [win.allTracks[0].path];
            }
        }
        function setDownloadsSubTab(tab: string) {
            win.isNowPlayingOpen = false;
            win.currentView = "library";
            mainGrid.sectionTitle = "Downloads";
            mainGrid.downloadsSubTab = tab;
        }
        function setSortBy(s: string) {
            win.isNowPlayingOpen = false;
            win.currentView = "library";
            mainGrid.sectionTitle = "Downloads";
            mainGrid.sortBy = s;
        }
        function typeSearch(q: string) {
            win.visible = true;
            win.isNowPlayingOpen = false;
            win.currentView = "search";
            win.searchViewMode = "suggestions";
            if (searchView) {
                searchView.setSearchInput(q);
                searchView.focusInput();
            }
            win.fetchSearchSuggestions(q);
        }
        function submitSearch(q: string) {
            win.visible = true;
            win.isNowPlayingOpen = false;
            win.currentView = "search";
            if (searchView) {
                searchView.setSearchInput(q);
                searchView.viewMode = "results";
            }
            win.searchViewMode = "results";
            win.performYTSearch(q);
        }
        function switchSearchTab(tab: string) {
            if (searchView) searchView.activeTab = tab;
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
        enabled: win.desktopLyricsEnabled
        lyricsPreset: win.desktopLyricsPreset
        customX: win.desktopLyricsCustomX
        customY: win.desktopLyricsCustomY
        onPositionChanged: (newX, newY) => {
            win.desktopLyricsCustomX = newX;
            win.desktopLyricsCustomY = newY;
            var wpKey = win.getWallpaperKey(win.currentWallpaperPath);
            var updated = Object.assign({}, win.desktopLyricsWallpaperPositions || {});
            updated[wpKey] = { x: newX, y: newY };
            win.desktopLyricsWallpaperPositions = updated;
            win.saveSettings();
        }
        onPlayPauseRequested: win.togglePlay()
        onVolumeChangeRequested: (delta) => {
            var newVol = Math.max(0.0, Math.min(100.0, win.volume + delta));
            win.setVolume(newVol);
        }
    }

    // =========================================================================
    // Nutsty Desktop Music Mini Controller Widget (Layer Bottom)
    // Active when Full Nutsty window is closed/minimized (!win.visible) and track is loaded
    // =========================================================================
    Loader {
        id: desktopMusicWidgetLoader
        active: !win.visible && win.currentTrack !== null
        sourceComponent: Component {
            DesktopMusicWidget {
                currentTrack: win.currentTrack
                nextTrack: win.nextTrack
                currentTime: win.currentTime
                duration: win.totalDuration
                isPlaying: win.isPlaying
                widgetX: win.widgetX
                widgetY: win.widgetY

                onPlayPauseClicked: win.togglePlay()
                onNextClicked: win.playNext()
                onPrevClicked: win.playPrev()
                onSeekRequested: (sec) => win.seekAudio(sec)
                onOpenFullAppRequested: {
                    win.visible = true;
                }
                onSavePositionRequested: (newX, newY) => {
                    win.widgetX = newX;
                    win.widgetY = newY;
                    win.saveSettings();
                }
            }
        }
    }
} // end appScope

