import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: root
    color: "transparent"

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

    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

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

    // Subtle top ambient gradient (clean acrylic SimpMusic style, no heavy purple)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Flickable {
        id: scrollArea
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: width
        contentHeight: contentCol.height + 110
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
                    Item {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 160

                        Rectangle {
                            id: albumHeroMask
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
                                maskSource: albumHeroMask
                                autoPaddingEnabled: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#242424"
                            }

                            Image {
                                id: albumHeroCover
                                anchors.fill: parent
                                source: {
                                    if (!root.albumMetadata || !root.albumMetadata.image) return "";
                                    var s = root.albumMetadata.image;
                                    return (s.startsWith("/") && !s.startsWith("file://")) ? ("file://" + s) : s;
                                }
                                fillMode: Image.PreserveAspectCrop
                                scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.25)) ? 1.48 : 1.0
                                transformOrigin: Item.Center
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !albumHeroCover.visible || albumHeroCover.status !== Image.Ready
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#3a2255" }
                                    GradientStop { position: 1.0; color: "#1a1a1a" }
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    source: "../assets/icons/media-optical-audio-symbolic.svg"
                                    iconSize: 54
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                }
                            }
                        }

                        // 1px Hairline Border Overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            z: 2
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
                                text: (root.sortedTracks ? root.sortedTracks.length : 0) + I18n.tr(" bài hát", " songs")
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

                        Text {
                            Layout.fillWidth: true
                            text: root.albumMetadata ? root.albumMetadata.description : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }

                // Normal View Header: Title, Count & View Options (Downloads Sub-tabs)
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.albumMetadata === null
                    spacing: 16

                    // Title & Count Badge
                    RowLayout {
                        spacing: 12

                        Text {
                            text: root.isDownloadsView ? I18n.tr("Tải xuống", "Downloads") : root.sectionTitle
                            font.family: Theme.fontFamily
                            font.pixelSize: 28
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        // Badge count pill
                        Rectangle {
                            height: 22
                            width: countBadgeText.implicitWidth + 14
                            radius: 11
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                id: countBadgeText
                                anchors.centerIn: parent
                                text: (root.sortedTracks ? root.sortedTracks.length : 0) + I18n.tr(" bài hát", " songs")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textSecondary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Downloads Sub-tab Switcher: [ Bài hát | Albums ] (Refined Dark Glass Segmented Control)
                    Rectangle {
                        visible: root.isDownloadsView
                        height: 34
                        width: 210
                        radius: 17
                        color: Qt.rgba(0.08, 0.08, 0.11, 0.85)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 2

                            // Subtab: Bài hát
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: root.downloadsSubTab === "tracks" 
                                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) 
                                       : (trksH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.color: root.downloadsSubTab === "tracks" 
                                              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45) 
                                              : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                HoverHandler { id: trksH }

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Bài hát", "Songs")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: root.downloadsSubTab === "tracks"
                                    color: root.downloadsSubTab === "tracks" ? root.accentColor : (trksH.hovered ? "#ffffff" : Theme.textSecondary)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.downloadsSubTab = "tracks"
                                }
                            }

                            // Subtab: Albums
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: root.downloadsSubTab === "albums" 
                                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) 
                                       : (albsH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.color: root.downloadsSubTab === "albums" 
                                              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45) 
                                              : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                HoverHandler { id: albsH }

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Tuyển tập (", "Albums (") + (root.localAlbums ? root.localAlbums.length : 0) + ")"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: root.downloadsSubTab === "albums"
                                    color: root.downloadsSubTab === "albums" ? root.accentColor : (albsH.hovered ? "#ffffff" : Theme.textSecondary)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.downloadsSubTab = "albums"
                                }
                            }
                        }
                    }

                    Text {
                        visible: !root.isDownloadsView && !root.isLoading
                        text: (root.sortedTracks ? root.sortedTracks.length + I18n.tr(" bài", " tracks") : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textSecondary
                    }
                }

                // Unified Toolbar: Play All, Shuffle Play, Sort Options
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.isDownloadsView || (root.isPlaylistView && root.sortedTracks && root.sortedTracks.length > 0)
                    spacing: 12

                    // Primary Play All Button (Emerald Green Solid)
                    Rectangle {
                        height: 36
                        width: playRow.implicitWidth + 24
                        radius: 18
                        color: playH.hovered ? Qt.lighter(root.accentColor, 1.15) : root.accentColor
                        scale: playH.hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            id: playRow
                            anchors.centerIn: parent
                            spacing: 8

                            AppIcon {
                                source: "../assets/icons/media-playback-start-symbolic.svg"
                                iconSize: 15
                                color: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114) > 0.6 ? "#0c0d10" : "#ffffff"
                            }

                            Text {
                                text: I18n.tr("Phát", "Play")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114) > 0.6 ? "#0c0d10" : "#ffffff"
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

                            AppIcon {
                                source: "../assets/icons/media-playlist-shuffle-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: I18n.tr("Phát ngẫu nhiên", "Shuffle")
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

                            AppIcon {
                                source: "../assets/icons/list-add-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: I18n.tr("Hàng đợi", "Queue")
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

                            AppIcon {
                                source: "../assets/icons/download-symbolic.svg"
                                iconSize: 15
                                color: "#ffffff"
                            }

                            Text {
                                text: I18n.tr("Tải Album", "Download Album")
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

                    Item { Layout.fillWidth: true }

                    // Segmented Glass Sort Control (Unified 36px Height, SimpMusic / Apple Music Hi-Fi)
                    Rectangle {
                        height: 36
                        width: sortInnerRow.implicitWidth + 8
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1

                        RowLayout {
                            id: sortInnerRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                Layout.leftMargin: 8
                                Layout.rightMargin: 2
                                text: I18n.tr("Sắp xếp:", "Sort by:")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textMuted
                            }

                            // Pill: Mới nhất
                            Rectangle {
                                height: 28
                                width: sortRecentText.implicitWidth + 20
                                radius: 14
                                color: root.sortBy === "recent" ? Qt.rgba(1, 1, 1, 0.14) : (sortRecentH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.color: root.sortBy === "recent" ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: sortRecentText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Mới nhất", "Latest")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.sortBy === "recent"
                                    color: root.sortBy === "recent" ? "#ffffff" : (sortRecentH.hovered ? "#ffffff" : Theme.textSecondary)
                                }
                                HoverHandler { id: sortRecentH }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortBy = "recent"
                                }
                            }

                            // Pill: Tên A-Z
                            Rectangle {
                                height: 28
                                width: sortTitleText.implicitWidth + 20
                                radius: 14
                                color: root.sortBy === "title" ? Qt.rgba(1, 1, 1, 0.14) : (sortTitleH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.color: root.sortBy === "title" ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: sortTitleText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Tên A-Z", "Title A-Z")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.sortBy === "title"
                                    color: root.sortBy === "title" ? "#ffffff" : (sortTitleH.hovered ? "#ffffff" : Theme.textSecondary)
                                }
                                HoverHandler { id: sortTitleH }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortBy = "title"
                                }
                            }

                            // Pill: Nghệ sĩ
                            Rectangle {
                                height: 28
                                width: sortArtistText.implicitWidth + 20
                                radius: 14
                                color: root.sortBy === "artist" ? Qt.rgba(1, 1, 1, 0.14) : (sortArtistH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.color: root.sortBy === "artist" ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: sortArtistText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Nghệ sĩ", "Artist")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.sortBy === "artist"
                                    color: root.sortBy === "artist" ? "#ffffff" : (sortArtistH.hovered ? "#ffffff" : Theme.textSecondary)
                                }
                                HoverHandler { id: sortArtistH }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortBy = "artist"
                                }
                            }
                        }
                    }
                }

                // Multi-Select Action Bar (Floating Dark Glass banner matching wallpaper theme)
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    color: Qt.rgba(0.08, 0.08, 0.10, 0.90)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    visible: root.isDownloadsView && root.isSelectionMode

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Accent-tinted Selection Count Badge
                        Rectangle {
                            height: 28
                            width: selBadgeRow.implicitWidth + 16
                            radius: 14
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                            border.width: 1

                            RowLayout {
                                id: selBadgeRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    source: "../assets/icons/emblem-ok-symbolic.svg"
                                    iconSize: 12
                                    color: root.accentColor
                                }

                                Text {
                                    text: I18n.tr("Đã chọn: ", "Selected: ") + root.selectedTrackPaths.length + I18n.tr(" bài", " songs")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: root.accentColor
                                }
                            }
                        }

                        // Button: Select All
                        Rectangle {
                            height: 28
                            width: selAllText.implicitWidth + 20
                            radius: 14
                            color: selAllH.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                id: selAllText
                                anchors.centerIn: parent
                                text: I18n.tr("Chọn tất cả", "Select All")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
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
                            width: clearSelText.implicitWidth + 20
                            radius: 14
                            color: clearSelH.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                id: clearSelText
                                anchors.centerIn: parent
                                text: I18n.tr("Bỏ chọn", "Deselect")
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

                        // Button: Create Custom Playlist from Selected (Harmonized with Wallpaper Accent)
                        Rectangle {
                            height: 32
                            width: createPlRow.implicitWidth + 22
                            radius: 16
                            color: createPlH.hovered ? Qt.lighter(root.accentColor, 1.15) : root.accentColor
                            visible: root.selectedTrackPaths.length > 0
                            Behavior on color { ColorAnimation { duration: 100 } }

                            readonly property bool isDarkAccent: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114) > 0.55

                            RowLayout {
                                id: createPlRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    source: "../assets/icons/folder-music-symbolic.svg"
                                    iconSize: 13
                                    color: parent.parent.isDarkAccent ? "#000000" : "#ffffff"
                                }

                                Text {
                                    text: I18n.tr("+ Tạo danh sách phát", "+ New Playlist")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: parent.parent.isDarkAccent ? "#000000" : "#ffffff"
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

                        // Button: Delete Selected (Sophisticated Crimson Glass)
                        Rectangle {
                            height: 32
                            width: delSelRow.implicitWidth + 22
                            radius: 16
                            color: delSelH.hovered ? Qt.rgba(0.85, 0.25, 0.30, 0.32) : Qt.rgba(0.85, 0.25, 0.30, 0.20)
                            border.color: Qt.rgba(0.85, 0.25, 0.30, 0.50)
                            border.width: 1
                            visible: root.selectedTrackPaths.length > 0
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                id: delSelRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    source: "../assets/icons/user-trash-symbolic.svg"
                                    iconSize: 13
                                    color: "#ff8888"
                                }

                                Text {
                                    text: I18n.tr("Xóa (", "Delete (") + root.selectedTrackPaths.length + ")"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ff8888"
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
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: exitSelH.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            HoverHandler { id: exitSelH }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/window-close-symbolic.svg"
                                iconSize: 13
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

                // Skeleton Lazy Loading Grid (Pure Visual Shimmer, Matching TrackCard 176x250 Grid)
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: root.isLoading

                    Repeater {
                        model: [
                            { tw: 120, sw: 80 },
                            { tw: 140, sw: 95 },
                            { tw: 110, sw: 75 },
                            { tw: 130, sw: 85 },
                            { tw: 125, sw: 90 },
                            { tw: 135, sw: 80 },
                            { tw: 115, sw: 70 },
                            { tw: 145, sw: 100 },
                            { tw: 120, sw: 85 },
                            { tw: 130, sw: 75 }
                        ]

                        SkeletonTrackCard {
                            titleWidth: modelData.tw
                            subtitleWidth: modelData.sw
                        }
                    }
                }

                Text {
                    visible: !root.isLoading && (!root.sortedTracks || root.sortedTracks.length === 0)
                    text: root.isPlaylistView ? I18n.tr("Danh sách phát này đang trống. Thêm bài hát bằng menu chuột phải!", "This playlist is empty. Add songs using the context menu on any song!") : I18n.tr("Không tìm thấy bài hát nào. Nhập vào thanh tìm kiếm để khám phá!", "No tracks found. Type in search bar to explore online tracks!")
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
                            color: albCardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.02)
                            border.color: albCardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width

                                    Rectangle {
                                        id: albImgMask
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
                                            maskSource: albImgMask
                                            autoPaddingEnabled: false
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#202024"
                                            visible: !albImg.visible || albImg.status !== Image.Ready
                                        }

                                        Image {
                                            id: albImg
                                            anchors.fill: parent
                                            source: {
                                                if (!modelData || !modelData.image) return "";
                                                var s = modelData.image;
                                                return (s.startsWith("/") && !s.startsWith("file://")) ? ("file://" + s) : s;
                                            }
                                            fillMode: Image.PreserveAspectCrop
                                            scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.25)) ? 1.48 : 1.0
                                            transformOrigin: Item.Center
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !albImg.visible || albImg.status !== Image.Ready
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "#333333" }
                                                GradientStop { position: 1.0; color: "#181818" }
                                            }
                                            AppIcon {
                                                anchors.centerIn: parent
                                                source: "../assets/icons/media-optical-audio-symbolic.svg"
                                                iconSize: 42
                                                color: Qt.rgba(1, 1, 1, 0.25)
                                            }
                                        }
                                    }

                                    // 1px Hairline Border Overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        z: 2
                                    }

                                    // Play Album Button on Hover
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: root.accentColor
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        visible: albCardMouse.containsMouse
                                        z: 10

                                        AppIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            source: "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 16
                                            color: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114) > 0.6 ? "#0c0d10" : "#ffffff"
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
                                    text: (modelData.artist || I18n.tr("Không rõ", "Unknown")) + " • " + (modelData.trackCount || 0) + I18n.tr(" bài", " songs")
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

                // =============================================================
                // SimpMusic Clean Horizontal List View for Downloads
                // =============================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: !root.isLoading && root.isDownloadsView && root.downloadsSubTab === "tracks" && root.albumMetadata === null

                    Repeater {
                        model: root.sortedTracks

                        Rectangle {
                            id: dlRow
                            Layout.fillWidth: true
                            height: 56
                            radius: 8
                            color: dlRow.isCurrentTrack
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                                   : (dlRow.isSelected
                                      ? Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                      : (dlRowMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.02)))
                            border.color: dlRow.isCurrentTrack
                                          ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                          : (dlRowMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06))
                            border.width: 1

                            readonly property bool isCurrentTrack: !!(root.currentTrack && modelData && (root.currentTrack.path === modelData.path || (modelData.videoId && root.currentTrack.videoId === modelData.videoId)))
                            readonly property bool isCurrentPlaying: isCurrentTrack && root.isPlaying
                            readonly property bool isSelected: !!(modelData && modelData.path && root.selectedTrackPaths.indexOf(modelData.path) !== -1)

                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 16
                                spacing: 14

                                // Index Number / Play Icon OR Selection Checkbox
                                Item {
                                    width: 28
                                    height: 28
                                    Layout.alignment: Qt.AlignVCenter

                                    // Checkbox in selection mode
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        radius: 4
                                        visible: root.isSelectionMode
                                        color: dlRow.isSelected ? root.accentColor : "transparent"
                                        border.color: dlRow.isSelected ? root.accentColor : Qt.rgba(1, 1, 1, 0.3)
                                        border.width: 1.5

                                        AppIcon {
                                            anchors.centerIn: parent
                                            visible: dlRow.isSelected
                                            source: "../assets/icons/emblem-ok-symbolic.svg"
                                            iconSize: 12
                                            color: "#000000"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleTrackSelection(modelData)
                                        }
                                    }

                                    // Play icon / Index number in normal mode
                                    Item {
                                        anchors.fill: parent
                                        visible: !root.isSelectionMode

                                        AppIcon {
                                            anchors.centerIn: parent
                                            visible: dlRowMouse.containsMouse || dlRow.isCurrentTrack
                                            source: dlRow.isCurrentPlaying
                                                    ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                    : "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 15
                                            color: dlRow.isCurrentTrack ? root.accentColor : "#ffffff"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !dlRowMouse.containsMouse && !dlRow.isCurrentTrack
                                            text: String(index + 1)
                                            color: Theme.textSecondary
                                            font.pixelSize: 13
                                            font.family: Theme.fontFamily
                                        }
                                    }
                                }

                                // Masked Artwork (42x42, radius 6, matching Home)
                                Item {
                                    width: 42
                                    height: 42
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        id: dlArtMask
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
                                            maskSource: dlArtMask
                                            autoPaddingEnabled: false
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#202024"
                                            visible: !dlArtImg.visible || dlArtImg.status !== Image.Ready
                                        }

                                        Image {
                                            id: dlArtImg
                                            anchors.fill: parent
                                            source: {
                                                if (!modelData || !modelData.image) return "";
                                                var s = modelData.image;
                                                return (s.startsWith("/") && !s.startsWith("file://")) ? ("file://" + s) : s;
                                            }
                                            fillMode: Image.PreserveAspectCrop
                                            scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.25)) ? 1.48 : 1.0
                                            transformOrigin: Item.Center
                                            sourceSize: Qt.size(88, 88)
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        AppIcon {
                                            anchors.centerIn: parent
                                            visible: !dlArtImg.visible || dlArtImg.status !== Image.Ready
                                            source: "../assets/icons/media-optical-audio-symbolic.svg"
                                            iconSize: 20
                                            color: Qt.rgba(1, 1, 1, 0.25)
                                        }
                                    }

                                    // 1px Hairline Border Overlay on top of image (matching Home)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        z: 2
                                    }
                                }

                                // Title & Artist • Album
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.title || I18n.tr("Bài hát không tên", "Unknown Track")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: dlRow.isCurrentTrack ? root.accentColor : Theme.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            var art = modelData.artist || I18n.tr("Nghệ sĩ chưa rõ", "Unknown Artist");
                                            var alb = modelData.album || "";
                                            return (alb && alb !== art) ? (art + " • " + alb) : art;
                                        }
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                // Duration
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.duration || "--:--"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }

                                // 3-Dots Context Menu Button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    color: dlDotsH.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                    HoverHandler { id: dlDotsH }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/view-more-symbolic.svg"
                                        iconSize: 16
                                        color: dlDotsH.hovered ? "#ffffff" : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var pt = dlRow.mapToItem(null, dlRow.width - 200, dlRow.height);
                                            root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dlRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                pressAndHoldInterval: 450

                                property bool wasLongPress: false

                                onPressed: mouse => {
                                    wasLongPress = false;
                                }

                                onPressAndHold: mouse => {
                                    if (mouse.button === Qt.LeftButton && !root.isSelectionMode) {
                                        wasLongPress = true;
                                        root.isSelectionMode = true;
                                        root.toggleTrackSelection(modelData);
                                    }
                                }

                                onClicked: mouse => {
                                    if (wasLongPress) {
                                        wasLongPress = false;
                                        return;
                                    }
                                    if (mouse.button === Qt.RightButton) {
                                        var pt = dlRow.mapToItem(null, mouse.x, mouse.y);
                                        root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                    } else {
                                        if (root.isSelectionMode) {
                                            root.toggleTrackSelection(modelData);
                                        } else {
                                            root.trackPlayRequested(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Grid of tracks (Online searches, or playlists with no hero album)
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: !root.isLoading && (!root.isDownloadsView || root.albumMetadata !== null) && !(root.isDownloadsView && root.downloadsSubTab === "albums")

                    Repeater {
                        model: root.sortedTracks

                        TrackCard {
                            track: modelData
                            accentColor: root.accentColor
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
