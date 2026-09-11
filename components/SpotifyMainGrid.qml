import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Rectangle {
    id: root
    color: "#121212"
    radius: Theme.radiusCard

    property var tracks: []
    property var currentTrack: null
    property bool isPlaying: false
    property string sectionTitle: "Featured & Popular"
    property bool isLoading: false
    signal trackPlayRequested(var trk)
    signal trackDetailsRequested(var trk)
    signal trackContextMenuRequested(var trk, real globalX, real globalY)
    signal playAllRequested()
    signal shufflePlayRequested()
    signal addAlbumToQueueRequested(var tracks)
    signal downloadAlbumRequested(var tracks)
    signal albumSelected(var album)
    signal batchDeleteRequested(var paths)
    signal createPlaylistRequested(var tracks)

    property var albumMetadata: null
    property string downloadsSubTab: "tracks" // "tracks", "albums"
    property var localAlbums: []

    readonly property bool isDownloadsView: root.sectionTitle.includes("Download") || (typeof win !== "undefined" && win && win.currentView === "library")
    readonly property bool isPlaylistView: typeof win !== "undefined" && win && win.currentView === "playlist"
    property string sortBy: "recent" // "recent", "title", "artist"
    property bool isSelectionMode: false
    property var selectedTrackPaths: []

    function toggleTrackSelection(trk) {
        if (!trk || !trk.path) return;
        var p = trk.path;
        var idx = selectedTrackPaths.indexOf(p);
        var updated = selectedTrackPaths.slice();
        if (idx !== -1) {
            updated.splice(idx, 1);
        } else {
            updated.push(p);
        }
        selectedTrackPaths = updated;
    }

    function selectAllTracks() {
        var arr = [];
        for (var i = 0; i < sortedTracks.length; i++) {
            if (sortedTracks[i] && sortedTracks[i].path) {
                arr.push(sortedTracks[i].path);
            }
        }
        selectedTrackPaths = arr;
    }

    function clearSelection() {
        selectedTrackPaths = [];
    }

    function getSelectedTracks() {
        var arr = [];
        for (var i = 0; i < sortedTracks.length; i++) {
            var t = sortedTracks[i];
            if (t && selectedTrackPaths.indexOf(t.path) !== -1) {
                arr.push(t);
            }
        }
        return arr;
    }

    readonly property var sortedTracks: {
        if (!root.tracks || root.tracks.length === 0) return [];
        var list = root.tracks.slice();
        if (!isDownloadsView) return list;
        if (sortBy === "recent") {
            list.sort((a, b) => (b.mtime || 0) - (a.mtime || 0));
        } else if (sortBy === "title") {
            list.sort((a, b) => (a.name || a.title || "").localeCompare(b.name || b.title || ""));
        } else if (sortBy === "artist") {
            list.sort((a, b) => (a.artist || "").localeCompare(b.artist || ""));
        }
        return list;
    }

    // Dynamic gradient banner on top (Spotify style)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 240
        radius: Theme.radiusCard
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#382255" }
            GradientStop { position: 1.0; color: "#121212" }
        }
    }

    Flickable {
        id: scrollArea
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: width
        contentHeight: contentCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentCol
            width: scrollArea.width
            spacing: 24

            // Section 1: Header Row
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14

                // Hero Album Banner (When viewing an Album or detailed Playlist)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 24
                    visible: root.albumMetadata !== null

                    // 1. Large Cover Art (160x160) with elegant shadow and subtle glow
                    Rectangle {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 160
                        radius: 8
                        color: "#242424"
                        clip: true

                        Image {
                            id: albumHeroCover
                            anchors.fill: parent
                            source: {
                                if (!root.albumMetadata || !root.albumMetadata.image) return "";
                                var s = root.albumMetadata.image;
                                return (s.startsWith("/") && !s.startsWith("file://")) ? ("file://" + s) : s;
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !albumHeroCover.visible || albumHeroCover.status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#3a2255" }
                                GradientStop { position: 1.0; color: "#1a1a1a" }
                            }
                            SpotifyIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/media-optical-audio-symbolic.svg"
                                iconSize: 54
                                color: Qt.rgba(1, 1, 1, 0.25)
                            }
                        }
                    }

                    // 2. Album Details & Metadata Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        // Badge: ALBUM / SINGLE / EP
                        Rectangle {
                            height: 22
                            width: badgeText.implicitWidth + 14
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: (root.albumMetadata && root.albumMetadata.type ? root.albumMetadata.type : "ALBUM").toUpperCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        // Album Title (Big & Bold)
                        Text {
                            Layout.fillWidth: true
                            text: root.albumMetadata ? (root.albumMetadata.title || root.albumMetadata.name || "") : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        // Subtitle: Artist • Year • Track count • Duration
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: root.albumMetadata ? (root.albumMetadata.artist || "Unknown Artist") : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                visible: root.albumMetadata && !!root.albumMetadata.year
                                text: "•"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }

                            Text {
                                visible: root.albumMetadata && !!root.albumMetadata.year
                                text: root.albumMetadata ? root.albumMetadata.year : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }

                            Text {
                                text: "•"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }

                            Text {
                                text: (root.sortedTracks ? root.sortedTracks.length : 0) + " bài hát"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }

                            Text {
                                visible: root.albumMetadata && !!root.albumMetadata.duration
                                text: "•"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }

                            Text {
                                visible: root.albumMetadata && !!root.albumMetadata.duration
                                text: root.albumMetadata ? root.albumMetadata.duration : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                        }

                        // Optional short description if available
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            visible: root.albumMetadata && !!root.albumMetadata.description
                            text: root.albumMetadata ? root.albumMetadata.description : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Standard Section Header (When NOT in Album Hero mode)
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.albumMetadata === null

                    Text {
                        text: root.sectionTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Downloads Sub-tab Switcher: [ Bài hát ] | [ Albums ]
                    RowLayout {
                        visible: root.isDownloadsView
                        Layout.leftMargin: 16
                        spacing: 8

                        Rectangle {
                            height: 28
                            width: dlTrkText.implicitWidth + 20
                            radius: 14
                            color: root.downloadsSubTab === "tracks" ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                            border.color: root.downloadsSubTab === "tracks" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1

                            Text {
                                id: dlTrkText
                                anchors.centerIn: parent
                                text: "Bài hát (" + (root.sortedTracks ? root.sortedTracks.length : 0) + ")"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.downloadsSubTab === "tracks"
                                color: root.downloadsSubTab === "tracks" ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.downloadsSubTab = "tracks"
                            }
                        }

                        Rectangle {
                            height: 28
                            width: dlAlbText.implicitWidth + 20
                            radius: 14
                            color: root.downloadsSubTab === "albums" ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                            border.color: root.downloadsSubTab === "albums" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1

                            Text {
                                id: dlAlbText
                                anchors.centerIn: parent
                                text: "Albums (" + (root.localAlbums ? root.localAlbums.length : 0) + ")"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.downloadsSubTab === "albums"
                                color: root.downloadsSubTab === "albums" ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.downloadsSubTab = "albums"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: !root.isDownloadsView
                        text: root.isLoading ? "Loading..." : (root.sortedTracks ? root.sortedTracks.length + " tracks" : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textSecondary
                    }
                }

                // Action Toolbar (Shuffle Play, Sort, Multi-Select)
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.isDownloadsView || (root.isPlaylistView && root.sortedTracks && root.sortedTracks.length > 0)
                    spacing: 12

                    // Play All (From 1st Track) Button
                    Rectangle {
                        height: 36
                        width: playRow.implicitWidth + 24
                        radius: 18
                        color: playH.hovered ? "#1ed760" : Theme.spotifyGreen
                        scale: playH.hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            id: playRow
                            anchors.centerIn: parent
                            spacing: 8

                            SpotifyIcon {
                                source: "../assets/icons/media-playback-start-symbolic.svg"
                                iconSize: 15
                                color: "#000000"
                            }

                            Text {
                                text: "Phát"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#000000"
                            }
                        }

                        HoverHandler { id: playH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playAllRequested()
                        }
                    }

                    // Shuffle Play Button (Secondary Glass Style)
                    Rectangle {
                        height: 36
                        width: shuffleRow.implicitWidth + 24
                        radius: 18
                        color: shufH.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        scale: shufH.hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            id: shuffleRow
                            anchors.centerIn: parent
                            spacing: 8

                            SpotifyIcon {
                                source: "../assets/icons/media-playlist-shuffle-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: "Phát ngẫu nhiên"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        HoverHandler { id: shufH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shufflePlayRequested()
                        }
                    }

                    // Add All to Queue Button
                    Rectangle {
                        height: 36
                        width: queueRow.implicitWidth + 24
                        radius: 18
                        visible: root.albumMetadata !== null || root.isPlaylistView
                        color: qH.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        scale: qH.hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            id: queueRow
                            anchors.centerIn: parent
                            spacing: 8

                            SpotifyIcon {
                                source: "../assets/icons/list-add-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: "Hàng đợi"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        HoverHandler { id: qH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addAlbumToQueueRequested(root.sortedTracks)
                        }
                    }

                    // Download Entire Album Button
                    Rectangle {
                        height: 36
                        width: dlAlbRow.implicitWidth + 24
                        radius: 18
                        visible: root.albumMetadata !== null && (!root.albumMetadata.isLocal)
                        color: dlAlbH.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        scale: dlAlbH.hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            id: dlAlbRow
                            anchors.centerIn: parent
                            spacing: 8

                            SpotifyIcon {
                                source: "../assets/icons/download-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: "Tải Album"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        HoverHandler { id: dlAlbH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.downloadAlbumRequested(root.sortedTracks)
                        }
                    }

                    // Sort Pills
                    RowLayout {
                        spacing: 6

                        Text {
                            text: "Sắp xếp:"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                            Layout.rightMargin: 2
                        }

                        // Pill: Mới nhất
                        Rectangle {
                            height: 28
                            width: sortRecentText.implicitWidth + 18
                            radius: 14
                            color: root.sortBy === "recent" ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: root.sortBy === "recent" ? "#ffffff" : "transparent"
                            border.width: 1

                            Text {
                                id: sortRecentText
                                anchors.centerIn: parent
                                text: "Mới nhất"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: root.sortBy === "recent"
                                color: root.sortBy === "recent" ? "#ffffff" : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy = "recent"
                            }
                        }

                        // Pill: Tên A-Z
                        Rectangle {
                            height: 28
                            width: sortTitleText.implicitWidth + 18
                            radius: 14
                            color: root.sortBy === "title" ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: root.sortBy === "title" ? "#ffffff" : "transparent"
                            border.width: 1

                            Text {
                                id: sortTitleText
                                anchors.centerIn: parent
                                text: "Tên A-Z"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: root.sortBy === "title"
                                color: root.sortBy === "title" ? "#ffffff" : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy = "title"
                            }
                        }

                        // Pill: Nghệ sĩ
                        Rectangle {
                            height: 28
                            width: sortArtistText.implicitWidth + 18
                            radius: 14
                            color: root.sortBy === "artist" ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: root.sortBy === "artist" ? "#ffffff" : "transparent"
                            border.width: 1

                            Text {
                                id: sortArtistText
                                anchors.centerIn: parent
                                text: "Nghệ sĩ"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: root.sortBy === "artist"
                                color: root.sortBy === "artist" ? "#ffffff" : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy = "artist"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Multi-Select Mode Toggle Button
                    Rectangle {
                        height: 32
                        width: selectModeRow.implicitWidth + 20
                        radius: 16
                        color: root.isSelectionMode ? Qt.rgba(0, 200, 83, 0.15) : (selH.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: root.isSelectionMode ? "#00c853" : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        RowLayout {
                            id: selectModeRow
                            anchors.centerIn: parent
                            spacing: 6

                            SpotifyIcon {
                                source: "../assets/icons/selection-mode-symbolic.svg"
                                iconSize: 13
                                color: root.isSelectionMode ? "#00c853" : (selH.hovered ? "#ffffff" : Theme.textSecondary)
                            }

                            Text {
                                text: root.isSelectionMode ? "Đang chọn" : "Chọn nhiều"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.isSelectionMode
                                color: root.isSelectionMode ? "#00c853" : (selH.hovered ? "#ffffff" : Theme.textSecondary)
                            }
                        }

                        HoverHandler { id: selH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isSelectionMode = !root.isSelectionMode;
                                if (!root.isSelectionMode) root.clearSelection();
                            }
                        }
                    }
                }

                // Multi-Select Action Bar (Floating Dark Glass banner)
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 10
                    color: Qt.rgba(0.12, 0.12, 0.16, 0.98)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    visible: root.isDownloadsView && root.isSelectionMode

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "Đã chọn: " + root.selectedTrackPaths.length + " bài"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        // Button: Select All
                        Rectangle {
                            height: 28
                            width: selAllText.implicitWidth + 18
                            radius: 14
                            color: selAllH.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                id: selAllText
                                anchors.centerIn: parent
                                text: "Chọn tất cả"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: "#ffffff"
                            }
                            HoverHandler { id: selAllH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectAllTracks()
                            }
                        }

                        // Button: Clear Selection
                        Rectangle {
                            height: 28
                            width: clearSelText.implicitWidth + 18
                            radius: 14
                            color: clearSelH.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                id: clearSelText
                                anchors.centerIn: parent
                                text: "Bỏ chọn"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                            HoverHandler { id: clearSelH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearSelection()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Button: Create Custom Playlist from Selected
                        Rectangle {
                            height: 32
                            width: createPlRow.implicitWidth + 20
                            radius: 16
                            color: createPlH.hovered ? "#3b82f6" : "#2563eb"
                            visible: root.selectedTrackPaths.length > 0

                            RowLayout {
                                id: createPlRow
                                anchors.centerIn: parent
                                spacing: 6

                                SpotifyIcon {
                                    source: "../assets/icons/folder-music-symbolic.svg"
                                    iconSize: 13
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "+ Tạo Playlist"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            HoverHandler { id: createPlH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.createPlaylistRequested(root.getSelectedTracks());
                                }
                            }
                        }

                        // Button: Delete Selected
                        Rectangle {
                            height: 32
                            width: delSelRow.implicitWidth + 20
                            radius: 16
                            color: delSelH.hovered ? "#ef4444" : "#dc2626"
                            visible: root.selectedTrackPaths.length > 0

                            RowLayout {
                                id: delSelRow
                                anchors.centerIn: parent
                                spacing: 6

                                SpotifyIcon {
                                    source: "../assets/icons/user-trash-symbolic.svg"
                                    iconSize: 13
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "Xóa (" + root.selectedTrackPaths.length + ")"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            HoverHandler { id: delSelH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.batchDeleteRequested(root.selectedTrackPaths);
                                }
                            }
                        }

                        // Button: Exit selection mode
                        Item {
                            width: 28
                            height: 28
                            HoverHandler { id: exitSelH }

                            SpotifyIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/window-close-symbolic.svg"
                                iconSize: 14
                                color: exitSelH.hovered ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.isSelectionMode = false;
                                    root.clearSelection();
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.isLoading
                    text: "Searching YouTube Music online..."
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.italic: true
                    color: Theme.spotifyGreen
                }

                Text {
                    visible: !root.isLoading && (!root.sortedTracks || root.sortedTracks.length === 0)
                    text: root.isPlaylistView ? "This playlist is empty. Add songs using the context menu on any song!" : "No tracks found. Type in search bar to explore YouTube Music!"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }

                // Local Albums Grid (when in Downloads view and Albums sub-tab is selected)
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: root.isDownloadsView && root.downloadsSubTab === "albums" && root.albumMetadata === null

                    Repeater {
                        model: root.localAlbums

                        Rectangle {
                            width: 176
                            height: 250
                            radius: Theme.radiusCard
                            color: albCardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width
                                    radius: 6
                                    color: "#282828"
                                    clip: true

                                    Image {
                                        id: albImg
                                        anchors.fill: parent
                                        source: {
                                            if (!modelData || !modelData.image) return "";
                                            var s = modelData.image;
                                            return (s.startsWith("/") && !s.startsWith("file://")) ? ("file://" + s) : s;
                                        }
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !albImg.visible || albImg.status !== Image.Ready
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#333333" }
                                            GradientStop { position: 1.0; color: "#181818" }
                                        }
                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            source: "../assets/icons/media-optical-audio-symbolic.svg"
                                            iconSize: 42
                                            color: Qt.rgba(1, 1, 1, 0.25)
                                        }
                                    }

                                    // Play Album Button on Hover
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: Theme.spotifyGreen
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        visible: albCardMouse.containsMouse

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            source: "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 16
                                            color: "#000000"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.tracks && modelData.tracks.length > 0) {
                                                    root.trackPlayRequested(modelData.tracks[0]);
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || modelData.name || "Album"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (modelData.artist || "Unknown") + " • " + (modelData.trackCount || 0) + " bài"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Item { Layout.fillHeight: true }
                            }

                            MouseArea {
                                id: albCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.albumSelected(modelData)
                            }
                        }
                    }
                }

                // Grid of tracks
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: !(root.isDownloadsView && root.downloadsSubTab === "albums" && root.albumMetadata === null)

                    Repeater {
                        model: root.sortedTracks

                        TrackCard {
                            track: modelData
                            isPlaying: root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying
                            isSelectionMode: root.isSelectionMode
                            isSelected: root.selectedTrackPaths.indexOf(modelData.path) !== -1
                            onSelectionToggled: trk => root.toggleTrackSelection(trk)
                            onPlayRequested: trk => root.trackPlayRequested(trk)
                            onDetailsRequested: trk => root.trackDetailsRequested(trk)
                            onContextMenuRequested: (trk, gx, gy) => root.trackContextMenuRequested(trk, gx, gy)
                        }
                    }
                }
            }
        }
    }
}
