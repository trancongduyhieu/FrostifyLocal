import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: searchRoot
    color: "transparent"

    // Props
    property var searchData: null // { query, top_result, songs, albums, artists, community_playlists, featured_playlists, playlists }
    property var suggestions: []
    property var recommendedSuggestions: []
    property bool isLoading: false
    property string currentQuery: ""
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property var currentTrack: null
    property bool isPlaying: false
    property alias searchInputText: searchTextInput.text

    // State
    property string activeTab: "all" // "all", "songs", "albums", "community_playlists", "featured_playlists", "artists"
    property string viewMode: "results" // "results", "suggestions"
    property var tabResultsCache: ({})
    property bool isTabLoading: false
    property var loadedTabs: ({})

    property var songsFilterItems: []
    property var albumsFilterItems: []
    property var communityPlaylistsFilterItems: []
    property var featuredPlaylistsFilterItems: []
    property var artistsFilterItems: []

    onSearchDataChanged: {
        searchRoot.activeTab = "all";
        searchRoot.viewMode = "results";
        searchRoot.loadedTabs = {};
        realtimeSuggestTimer.stop();
        searchRoot.songsFilterItems = [];
        searchRoot.albumsFilterItems = [];
        searchRoot.communityPlaylistsFilterItems = [];
        searchRoot.featuredPlaylistsFilterItems = [];
        searchRoot.artistsFilterItems = [];
    }

    onActiveTabChanged: {
        if (activeTab !== "all") {
            fetchTabCategory(activeTab);
        }
    }

    // Signals
    signal trackPlayRequested(var trk)
    signal startRadioRequested(var trk)
    signal artistSelected(string artistName, string browseId)
    signal albumSelected(var album)
    signal playlistSelected(var playlist)
    signal trackContextMenuRequested(var trk, real globalX, real globalY)
    signal suggestionClicked(string query)
    signal suggestionFillRequested(string query)
    signal searchRequested(string query)
    signal searchSubmitted(string query)
    signal backRequested()

    function focusInput() {
        searchTextInput.forceActiveFocus();
    }

    property var suggestionsCache: ({})

    function getCurrentSearchQuery() {
        var dt = (searchTextInput.displayText !== undefined && searchTextInput.displayText !== null) ? String(searchTextInput.displayText).trim() : "";
        var pt = (searchTextInput.preeditText !== undefined && searchTextInput.preeditText !== null) ? String(searchTextInput.preeditText).trim() : "";
        var t = (searchTextInput.text !== undefined && searchTextInput.text !== null) ? String(searchTextInput.text).trim() : "";

        if (dt.length > 0 && dt.length >= t.length && dt.length >= pt.length) {
            return dt;
        }
        if (pt.length > 0) {
            if (t.length > 0) return (t + " " + pt).replace(/\s+/g, " ").trim();
            return pt;
        }
        if (t.length > 0) return t;
        return dt;
    }

    function fetchSuggestions(q) {
        if (!q || q.trim() === "") {
            searchRoot.suggestions = [];
            searchRoot.recommendedSuggestions = [];
            return;
        }
        var cleanQ = q.trim();
        if (searchRoot.suggestionsCache && searchRoot.suggestionsCache[cleanQ]) {
            var cached = searchRoot.suggestionsCache[cleanQ];
            searchRoot.suggestions = cached.queries || [];
            searchRoot.recommendedSuggestions = cached.recommended || [];
            return;
        }

        var xhr = new XMLHttpRequest();
        var url = "http://127.0.0.1:17890/api/suggestions?q=" + encodeURIComponent(cleanQ);
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
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
                        if (!searchRoot.suggestionsCache) searchRoot.suggestionsCache = {};
                        searchRoot.suggestionsCache[cleanQ] = { queries: queries, recommended: recs };
                        if (searchRoot.viewMode !== "results") {
                            var curQ = searchRoot.getCurrentSearchQuery().toLowerCase();
                            var targetQ = cleanQ.toLowerCase();
                            if (curQ === targetQ || curQ.startsWith(targetQ) || targetQ.startsWith(curQ)) {
                                searchRoot.suggestions = queries;
                                searchRoot.recommendedSuggestions = recs;
                                searchRoot.viewMode = "suggestions";
                            }
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.send();
    }

    function isTabLoaded(cat) {
        if (cat === "all") return true;
        return !!(searchRoot.loadedTabs && searchRoot.loadedTabs[cat]);
    }

    function fetchTabCategory(cat) {
        var q = searchRoot.currentQuery || (searchRoot.searchData ? searchRoot.searchData.query : "");
        if (!q) return;
        var cleanQ = q.trim();
        var cacheKey = cat + "_" + cleanQ.toLowerCase();
        if (searchRoot.tabResultsCache && searchRoot.tabResultsCache[cacheKey] && searchRoot.tabResultsCache[cacheKey].length > 0) {
            var cached = searchRoot.tabResultsCache[cacheKey];
            if (cat === "songs") searchRoot.songsFilterItems = cached;
            else if (cat === "albums") searchRoot.albumsFilterItems = cached;
            else if (cat === "community_playlists") searchRoot.communityPlaylistsFilterItems = cached;
            else if (cat === "featured_playlists") searchRoot.featuredPlaylistsFilterItems = cached;
            else if (cat === "artists") searchRoot.artistsFilterItems = cached;
            var updatedTabs = Object.assign({}, searchRoot.loadedTabs);
            updatedTabs[cat] = true;
            searchRoot.loadedTabs = updatedTabs;
            return;
        }
        searchRoot.isTabLoading = true;
        var xhr = new XMLHttpRequest();
        var url = "http://127.0.0.1:17890/api/filter_search?q=" + encodeURIComponent(cleanQ) + "&filter=" + encodeURIComponent(cat);
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                searchRoot.isTabLoading = false;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (Array.isArray(res)) {
                            if (!searchRoot.tabResultsCache) searchRoot.tabResultsCache = {};
                            searchRoot.tabResultsCache[cacheKey] = res;
                            if (cat === "songs") searchRoot.songsFilterItems = res;
                            else if (cat === "albums") searchRoot.albumsFilterItems = res;
                            else if (cat === "community_playlists") searchRoot.communityPlaylistsFilterItems = res;
                            else if (cat === "featured_playlists") searchRoot.featuredPlaylistsFilterItems = res;
                            else if (cat === "artists") searchRoot.artistsFilterItems = res;
                            var updatedTabs2 = Object.assign({}, searchRoot.loadedTabs);
                            updatedTabs2[cat] = true;
                            searchRoot.loadedTabs = updatedTabs2;
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.send();
    }

    function getTabItems(cat) {
        if (cat === "songs") return searchRoot.songsFilterItems || [];
        if (cat === "albums") return searchRoot.albumsFilterItems || [];
        if (cat === "community_playlists") return searchRoot.communityPlaylistsFilterItems || [];
        if (cat === "featured_playlists") return searchRoot.featuredPlaylistsFilterItems || [];
        if (cat === "artists") return searchRoot.artistsFilterItems || [];
        return [];
    }

    function setSearchInput(val) {
        searchTextInput.text = val;
        searchTextInput.cursorPosition = val.length;
        if (val && val.trim().length > 0) {
            searchRoot.viewMode = "suggestions";
            searchRoot.fetchSuggestions(val.trim());
        }
    }

    // Timer debounce for instant keystroke search suggestions (< 60ms)
    Timer {
        id: realtimeSuggestTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (searchRoot.viewMode === "results") return;
            var q = searchRoot.getCurrentSearchQuery();
            if (q.length > 0) {
                searchRoot.viewMode = "suggestions";
                searchRoot.fetchSuggestions(q);
                searchRoot.searchRequested(q);
            } else {
                searchRoot.suggestions = [];
                searchRoot.recommendedSuggestions = [];
                searchRoot.viewMode = "suggestions";
            }
        }
    }

    // Helper calculate luminance for capsule text contrast
    readonly property real accentLuminance: {
        var c = searchRoot.accentColor;
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    }
    readonly property color capsuleActiveTextColor: accentLuminance > 0.65 ? "#0f0f11" : "#ffffff"

    // =========================================================================
    // 0. PINNED TOP SEARCH BAR (Dynamic Accent Color Sync)
    // =========================================================================
    Item {
        id: pinnedSearchBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 54
        z: 200

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12

            // Back Button (Synced with dynamic accent color from wallpaper or track cover)
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: backBtnM.containsMouse 
                    ? Qt.rgba(searchRoot.accentColor.r, searchRoot.accentColor.g, searchRoot.accentColor.b, 0.30) 
                    : Qt.rgba(searchRoot.accentColor.r, searchRoot.accentColor.g, searchRoot.accentColor.b, 0.16)
                border.color: Qt.rgba(searchRoot.accentColor.r, searchRoot.accentColor.g, searchRoot.accentColor.b, backBtnM.containsMouse ? 0.60 : 0.32)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    color: searchRoot.accentColor
                }

                MouseArea {
                    id: backBtnM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchRoot.backRequested()
                }
            }

            // Search Input Container (Dark glass pill, borderless or accent on focus)
            Rectangle {
                id: searchInputBox
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: searchTextInput.activeFocus ? Qt.rgba(searchRoot.accentColor.r, searchRoot.accentColor.g, searchRoot.accentColor.b, 0.35) : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    AppIcon {
                        source: "../assets/icons/system-search-symbolic.svg"
                        iconSize: 16
                        color: searchTextInput.activeFocus ? searchRoot.accentColor : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    TextInput {
                        id: searchTextInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: "#ffffff"
                        selectByMouse: true
                        clip: true

                        Text {
                            text: "Tìm kiếm bài hát, album, nghệ sĩ..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textMuted
                            visible: searchRoot.getCurrentSearchQuery().length === 0 && !searchTextInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Real-time suggestions on EVERY keystroke including Vietnamese IME / Fcitx5 preedit
                        onDisplayTextChanged: {
                            if (searchRoot.viewMode !== "results") realtimeSuggestTimer.restart();
                        }
                        onTextEdited: {
                            searchRoot.viewMode = "suggestions";
                            realtimeSuggestTimer.restart();
                        }
                        onTextChanged: {
                            if (searchRoot.viewMode !== "results") realtimeSuggestTimer.restart();
                        }
                        onPreeditTextChanged: {
                            searchRoot.viewMode = "suggestions";
                            realtimeSuggestTimer.restart();
                        }
                        onInputMethodComposingChanged: {
                            if (searchRoot.viewMode !== "results") realtimeSuggestTimer.restart();
                        }

                        onAccepted: {
                            realtimeSuggestTimer.stop();
                            var q = searchRoot.getCurrentSearchQuery();
                            if (q.length > 0) {
                                searchRoot.viewMode = "results";
                                searchRoot.searchSubmitted(q);
                            }
                        }

                        Keys.onEscapePressed: {
                            if (searchRoot.getCurrentSearchQuery().length > 0) {
                                text = "";
                                searchRoot.suggestions = [];
                                searchRoot.recommendedSuggestions = [];
                            } else {
                                searchRoot.backRequested();
                            }
                        }
                    }

                    // Clear button
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        visible: searchRoot.getCurrentSearchQuery().length > 0

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/window-close-symbolic.svg"
                            iconSize: 12
                            color: clearBtnM.containsMouse ? "#ffffff" : Theme.textMuted
                        }

                        MouseArea {
                            id: clearBtnM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchTextInput.text = "";
                                searchTextInput.forceActiveFocus();
                                searchRoot.suggestions = [];
                                searchRoot.recommendedSuggestions = [];
                                searchRoot.viewMode = "suggestions";
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 1. SUGGESTIONS VIEW (Multi-entity: Artist circle, Album/Song square)
    // =========================================================================
    Flickable {
        id: suggestionsFlickable
        anchors.top: pinnedSearchBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 80
        contentWidth: width
        contentHeight: suggestionsCol.height + 20
        clip: true
        visible: searchRoot.viewMode === "suggestions" && ((searchRoot.suggestions && searchRoot.suggestions.length > 0) || (searchRoot.recommendedSuggestions && searchRoot.recommendedSuggestions.length > 0))
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: suggestionsCol
            width: parent.width
            spacing: 4

            // Section 1: Recommended Top Entities (Artist, Album, Song)
            Text {
                text: "Gợi ý hàng đầu"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textMuted
                leftPadding: 8
                bottomPadding: 4
                visible: searchRoot.recommendedSuggestions && searchRoot.recommendedSuggestions.length > 0
            }

            Repeater {
                model: searchRoot.recommendedSuggestions

                delegate: Rectangle {
                    id: recEntityRow
                    width: suggestionsCol.width
                    height: 52
                    radius: 8
                    color: recEntityM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    readonly property bool isArtist: modelData.type === "artist"
                    readonly property bool isAlbum: modelData.type === "album"
                    readonly property bool isSong: modelData.type === "song"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 12

                        // Thumbnail (Round for Artist, Rounded rect for Album/Song)
                        Item {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                id: recMask
                                anchors.fill: parent
                                radius: recEntityRow.isArtist ? 20 : 6
                                visible: false
                                layer.enabled: true
                            }

                            Image {
                                id: recImg
                                anchors.fill: parent
                                source: modelData.image || ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 80
                                sourceSize.height: 80
                                asynchronous: true
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: recImg
                                maskEnabled: true
                                maskSource: recMask
                                visible: recImg.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: recEntityRow.isArtist ? 20 : 6
                                color: Qt.rgba(1, 1, 1, 0.08)
                                visible: recImg.status !== Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: recEntityRow.isArtist ? 20 : 6
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1
                            }
                        }

                        // Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || modelData.name || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: recEntityM.containsMouse ? searchRoot.accentColor : "#ffffff"
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (recEntityRow.isArtist) return modelData.subtitle || "Nghệ sĩ";
                                    if (recEntityRow.isAlbum) return modelData.subtitle || "Album";
                                    return modelData.artist || modelData.subtitle || "";
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: recEntityM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            realtimeSuggestTimer.stop();
                            if (recEntityRow.isArtist) {
                                searchRoot.artistSelected(modelData.name || modelData.title, modelData.browseId || modelData.id);
                            } else if (recEntityRow.isAlbum) {
                                searchRoot.albumSelected(modelData);
                            } else {
                                searchRoot.trackPlayRequested(modelData);
                            }
                        }
                    }
                }
            }

            // Section 2: Search Queries (Keywords)
            Text {
                text: "Từ khóa tìm kiếm"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textMuted
                leftPadding: 8
                topPadding: 10
                bottomPadding: 4
                visible: searchRoot.suggestions && searchRoot.suggestions.length > 0
            }

            Repeater {
                model: searchRoot.suggestions

                delegate: Rectangle {
                    id: sugRow
                    width: suggestionsCol.width
                    height: 44
                    radius: 8
                    color: sugRowM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 12

                        AppIcon {
                            source: "../assets/icons/system-search-symbolic.svg"
                            iconSize: 15
                            color: sugRowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: sugRowM.containsMouse ? "#ffffff" : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        // ArrowOutward button to fill text
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: arrowM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/arrow-outward-symbolic.svg"
                                iconSize: 13
                                color: arrowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                                scale: arrowM.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: arrowM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    searchRoot.suggestionFillRequested(modelData);
                                    searchTextInput.text = modelData;
                                    searchTextInput.cursorPosition = modelData.length;
                                    searchTextInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: sugRowM
                        anchors.fill: parent
                        anchors.rightMargin: 40
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            realtimeSuggestTimer.stop();
                            searchRoot.viewMode = "results";
                            searchRoot.suggestionClicked(modelData);
                            searchTextInput.text = modelData;
                            searchRoot.searchSubmitted(modelData);
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. CATEGORIZED RESULTS VIEW (Search Summary / Filter Tabs)
    // =========================================================================
    ColumnLayout {
        anchors.top: pinnedSearchBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 76
        spacing: 12
        visible: searchRoot.viewMode === "results"

        // Filter Chips Bar (Glossy Gel Capsules + Reset Filter Chip)
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            contentWidth: chipsRow.width + 10
            contentHeight: 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: chipsRow
                spacing: 8

                // Reset Filter Button [ ✕ ] (Shown when not in "all" tab)
                Rectangle {
                    height: 30
                    width: 30
                    radius: 15
                    visible: searchRoot.activeTab !== "all"
                    color: resetM.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 11
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: resetM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchRoot.activeTab = "all"
                    }
                }

                Repeater {
                    model: [
                        { id: "all", label: "Tất cả" },
                        { id: "songs", label: "Bài hát" },
                        { id: "albums", label: "Albums" },
                        { id: "community_playlists", label: "Danh sách phát cộng đồng" },
                        { id: "featured_playlists", label: "Danh sách phát nổi bật" },
                        { id: "artists", label: "Nghệ sĩ" }
                    ]

                    delegate: Rectangle {
                        id: chipPill
                        height: 30
                        width: chipText.implicitWidth + 24
                        radius: 15
                        readonly property bool isSelected: searchRoot.activeTab === modelData.id

                        color: isSelected ? searchRoot.accentColor : (chipM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: isSelected ? Qt.rgba(1, 1, 1, 0.45) : (chipM.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: chipPill.isSelected ? Font.Bold : Font.Medium
                            color: chipPill.isSelected ? searchRoot.capsuleActiveTextColor : Theme.textPrimary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: chipM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (searchRoot.activeTab === modelData.id) {
                                    searchRoot.activeTab = "all";
                                } else {
                                    searchRoot.activeTab = modelData.id;
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SKELETON SHIMMER LOADING STATE
        // =====================================================================
        Flickable {
            id: skeletonScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: skeletonCol.height + 20
            clip: true
            visible: searchRoot.isLoading
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: skeletonCol
                width: parent.width
                spacing: 16

                // Hero Top Result Skeleton
                Rectangle {
                    width: Math.min(parent.width, 540)
                    height: 140
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    clip: true

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: searchRoot.isLoading
                        NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.70; duration: 650; easing.type: Easing.InOutQuad }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 16

                        Rectangle {
                            width: 104
                            height: 104
                            radius: 52
                            color: Qt.rgba(1, 1, 1, 0.12)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle { width: 110; height: 14; radius: 7; color: Qt.rgba(1, 1, 1, 0.14) }
                            Rectangle { width: 220; height: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.20) }
                            Rectangle { width: 140; height: 12; radius: 6; color: Qt.rgba(1, 1, 1, 0.10) }
                        }
                    }
                }

                // 4 Song Skeleton Rows
                Column {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: 4
                        SkeletonTrackRow { width: skeletonCol.width }
                    }
                }
            }
        }

        // =====================================================================
        // REAL CONTENT SCROLLABLE BODY
        // =====================================================================
        Flickable {
            id: contentScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: contentCol.height + 30
            clip: true
            visible: !searchRoot.isLoading
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                width: parent.width
                spacing: 24

                // -------------------------------------------------------------
                // SECTION: TAB "ALL" (Desktop 2-Column Hero + Carousels)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: allSummaryCol.height
                    visible: searchRoot.activeTab === "all"

                    Column {
                        id: allSummaryCol
                        width: parent.width
                        spacing: 28

                        // 1. HERO TOP RESULT & TOP SONGS (Desktop 2-Column Connected Hero Grid)
                        Item {
                            width: parent.width
                            height: heroCol.implicitHeight
                            visible: !!(searchRoot.searchData && (searchRoot.searchData.top_result || (searchRoot.searchData.songs && searchRoot.searchData.songs.length > 0)))

                            readonly property bool isWide: parent.width >= 750

                            ColumnLayout {
                                id: heroCol
                                width: parent.width
                                spacing: 12

                                Text {
                                    text: "Kết quả hàng đầu"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                ShinyCardContainer {
                                    id: topResultUnifiedCard
                                    Layout.preferredWidth: heroCol.parent.isWide ? Math.min(heroCol.width, 760) : heroCol.width
                                    Layout.fillWidth: !heroCol.parent.isWide
                                    Layout.alignment: Qt.AlignLeft
                                    implicitHeight: heroCol.parent.isWide ? 194 : (topHeroRow.implicitHeight + (topResultUnifiedCard.hasTopTracks ? (topTracksWideCol.implicitHeight + 20) : 0) + 32)
                                    accentColor: searchRoot.accentColor
                                    radius: 16
                                    borderWidth: 1.5

                                    readonly property var topItem: searchRoot.searchData ? searchRoot.searchData.top_result : null
                                    readonly property bool hasTopResult: !!topItem
                                    readonly property bool isArtist: topItem && topItem.type === "artist"
                                    readonly property bool isSong: topItem && topItem.type === "song"
                                    readonly property bool isAlbum: topItem && topItem.type === "album"

                                    readonly property var topTracksModel: {
                                        if (topItem && topItem.top_tracks && topItem.top_tracks.length > 0) {
                                            return topItem.top_tracks.slice(0, 3);
                                        }
                                        if (searchRoot.searchData && searchRoot.searchData.songs && searchRoot.searchData.songs.length > 0) {
                                            return searchRoot.searchData.songs.slice(0, 3);
                                        }
                                        return [];
                                    }
                                    readonly property bool hasTopTracks: topTracksModel && topTracksModel.length > 0

                                    // Unified Content: Responsive Layout (Side-by-side in wide view, stacked in narrow view)
                                    GridLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        columns: (heroCol.parent.isWide && topResultUnifiedCard.hasTopResult && topResultUnifiedCard.hasTopTracks) ? 3 : 1
                                        columnSpacing: 14
                                        rowSpacing: 10

                                        // =================================================
                                        // LEFT: TOP RESULT (ARTIST / ALBUM / SONG HERO)
                                        // =================================================
                                        RowLayout {
                                            id: topHeroRow
                                            Layout.preferredWidth: (heroCol.parent.isWide && topResultUnifiedCard.hasTopTracks) ? 310 : -1
                                            Layout.fillWidth: !heroCol.parent.isWide || !topResultUnifiedCard.hasTopTracks
                                            Layout.fillHeight: heroCol.parent.isWide
                                            spacing: 14
                                            visible: topResultUnifiedCard.hasTopResult

                                            // Thumbnail / Round Avatar
                                            Item {
                                                Layout.preferredWidth: 92
                                                Layout.preferredHeight: 92
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    id: artMask
                                                    anchors.fill: parent
                                                    radius: topResultUnifiedCard.isArtist ? 46 : 12
                                                    color: "#ffffff"
                                                    visible: false
                                                    layer.enabled: true
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    layer.enabled: true
                                                    layer.effect: MultiEffect {
                                                        maskEnabled: true
                                                        maskSource: artMask
                                                        autoPaddingEnabled: false
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: "#202024"
                                                        visible: topThumb.status !== Image.Ready
                                                    }

                                                    Image {
                                                        id: topThumb
                                                        anchors.fill: parent
                                                        source: topResultUnifiedCard.topItem ? (topResultUnifiedCard.topItem.image || "") : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        sourceSize: Qt.size(192, 192)
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: topResultUnifiedCard.isArtist ? 46 : 12
                                                    color: topThumbM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                                    border.color: Qt.rgba(1, 1, 1, 0.18)
                                                    border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 120 } }
                                                }

                                                MouseArea {
                                                    id: topThumbM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (!topResultUnifiedCard.topItem) return;
                                                        if (topResultUnifiedCard.isArtist) {
                                                            searchRoot.artistSelected(topResultUnifiedCard.topItem.name, topResultUnifiedCard.topItem.browseId);
                                                        } else if (topResultUnifiedCard.isAlbum) {
                                                            searchRoot.albumSelected(topResultUnifiedCard.topItem);
                                                        } else {
                                                            searchRoot.trackPlayRequested(topResultUnifiedCard.topItem);
                                                        }
                                                    }
                                                }
                                            }

                                            // Details & Action Buttons
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 4

                                                // Name / Title
                                                Text {
                                                    id: topResultTitleText
                                                    Layout.fillWidth: true
                                                    text: topResultUnifiedCard.topItem ? (topResultUnifiedCard.topItem.name || topResultUnifiedCard.topItem.title || "") : ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 20
                                                    font.weight: Font.Bold
                                                    color: topResultTitleM.containsMouse ? searchRoot.accentColor : Theme.textPrimary
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 100 } }

                                                    MouseArea {
                                                        id: topResultTitleM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (!topResultUnifiedCard.topItem) return;
                                                            if (topResultUnifiedCard.isArtist) {
                                                                searchRoot.artistSelected(topResultUnifiedCard.topItem.name, topResultUnifiedCard.topItem.browseId);
                                                            } else if (topResultUnifiedCard.isAlbum) {
                                                                searchRoot.albumSelected(topResultUnifiedCard.topItem);
                                                            } else {
                                                                searchRoot.trackPlayRequested(topResultUnifiedCard.topItem);
                                                            }
                                                        }
                                                    }
                                                }

                                                // Subtitle
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        if (!topResultUnifiedCard.topItem) return "";
                                                        if (topResultUnifiedCard.isArtist) return "Nghệ sĩ" + (topResultUnifiedCard.topItem.subscribers ? (" • " + topResultUnifiedCard.topItem.subscribers) : "");
                                                        if (topResultUnifiedCard.isAlbum) return (topResultUnifiedCard.topItem.albumType || "Album") + (topResultUnifiedCard.topItem.year ? (" • " + topResultUnifiedCard.topItem.year) : "") + (topResultUnifiedCard.topItem.artist ? (" • " + topResultUnifiedCard.topItem.artist) : "");
                                                        return (topResultUnifiedCard.topItem.artist || "") + (topResultUnifiedCard.topItem.duration ? (" • " + topResultUnifiedCard.topItem.duration) : "");
                                                    }
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                }

                                                Item { Layout.preferredHeight: 8 }

                                                // Action Buttons (Shuffle + Mix)
                                                RowLayout {
                                                    spacing: 8

                                                    // Main Action Button (Shuffle for Artist, Play for Song/Album)
                                                    Rectangle {
                                                        Layout.preferredHeight: 32
                                                        Layout.preferredWidth: heroMainBtnRow.implicitWidth + 24
                                                        radius: 16
                                                        color: searchRoot.accentColor

                                                        RowLayout {
                                                            id: heroMainBtnRow
                                                            anchors.centerIn: parent
                                                            spacing: 6

                                                            AppIcon {
                                                                source: topResultUnifiedCard.isArtist ? "../assets/icons/media-playlist-shuffle-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                                                                iconSize: 12
                                                                color: searchRoot.capsuleActiveTextColor
                                                            }

                                                            Text {
                                                                text: topResultUnifiedCard.isArtist ? "Phát ngẫu nhiên" : "Phát ngay"
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Bold
                                                                color: searchRoot.capsuleActiveTextColor
                                                            }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (topResultUnifiedCard.isArtist) {
                                                                    var trk = (topResultUnifiedCard.topItem && topResultUnifiedCard.topItem.top_tracks && topResultUnifiedCard.topItem.top_tracks.length > 0)
                                                                              ? topResultUnifiedCard.topItem.top_tracks[0]
                                                                              : ((searchRoot.searchData && searchRoot.searchData.songs && searchRoot.searchData.songs.length > 0) ? searchRoot.searchData.songs[0] : null);
                                                                    if (trk) {
                                                                        searchRoot.startRadioRequested(trk);
                                                                    } else {
                                                                        searchRoot.artistSelected(topResultUnifiedCard.topItem.name, topResultUnifiedCard.topItem.browseId);
                                                                    }
                                                                } else if (topResultUnifiedCard.isAlbum) {
                                                                    searchRoot.albumSelected(topResultUnifiedCard.topItem);
                                                                } else {
                                                                    searchRoot.trackPlayRequested(topResultUnifiedCard.topItem);
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Secondary Button (Radio/Mix for Artist, Radio for Song, or Details)
                                                    Rectangle {
                                                        Layout.preferredHeight: 32
                                                        Layout.preferredWidth: heroSecBtnRow.implicitWidth + 24
                                                        radius: 16
                                                        color: Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: Qt.rgba(1, 1, 1, 0.14)
                                                        border.width: 1

                                                        RowLayout {
                                                            id: heroSecBtnRow
                                                            anchors.centerIn: parent
                                                            spacing: 6

                                                            AppIcon {
                                                                source: topResultUnifiedCard.isAlbum ? "../assets/icons/view-more-symbolic.svg" : "../assets/icons/radio-symbolic.svg"
                                                                iconSize: 11
                                                                color: Theme.textPrimary
                                                            }

                                                            Text {
                                                                text: topResultUnifiedCard.isArtist ? "Mix" : (topResultUnifiedCard.isAlbum ? "Xem album" : "Đài phát")
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Medium
                                                                color: Theme.textPrimary
                                                            }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (topResultUnifiedCard.isArtist) {
                                                                    var trk2 = (topResultUnifiedCard.topItem && topResultUnifiedCard.topItem.top_tracks && topResultUnifiedCard.topItem.top_tracks.length > 0)
                                                                               ? topResultUnifiedCard.topItem.top_tracks[0]
                                                                               : ((searchRoot.searchData && searchRoot.searchData.songs && searchRoot.searchData.songs.length > 0) ? searchRoot.searchData.songs[0] : null);
                                                                    if (trk2) {
                                                                        searchRoot.startRadioRequested(trk2);
                                                                    } else {
                                                                        searchRoot.artistSelected(topResultUnifiedCard.topItem.name, topResultUnifiedCard.topItem.browseId);
                                                                    }
                                                                } else if (topResultUnifiedCard.isAlbum) {
                                                                    searchRoot.albumSelected(topResultUnifiedCard.topItem);
                                                                } else {
                                                                    searchRoot.startRadioRequested(topResultUnifiedCard.topItem);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Subtle Divider (Vertical on wide, Horizontal on narrow)
                                        Rectangle {
                                            Layout.preferredWidth: (heroCol.parent.isWide && topResultUnifiedCard.hasTopResult && topResultUnifiedCard.hasTopTracks) ? 1 : -1
                                            Layout.preferredHeight: (heroCol.parent.isWide && topResultUnifiedCard.hasTopResult && topResultUnifiedCard.hasTopTracks) ? -1 : 1
                                            Layout.fillWidth: !(heroCol.parent.isWide && topResultUnifiedCard.hasTopResult && topResultUnifiedCard.hasTopTracks)
                                            Layout.fillHeight: (heroCol.parent.isWide && topResultUnifiedCard.hasTopResult && topResultUnifiedCard.hasTopTracks)
                                            Layout.topMargin: 10
                                            Layout.bottomMargin: 10
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            visible: topResultUnifiedCard.hasTopTracks && topResultUnifiedCard.hasTopResult
                                        }

                                        // =================================================
                                        // RIGHT: TOP 3 SONGS LIST
                                        // =================================================
                                        ColumnLayout {
                                            id: topTracksWideCol
                                            Layout.preferredWidth: (heroCol.parent.isWide && topResultUnifiedCard.hasTopResult) ? 390 : -1
                                            Layout.fillWidth: true
                                            Layout.fillHeight: heroCol.parent.isWide
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 4
                                            visible: topResultUnifiedCard.hasTopTracks

                                            Repeater {
                                                model: topResultUnifiedCard.topTracksModel

                                                delegate: Rectangle {
                                                    id: topTrackRow
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 50
                                                    radius: 8
                                                    color: topTrackM.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 80 } }

                                                    readonly property bool isCurrent: searchRoot.currentTrack && (searchRoot.currentTrack.videoId === modelData.videoId || (searchRoot.currentTrack.path && searchRoot.currentTrack.path === modelData.path))

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 12
                                                        spacing: 12

                                                        // 42x42 Thumbnail with Play Overlay
                                                        Item {
                                                            Layout.preferredWidth: 42
                                                            Layout.preferredHeight: 42
                                                            Layout.alignment: Qt.AlignVCenter

                                                            Rectangle {
                                                                id: rThumbMask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true
                                                            }
                                                            Item {
                                                                anchors.fill: parent
                                                                layer.enabled: true
                                                                layer.effect: MultiEffect { maskEnabled: true; maskSource: rThumbMask; autoPaddingEnabled: false }
                                                                Rectangle { anchors.fill: parent; color: "#202024"; visible: rThumb.status !== Image.Ready }
                                                                Image {
                                                                    id: rThumb
                                                                    anchors.fill: parent
                                                                    source: modelData.image || ""
                                                                    fillMode: Image.PreserveAspectCrop
                                                                    sourceSize: Qt.size(96, 96)
                                                                    asynchronous: true
                                                                    visible: status === Image.Ready
                                                                }
                                                            }
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                radius: 8
                                                                color: Qt.rgba(0, 0, 0, 0.45)
                                                                visible: topTrackM.containsMouse || topTrackRow.isCurrent

                                                                AppIcon {
                                                                    anchors.centerIn: parent
                                                                    source: (topTrackRow.isCurrent && searchRoot.isPlaying) ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                                                                    iconSize: 14
                                                                    color: "#ffffff"
                                                                }
                                                            }
                                                        }

                                                        // Title & Detailed Subtitle with Views
                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            spacing: 2

                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.title || modelData.name || ""
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 14
                                                                font.weight: Font.DemiBold
                                                                color: topTrackRow.isCurrent ? searchRoot.accentColor : Theme.textPrimary
                                                                elide: Text.ElideRight
                                                            }

                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: {
                                                                    var parts = [];
                                                                    if (modelData.type === "album" || modelData.albumType) {
                                                                        parts.push(modelData.albumType || "Album");
                                                                    } else {
                                                                        parts.push("Bài hát");
                                                                    }
                                                                    if (modelData.duration) {
                                                                        parts.push(modelData.duration);
                                                                    }
                                                                    if (modelData.views) {
                                                                        parts.push(modelData.views);
                                                                    } else if (modelData.artist && modelData.artist !== "YouTube Music") {
                                                                        parts.push(modelData.artist);
                                                                    }
                                                                    return parts.join(" • ");
                                                                }
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 12
                                                                color: Theme.textSecondary
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: topTrackM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        onClicked: mouse => {
                                                            if (mouse.button === Qt.RightButton) {
                                                                searchRoot.trackContextMenuRequested(modelData, mouse.x + topTrackRow.x, mouse.y + topTrackRow.y);
                                                            } else {
                                                                searchRoot.trackPlayRequested(modelData);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. ALBUMS CAROUSEL
                        Item {
                            width: parent.width
                            height: albumsCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.albums && searchRoot.searchData.albums.length > 0)

                            Column {
                                id: albumsCol
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "Albums & Đĩa đơn"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Flickable {
                                    id: albumsFlick
                                    width: parent.width
                                    height: 196
                                    contentWidth: albRow.width + 10
                                    contentHeight: height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Row {
                                        id: albRow
                                        spacing: 14

                                        Repeater {
                                            model: searchRoot.searchData ? searchRoot.searchData.albums : []

                                            delegate: Rectangle {
                                                width: 136
                                                height: 190
                                                radius: 12
                                                color: albCardM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                                Behavior on color { ColorAnimation { duration: 100 } }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    // Thumbnail
                                                    Item {
                                                        Layout.preferredWidth: 124
                                                        Layout.preferredHeight: 124

                                                        Rectangle {
                                                            id: albMask
                                                            anchors.fill: parent
                                                            radius: 8
                                                            color: "#ffffff"
                                                            visible: false
                                                            layer.enabled: true
                                                        }

                                                        Item {
                                                            anchors.fill: parent
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true
                                                                maskSource: albMask
                                                                autoPaddingEnabled: false
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "#202024"
                                                                visible: albThumb.status !== Image.Ready
                                                            }

                                                            Image {
                                                                id: albThumb
                                                                anchors.fill: parent
                                                                source: modelData.image || ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                sourceSize: Qt.size(248, 248)
                                                                asynchronous: true
                                                                visible: status === Image.Ready
                                                            }
                                                        }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: 8
                                                            color: "transparent"
                                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                                            border.width: 1
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.title || modelData.name || ""
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: (modelData.albumType ? (modelData.albumType + " • ") : "") + (modelData.year ? (modelData.year + " • ") : "") + (modelData.artist || "")
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: albCardM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: searchRoot.albumSelected(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. COMMUNITY PLAYLISTS CAROUSEL
                        Item {
                            width: parent.width
                            height: commPlCol.height
                            visible: !!(searchRoot.searchData && ((searchRoot.searchData.community_playlists && searchRoot.searchData.community_playlists.length > 0) || (searchRoot.searchData.playlists && searchRoot.searchData.playlists.length > 0)))

                            Column {
                                id: commPlCol
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "Danh sách phát cộng đồng"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Flickable {
                                    id: commPlFlick
                                    width: parent.width
                                    height: 180
                                    contentWidth: commPlRow.width + 10
                                    contentHeight: height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Row {
                                        id: commPlRow
                                        spacing: 14

                                        Repeater {
                                            model: (searchRoot.searchData && searchRoot.searchData.community_playlists && searchRoot.searchData.community_playlists.length > 0)
                                                ? searchRoot.searchData.community_playlists
                                                : (searchRoot.searchData ? searchRoot.searchData.playlists : [])

                                            delegate: Rectangle {
                                                width: 130
                                                height: 174
                                                radius: 12
                                                color: cplCardM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    Item {
                                                        Layout.preferredWidth: 118
                                                        Layout.preferredHeight: 118

                                                        Rectangle {
                                                            id: cplMask
                                                            anchors.fill: parent
                                                            radius: 8
                                                            color: "#ffffff"
                                                            visible: false
                                                            layer.enabled: true
                                                        }

                                                        Item {
                                                            anchors.fill: parent
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true
                                                                maskSource: cplMask
                                                                autoPaddingEnabled: false
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "#202024"
                                                                visible: cplThumb.status !== Image.Ready
                                                            }

                                                            Image {
                                                                id: cplThumb
                                                                anchors.fill: parent
                                                                source: modelData.image || ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                sourceSize: Qt.size(236, 236)
                                                                asynchronous: true
                                                                visible: status === Image.Ready
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.title || ""
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.author || modelData.artist || "Cộng đồng"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: cplCardM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: searchRoot.playlistSelected(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 4. FEATURED PLAYLISTS CAROUSEL
                        Item {
                            width: parent.width
                            height: featPlCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.featured_playlists && searchRoot.searchData.featured_playlists.length > 0)

                            Column {
                                id: featPlCol
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "Danh sách phát nổi bật"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Flickable {
                                    id: featPlFlick
                                    width: parent.width
                                    height: 180
                                    contentWidth: featPlRow.width + 10
                                    contentHeight: height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Row {
                                        id: featPlRow
                                        spacing: 14

                                        Repeater {
                                            model: searchRoot.searchData ? searchRoot.searchData.featured_playlists : []

                                            delegate: Rectangle {
                                                width: 130
                                                height: 174
                                                radius: 12
                                                color: fplCardM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    Item {
                                                        Layout.preferredWidth: 118
                                                        Layout.preferredHeight: 118

                                                        Rectangle {
                                                            id: fplmMask
                                                            anchors.fill: parent
                                                            radius: 8
                                                            color: "#ffffff"
                                                            visible: false
                                                            layer.enabled: true
                                                        }

                                                        Item {
                                                            anchors.fill: parent
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true
                                                                maskSource: fplmMask
                                                                autoPaddingEnabled: false
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "#202024"
                                                                visible: fplmThumb.status !== Image.Ready
                                                            }

                                                            Image {
                                                                id: fplmThumb
                                                                anchors.fill: parent
                                                                source: modelData.image || ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                sourceSize: Qt.size(236, 236)
                                                                asynchronous: true
                                                                visible: status === Image.Ready
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.title || ""
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: "YouTube Music"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: fplCardM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: searchRoot.playlistSelected(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 5. ARTISTS CAROUSEL
                        Item {
                            width: parent.width
                            height: artistsCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.artists && searchRoot.searchData.artists.length > 0)

                            Column {
                                id: artistsCol
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "Nghệ sĩ liên quan"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Flickable {
                                    id: artistsFlick
                                    width: parent.width
                                    height: 160
                                    contentWidth: artRow.width + 10
                                    contentHeight: height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Row {
                                        id: artRow
                                        spacing: 16

                                        Repeater {
                                            model: searchRoot.searchData ? searchRoot.searchData.artists : []

                                            delegate: Rectangle {
                                                width: 112
                                                height: 154
                                                radius: 12
                                                color: artCardM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                                Behavior on color { ColorAnimation { duration: 100 } }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    // Round Avatar
                                                    Item {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        Layout.preferredWidth: 96
                                                        Layout.preferredHeight: 96

                                                        Rectangle {
                                                            id: artCircleMask
                                                            anchors.fill: parent
                                                            radius: 48
                                                            color: "#ffffff"
                                                            visible: false
                                                            layer.enabled: true
                                                        }

                                                        Item {
                                                            anchors.fill: parent
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true
                                                                maskSource: artCircleMask
                                                                autoPaddingEnabled: false
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "#202024"
                                                                visible: artImg.status !== Image.Ready
                                                            }

                                                            Image {
                                                                id: artImg
                                                                anchors.fill: parent
                                                                source: modelData.image || ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                sourceSize: Qt.size(192, 192)
                                                                asynchronous: true
                                                                visible: status === Image.Ready
                                                            }
                                                        }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: 48
                                                            color: "transparent"
                                                            border.color: Qt.rgba(1, 1, 1, 0.18)
                                                            border.width: 1
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.name || modelData.artist || ""
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textPrimary
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.subscribers ? (modelData.subscribers + " fans") : "Nghệ sĩ"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        color: Theme.textSecondary
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: artCardM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: searchRoot.artistSelected(modelData.name || modelData.artist, modelData.browseId)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "SONGS" (Full list of songs, 30+ items)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullSongsCol.height
                    visible: searchRoot.activeTab === "songs"

                    Column {
                        id: fullSongsCol
                        width: parent.width
                        spacing: 4

                        // Header
                        RowLayout {
                            width: parent.width
                            height: 36

                            Text {
                                text: searchRoot.isTabLoaded("songs") ? ("Toàn bộ bài hát (" + searchRoot.getTabItems("songs").length + ")") : "Toàn bộ bài hát"
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Skeleton Loading Placeholder
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: !searchRoot.isTabLoaded("songs")

                            Repeater {
                                model: 8
                                SkeletonTrackRow {
                                    width: fullSongsCol.width
                                }
                            }
                        }

                        Repeater {
                            model: searchRoot.isTabLoaded("songs") ? searchRoot.getTabItems("songs") : []

                            delegate: Rectangle {
                                id: fullSongRow
                                width: fullSongsCol.width
                                height: 52
                                radius: 8
                                color: fullSongM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                readonly property bool isCurrent: searchRoot.currentTrack && (searchRoot.currentTrack.videoId === modelData.videoId || (searchRoot.currentTrack.path && searchRoot.currentTrack.path === modelData.path))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    // Index or Soundwave
                                    Item {
                                        Layout.preferredWidth: 24
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(index + 1)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textMuted
                                            visible: !fullSongRow.isCurrent
                                        }

                                        AppIcon {
                                            anchors.centerIn: parent
                                            source: "../assets/icons/audio-volume-high-symbolic.svg"
                                            iconSize: 14
                                            color: searchRoot.accentColor
                                            visible: fullSongRow.isCurrent
                                        }
                                    }

                                    // Thumbnail with Play overlay
                                    Item {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40

                                        Rectangle {
                                            id: fMask; anchors.fill: parent; radius: 6; color: "#ffffff"; visible: false; layer.enabled: true
                                        }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: fMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: fImg.status !== Image.Ready }
                                            Image {
                                                id: fImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(80, 80); asynchronous: true; visible: status === Image.Ready
                                            }
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: Qt.rgba(0, 0, 0, 0.45)
                                            visible: fullSongM.containsMouse || fullSongRow.isCurrent

                                            AppIcon {
                                                anchors.centerIn: parent
                                                source: (fullSongRow.isCurrent && searchRoot.isPlaying) ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                                                iconSize: 14
                                                color: "#ffffff"
                                            }
                                        }
                                    }

                                    // Title & Artist
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || modelData.name || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: fullSongRow.isCurrent ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                var parts = [];
                                                if (modelData.artist && modelData.artist !== "YouTube Music") parts.push(modelData.artist);
                                                if (modelData.album) parts.push(modelData.album);
                                                if (modelData.views) parts.push(modelData.views);
                                                return parts.length > 0 ? parts.join(" • ") : (modelData.artist || "");
                                            }
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Duration
                                    Text {
                                        text: modelData.duration || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: fullSongM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            searchRoot.trackContextMenuRequested(modelData, mouse.x + fullSongRow.x, mouse.y + fullSongRow.y);
                                        } else {
                                            searchRoot.trackPlayRequested(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "ALBUMS" (Full vertical list of Albums & Singles)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullAlbCol.height
                    visible: searchRoot.activeTab === "albums"

                    Column {
                        id: fullAlbCol
                        width: parent.width
                        spacing: 6

                        // Header
                        RowLayout {
                            width: parent.width
                            height: 36

                            Text {
                                text: searchRoot.isTabLoaded("albums") ? ("Albums & Đĩa đơn (" + searchRoot.getTabItems("albums").length + ")") : "Albums & Đĩa đơn"
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Skeleton Loading Placeholder
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: !searchRoot.isTabLoaded("albums")

                            Repeater {
                                model: 6
                                SkeletonTrackRow {
                                    width: fullAlbCol.width
                                    height: 68
                                }
                            }
                        }

                        Repeater {
                            model: searchRoot.isTabLoaded("albums") ? searchRoot.getTabItems("albums") : []

                            delegate: Rectangle {
                                width: fullAlbCol.width
                                height: 68
                                radius: 8
                                color: fullAlbRowM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    // Thumbnail 54x54
                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54

                                        Rectangle { id: falbMask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: falbMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: falbImg.status !== Image.Ready }
                                            Image { id: falbImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(108, 108); asynchronous: true; visible: status === Image.Ready }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1 }
                                    }

                                    // Details
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || modelData.name || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: fullAlbRowM.containsMouse ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.albumType ? (modelData.albumType + " • ") : "Album • ") + (modelData.year ? (modelData.year + " • ") : "") + (modelData.artist || "")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    AppIcon {
                                        source: "../assets/icons/go-next-symbolic.svg"
                                        iconSize: 14
                                        color: fullAlbRowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: fullAlbRowM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.albumSelected(modelData)
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "COMMUNITY_PLAYLISTS" (Full vertical list)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullCommPlCol.height
                    visible: searchRoot.activeTab === "community_playlists"

                    Column {
                        id: fullCommPlCol
                        width: parent.width
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            height: 36

                            Text {
                                text: searchRoot.isTabLoaded("community_playlists") ? ("Danh sách phát cộng đồng (" + searchRoot.getTabItems("community_playlists").length + ")") : "Danh sách phát cộng đồng"
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Skeleton Loading Placeholder
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: !searchRoot.isTabLoaded("community_playlists")

                            Repeater {
                                model: 6
                                SkeletonTrackRow {
                                    width: fullCommPlCol.width
                                    height: 68
                                }
                            }
                        }

                        Repeater {
                            model: searchRoot.isTabLoaded("community_playlists") ? searchRoot.getTabItems("community_playlists") : []

                            delegate: Rectangle {
                                width: fullCommPlCol.width
                                height: 68
                                radius: 8
                                color: commPlRowM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54

                                        Rectangle { id: cplmMask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: cplmMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: cplmImg.status !== Image.Ready }
                                            Image { id: cplmImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(108, 108); asynchronous: true; visible: status === Image.Ready }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1 }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: commPlRowM.containsMouse ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.author || modelData.artist || "Cộng đồng") + (modelData.itemCount ? (" • " + modelData.itemCount + " bài hát") : "")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    AppIcon {
                                        source: "../assets/icons/go-next-symbolic.svg"
                                        iconSize: 14
                                        color: commPlRowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: commPlRowM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.playlistSelected(modelData)
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "FEATURED_PLAYLISTS" (Full vertical list)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullFeatPlCol.height
                    visible: searchRoot.activeTab === "featured_playlists"

                    Column {
                        id: fullFeatPlCol
                        width: parent.width
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            height: 36

                            Text {
                                text: searchRoot.isTabLoaded("featured_playlists") ? ("Danh sách phát nổi bật (" + searchRoot.getTabItems("featured_playlists").length + ")") : "Danh sách phát nổi bật"
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Skeleton Loading Placeholder
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: !searchRoot.isTabLoaded("featured_playlists")

                            Repeater {
                                model: 6
                                SkeletonTrackRow {
                                    width: fullFeatPlCol.width
                                    height: 68
                                }
                            }
                        }

                        Repeater {
                            model: searchRoot.isTabLoaded("featured_playlists") ? searchRoot.getTabItems("featured_playlists") : []

                            delegate: Rectangle {
                                width: fullFeatPlCol.width
                                height: 68
                                radius: 8
                                color: featPlRowM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54

                                        Rectangle { id: fpl2Mask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: fpl2Mask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: fpl2Img.status !== Image.Ready }
                                            Image { id: fpl2Img; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(108, 108); asynchronous: true; visible: status === Image.Ready }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1 }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: featPlRowM.containsMouse ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Tuyển tập chính thức YouTube Music" + (modelData.itemCount ? (" • " + modelData.itemCount + " bài") : "")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    AppIcon {
                                        source: "../assets/icons/go-next-symbolic.svg"
                                        iconSize: 14
                                        color: featPlRowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: featPlRowM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.playlistSelected(modelData)
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "ARTISTS" (Full vertical list of Artists)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullArtCol.height
                    visible: searchRoot.activeTab === "artists"

                    Column {
                        id: fullArtCol
                        width: parent.width
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            height: 36

                            Text {
                                text: searchRoot.isTabLoaded("artists") ? ("Nghệ sĩ liên quan (" + searchRoot.getTabItems("artists").length + ")") : "Nghệ sĩ liên quan"
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Skeleton Loading Placeholder
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: !searchRoot.isTabLoaded("artists")

                            Repeater {
                                model: 6
                                SkeletonTrackRow {
                                    width: fullArtCol.width
                                    height: 68
                                }
                            }
                        }

                        Repeater {
                            model: searchRoot.isTabLoaded("artists") ? searchRoot.getTabItems("artists") : []

                            delegate: Rectangle {
                                width: fullArtCol.width
                                height: 68
                                radius: 8
                                color: fArtRowM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    // Round Avatar 54x54
                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54

                                        Rectangle { id: faMask; anchors.fill: parent; radius: 27; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: faMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: faImg.status !== Image.Ready }
                                            Image { id: faImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(108, 108); asynchronous: true; visible: status === Image.Ready }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 27; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1 }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name || modelData.artist || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: fArtRowM.containsMouse ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Nghệ sĩ" + (modelData.subscribers ? (" • " + modelData.subscribers) : "")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    AppIcon {
                                        source: "../assets/icons/go-next-symbolic.svg"
                                        iconSize: 14
                                        color: fArtRowM.containsMouse ? searchRoot.accentColor : Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: fArtRowM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.artistSelected(modelData.name || modelData.artist, modelData.browseId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
