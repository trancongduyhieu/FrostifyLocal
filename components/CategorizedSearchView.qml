import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: searchRoot
    color: "transparent"

    // Props
    property var searchData: null // { query, top_result, songs, albums, artists, playlists }
    property var suggestions: []
    property var recommendedSuggestions: []
    property bool isLoading: false
    property string currentQuery: ""
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property var currentTrack: null
    property bool isPlaying: false
    property alias searchInputText: searchTextInput.text

    // State
    property string activeTab: "all" // "all", "songs", "artists", "albums", "playlists"
    property string viewMode: "results" // "results", "suggestions"

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
                        var curQ = searchRoot.getCurrentSearchQuery().toLowerCase();
                        var targetQ = cleanQ.toLowerCase();
                        if (curQ === targetQ || curQ.startsWith(targetQ) || targetQ.startsWith(curQ)) {
                            searchRoot.suggestions = queries;
                            searchRoot.recommendedSuggestions = recs;
                            searchRoot.viewMode = "suggestions";
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.send();
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
    // 0. PINNED TOP SEARCH BAR (SimpMusic / Spotify style)
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

            // Back Button
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: backBtnM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                Behavior on color { ColorAnimation { duration: 100 } }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    color: backBtnM.containsMouse ? searchRoot.accentColor : "#ffffff"
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
                        onDisplayTextChanged: realtimeSuggestTimer.restart()
                        onTextEdited: realtimeSuggestTimer.restart()
                        onTextChanged: realtimeSuggestTimer.restart()
                        onPreeditTextChanged: realtimeSuggestTimer.restart()
                        onInputMethodComposingChanged: realtimeSuggestTimer.restart()

                        onAccepted: {
                            var q = searchRoot.getCurrentSearchQuery();
                            if (q.length > 0) {
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
    // 1. SUGGESTIONS VIEW (When typing or exploring real-time suggestions)
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

            // Section 1: Recommended Songs with Avatars (SimpMusic pattern)
            Text {
                text: "Bài hát đề xuất"
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
                    id: recSongRow
                    width: suggestionsCol.width
                    height: 52
                    radius: 8
                    color: recSongM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 12

                        // Thumbnail (40x40, rounded 6px)
                        Item {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                id: recMask
                                anchors.fill: parent
                                radius: 6
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
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.08)
                                visible: recImg.status !== Image.Ready
                            }
                        }

                        // Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: recSongM.containsMouse ? searchRoot.accentColor : "#ffffff"
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.artist || modelData.subtitle || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: recSongM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Directly play track WITHOUT popping open Now Playing lyrics
                            searchRoot.trackPlayRequested(modelData);
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

                        // ArrowOutward button to fill text (SimpMusic pattern)
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

        // Filter Chips Bar (Glossy Gel Capsules)
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

                Repeater {
                    model: [
                        { id: "all", label: "Tất cả" },
                        { id: "songs", label: "Bài hát" },
                        { id: "artists", label: "Nghệ sĩ" },
                        { id: "albums", label: "Albums" },
                        { id: "playlists", label: "Danh sách phát" }
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
                            onClicked: searchRoot.activeTab = modelData.id
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
                // SECTION: TAB "ALL" (Search Summary: Top Result + Songs + Carousels)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: allSummaryCol.height
                    visible: searchRoot.activeTab === "all"

                    Column {
                        id: allSummaryCol
                        width: parent.width
                        spacing: 24

                        // 1. HERO TOP RESULT CARD
                        Item {
                            width: parent.width
                            height: topResultCard.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.top_result)

                            Rectangle {
                                id: topResultCard
                                width: Math.min(parent.width, 580)
                                height: 144
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: "transparent"
                                border.width: 0
                                clip: true

                                readonly property var topItem: searchRoot.searchData ? searchRoot.searchData.top_result : null
                                readonly property bool isArtist: topItem && topItem.type === "artist"
                                readonly property bool isSong: topItem && topItem.type === "song"
                                readonly property bool isAlbum: topItem && topItem.type === "album"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    // Thumbnail / Avatar
                                    Item {
                                        Layout.preferredWidth: 112
                                        Layout.preferredHeight: 112

                                        Rectangle {
                                            id: artMask
                                            anchors.fill: parent
                                            radius: topResultCard.isArtist ? 56 : 12
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
                                                source: topResultCard.topItem ? (topResultCard.topItem.image || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize: Qt.size(224, 224)
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: topResultCard.isArtist ? 56 : 12
                                            color: "transparent"
                                            border.color: Qt.rgba(1, 1, 1, 0.18)
                                            border.width: 1
                                        }
                                    }

                                    // Details & Actions
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        // Badge
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: badgeText.implicitWidth + 12
                                            radius: 9
                                            color: Qt.rgba(1, 1, 1, 0.08)

                                            Text {
                                                id: badgeText
                                                anchors.centerIn: parent
                                                text: topResultCard.isArtist ? "KẾT QUẢ HÀNG ĐẦU • NGHỆ SĨ" : (topResultCard.isAlbum ? "KẾT QUẢ HÀNG ĐẦU • ALBUM" : "KẾT QUẢ HÀNG ĐẦU • BÀI HÁT")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: searchRoot.accentColor
                                            }
                                        }

                                        // Name / Title
                                        Text {
                                            Layout.fillWidth: true
                                            text: topResultCard.topItem ? (topResultCard.topItem.name || topResultCard.topItem.title || "") : ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.Bold
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        // Subtitle (Artist or Subscribers or Duration)
                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                if (!topResultCard.topItem) return "";
                                                if (topResultCard.isArtist) return topResultCard.topItem.subscribers ? (topResultCard.topItem.subscribers + " người theo dõi") : "Nghệ sĩ chính thức";
                                                if (topResultCard.isAlbum) return (topResultCard.topItem.artist || "") + (topResultCard.topItem.year ? (" • " + topResultCard.topItem.year) : "");
                                                return (topResultCard.topItem.artist || "") + (topResultCard.topItem.duration ? (" • " + topResultCard.topItem.duration) : "");
                                            }
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }

                                        Item { Layout.preferredHeight: 4 }

                                        // Action buttons
                                        RowLayout {
                                            spacing: 10

                                            // Main Button
                                            Rectangle {
                                                Layout.preferredHeight: 28
                                                Layout.preferredWidth: mainBtnRow.implicitWidth + 24
                                                radius: 14
                                                color: searchRoot.accentColor

                                                RowLayout {
                                                    id: mainBtnRow
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    AppIcon {
                                                        source: topResultCard.isArtist ? "../assets/icons/avatar-default-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                                                        iconSize: 11
                                                        color: searchRoot.capsuleActiveTextColor
                                                    }

                                                    Text {
                                                        id: btnLabel
                                                        text: topResultCard.isArtist ? "Xem nghệ sĩ" : (topResultCard.isAlbum ? "Xem album" : "Phát ngay")
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
                                                        if (topResultCard.isArtist) {
                                                            searchRoot.artistSelected(topResultCard.topItem.name, topResultCard.topItem.browseId);
                                                        } else if (topResultCard.isAlbum) {
                                                            searchRoot.albumSelected(topResultCard.topItem);
                                                        } else {
                                                            searchRoot.trackPlayRequested(topResultCard.topItem);
                                                        }
                                                    }
                                                }
                                            }

                                            // Secondary Button (Radio)
                                            Rectangle {
                                                Layout.preferredHeight: 28
                                                Layout.preferredWidth: radioBtnRow.implicitWidth + 24
                                                radius: 14
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                border.color: "transparent"
                                                border.width: 0
                                                visible: topResultCard.isArtist || topResultCard.isSong

                                                RowLayout {
                                                    id: radioBtnRow
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    AppIcon {
                                                        source: "../assets/icons/radio-symbolic.svg"
                                                        iconSize: 11
                                                        color: Theme.textPrimary
                                                    }

                                                    Text {
                                                        id: radioLabel
                                                        text: "Đài phát"
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
                                                        if (topResultCard.isArtist) {
                                                            searchRoot.startRadioRequested({ id: topResultCard.topItem.browseId, name: topResultCard.topItem.name });
                                                        } else {
                                                            searchRoot.startRadioRequested(topResultCard.topItem);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. TOP SONGS LIST (4 items in All view)
                        Item {
                            width: parent.width
                            height: songsBlockCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.songs && searchRoot.searchData.songs.length > 0)

                            Column {
                                id: songsBlockCol
                                width: parent.width
                                spacing: 8

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: "Bài hát"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "Xem tất cả >"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: searchRoot.accentColor
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: searchRoot.activeTab = "songs"
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: searchRoot.searchData ? searchRoot.searchData.songs.slice(0, 4) : []

                                        delegate: Rectangle {
                                            id: trackItem
                                            width: parent.width
                                            height: 48
                                            radius: 8
                                            color: trackItemM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 80 } }

                                            readonly property bool isCurrent: searchRoot.currentTrack && (searchRoot.currentTrack.videoId === modelData.videoId || (searchRoot.currentTrack.path && searchRoot.currentTrack.path === modelData.path))

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 12
                                                spacing: 12

                                                // Thumbnail with hover play overlay
                                                Item {
                                                    Layout.preferredWidth: 38
                                                    Layout.preferredHeight: 38

                                                    Rectangle {
                                                        id: rowThumbMask
                                                        anchors.fill: parent
                                                        radius: 6
                                                        color: "#ffffff"
                                                        visible: false
                                                        layer.enabled: true
                                                    }

                                                    Item {
                                                        anchors.fill: parent
                                                        layer.enabled: true
                                                        layer.effect: MultiEffect {
                                                            maskEnabled: true
                                                            maskSource: rowThumbMask
                                                            autoPaddingEnabled: false
                                                        }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "#202024"
                                                            visible: rowThumb.status !== Image.Ready
                                                        }

                                                        Image {
                                                            id: rowThumb
                                                            anchors.fill: parent
                                                            source: modelData.image || ""
                                                            fillMode: Image.PreserveAspectCrop
                                                            sourceSize: Qt.size(76, 76)
                                                            asynchronous: true
                                                            visible: status === Image.Ready
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 6
                                                        color: Qt.rgba(0, 0, 0, 0.45)
                                                        visible: trackItemM.containsMouse || trackItem.isCurrent

                                                        AppIcon {
                                                            anchors.centerIn: parent
                                                            source: (trackItem.isCurrent && searchRoot.isPlaying) ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
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
                                                        font.weight: Font.Medium
                                                        color: trackItem.isCurrent ? searchRoot.accentColor : Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.artist || ""
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
                                                id: trackItemM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        searchRoot.trackContextMenuRequested(modelData, mouse.x + trackItem.x, mouse.y + trackItem.y);
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

                        // 3. ALBUMS CAROUSEL
                        Item {
                            width: parent.width
                            height: albumsCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.albums && searchRoot.searchData.albums.length > 0)

                            Column {
                                id: albumsCol
                                width: parent.width
                                spacing: 10

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: "Albums & Đĩa đơn"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Carousel Navigation Arrows < >
                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: albPrevM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            AppIcon { anchors.centerIn: parent; source: "../assets/icons/go-previous-symbolic.svg"; iconSize: 12; color: searchRoot.accentColor }
                                            MouseArea { id: albPrevM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: albumsFlick.contentX = Math.max(0, albumsFlick.contentX - 320) }
                                        }
                                        Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: albNextM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            AppIcon { anchors.centerIn: parent; source: "../assets/icons/go-next-symbolic.svg"; iconSize: 12; color: searchRoot.accentColor }
                                            MouseArea { id: albNextM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: albumsFlick.contentX = Math.min(albumsFlick.contentWidth - albumsFlick.width, albumsFlick.contentX + 320) }
                                        }
                                    }
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
                                                        text: (modelData.artist || "") + (modelData.year ? (" • " + modelData.year) : "")
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

                        // 4. ARTISTS CAROUSEL
                        Item {
                            width: parent.width
                            height: artistsCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.artists && searchRoot.searchData.artists.length > 0)

                            Column {
                                id: artistsCol
                                width: parent.width
                                spacing: 10

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: "Nghệ sĩ liên quan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: artPrevM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            AppIcon { anchors.centerIn: parent; source: "../assets/icons/go-previous-symbolic.svg"; iconSize: 12; color: searchRoot.accentColor }
                                            MouseArea { id: artPrevM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: artistsFlick.contentX = Math.max(0, artistsFlick.contentX - 320) }
                                        }
                                        Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: artNextM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            AppIcon { anchors.centerIn: parent; source: "../assets/icons/go-next-symbolic.svg"; iconSize: 12; color: searchRoot.accentColor }
                                            MouseArea { id: artNextM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: artistsFlick.contentX = Math.min(artistsFlick.contentWidth - artistsFlick.width, artistsFlick.contentX + 320) }
                                        }
                                    }
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

                        // 5. PLAYLISTS CAROUSEL
                        Item {
                            width: parent.width
                            height: plCol.height
                            visible: !!(searchRoot.searchData && searchRoot.searchData.playlists && searchRoot.searchData.playlists.length > 0)

                            Column {
                                id: plCol
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "Danh sách phát"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Flickable {
                                    width: parent.width
                                    height: 180
                                    contentWidth: plRow.width + 10
                                    contentHeight: height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Row {
                                        id: plRow
                                        spacing: 14

                                        Repeater {
                                            model: searchRoot.searchData ? searchRoot.searchData.playlists : []

                                            delegate: Rectangle {
                                                width: 130
                                                height: 174
                                                radius: 12
                                                color: plCardM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    Item {
                                                        Layout.preferredWidth: 118
                                                        Layout.preferredHeight: 118

                                                        Rectangle {
                                                            id: plMask
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
                                                                maskSource: plMask
                                                                autoPaddingEnabled: false
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "#202024"
                                                                visible: plThumb.status !== Image.Ready
                                                            }

                                                            Image {
                                                                id: plThumb
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
                                                        text: modelData.author || "YouTube Music"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: plCardM
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
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "SONGS" (Full list of songs)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullSongsCol.height
                    visible: searchRoot.activeTab === "songs"

                    Column {
                        id: fullSongsCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: (searchRoot.searchData && searchRoot.searchData.songs) ? searchRoot.searchData.songs : []

                            delegate: Rectangle {
                                id: fullSongRow
                                width: fullSongsCol.width
                                height: 50
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

                                    // Thumbnail
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
                                            font.weight: Font.Medium
                                            color: fullSongRow.isCurrent ? searchRoot.accentColor : Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.artist || ""
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
                // SECTION: TAB "ARTISTS" (Full list / Grid of artists)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullArtGrid.height
                    visible: searchRoot.activeTab === "artists"

                    Flow {
                        id: fullArtGrid
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: (searchRoot.searchData && searchRoot.searchData.artists) ? searchRoot.searchData.artists : []

                            delegate: Rectangle {
                                width: 140
                                height: 170
                                radius: 12
                                color: fArtM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 104
                                        Layout.preferredHeight: 104

                                        Rectangle { id: faMask; anchors.fill: parent; radius: 52; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: faMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: faImg.status !== Image.Ready }
                                            Image { id: faImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(208, 208); asynchronous: true; visible: status === Image.Ready }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 52; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1 }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.artist || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: fArtM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.artistSelected(modelData.name || modelData.artist, modelData.browseId)
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION: TAB "ALBUMS" (Full list / Grid of albums)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullAlbGrid.height
                    visible: searchRoot.activeTab === "albums"

                    Flow {
                        id: fullAlbGrid
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: (searchRoot.searchData && searchRoot.searchData.albums) ? searchRoot.searchData.albums : []

                            delegate: Rectangle {
                                width: 148
                                height: 200
                                radius: 12
                                color: fAlbM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Item {
                                        Layout.preferredWidth: 132
                                        Layout.preferredHeight: 132

                                        Rectangle { id: falbMask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: falbMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: falbImg.status !== Image.Ready }
                                            Image { id: falbImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(264, 264); asynchronous: true; visible: status === Image.Ready }
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
                                        text: (modelData.artist || "") + (modelData.year ? (" • " + modelData.year) : "")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: fAlbM
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
                // SECTION: TAB "PLAYLISTS" (Full list / Grid of playlists)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: fullPlGrid.height
                    visible: searchRoot.activeTab === "playlists"

                    Flow {
                        id: fullPlGrid
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: (searchRoot.searchData && searchRoot.searchData.playlists) ? searchRoot.searchData.playlists : []

                            delegate: Rectangle {
                                width: 148
                                height: 190
                                radius: 12
                                color: fPlM.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Item {
                                        Layout.preferredWidth: 132
                                        Layout.preferredHeight: 132

                                        Rectangle { id: fplMask; anchors.fill: parent; radius: 8; color: "#ffffff"; visible: false; layer.enabled: true }
                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect { maskEnabled: true; maskSource: fplMask; autoPaddingEnabled: false }
                                            Rectangle { anchors.fill: parent; color: "#202024"; visible: fplImg.status !== Image.Ready }
                                            Image { id: fplImg; anchors.fill: parent; source: modelData.image || ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(264, 264); asynchronous: true; visible: status === Image.Ready }
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
                                        text: modelData.author || "YouTube Music"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: fPlM
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
    }
}
