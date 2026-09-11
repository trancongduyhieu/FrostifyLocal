import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property var artistData: null
    property bool isLoading: false
    property var currentTrack: null
    property bool isPlaying: false
    property var followedArtists: []

    readonly property bool isFollowed: {
        if (!artistData || !artistData.metadata) return false;
        var chId = artistData.metadata.channelId || artistData.metadata.browseId || "";
        var aName = (artistData.metadata.name || "").toLowerCase().trim();
        if (root.followedArtists && root.followedArtists.length > 0) {
            for (var i = 0; i < root.followedArtists.length; i++) {
                var f = root.followedArtists[i];
                if ((chId && f.channelId === chId) || (aName && (f.name || "").toLowerCase().trim() === aName)) {
                    return true;
                }
            }
        }
        return !!(artistData.metadata && artistData.metadata.subscribed);
    }

    signal backRequested()
    signal playTrackRequested(var trk, int index, var trackList)
    signal startRadioRequested(var item)
    signal shuffleArtistRequested(var artistObj)
    signal viewAlbumRequested(var alb)
    signal openArtistRequested(string artistName, string channelId)
    signal trackContextMenuRequested(var trk, real mouseX, real mouseY)
    signal toggleFollowRequested(string channelId, string artistName, bool currentlyFollowed)

    // Background gradient overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1a1e" }
            GradientStop { position: 0.35; color: "#121214" }
            GradientStop { position: 1.0; color: "#0c0c0e" }
        }
    }

    // Scrollable Content
    Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 80
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 28

            // 1. Hero Artist Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(220, heroRow.implicitHeight + 60)

                // Ambient glow behind header
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 280
                    opacity: 0.45
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.2, 0.25, 0.35, 0.6) }
                        GradientStop { position: 0.8; color: Qt.rgba(0.08, 0.08, 0.1, 0.0) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                RowLayout {
                    id: heroRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 56
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 24

                    // Large Round Artist Avatar
                    Item {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 140

                        // Shimmer placeholder when loading
                        Rectangle {
                            anchors.fill: parent
                            radius: 70
                            color: "#28282c"
                            visible: heroAvatar.status !== Image.Ready
                            SequentialAnimation on opacity {
                                running: heroAvatar.status !== Image.Ready
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.3; to: 0.7; duration: 800; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.7; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                            }
                        }

                        Image {
                            id: heroAvatar
                            anchors.fill: parent
                            source: (root.artistData && root.artistData.metadata && root.artistData.metadata.image) ? root.artistData.metadata.image : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        Rectangle {
                            id: heroAvatarMask
                            anchors.fill: parent
                            radius: 70
                            color: "#000000"
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: heroAvatar
                            maskEnabled: true
                            maskSource: heroAvatarMask
                            visible: heroAvatar.status === Image.Ready
                        }

                        // Border ring
                        Rectangle {
                            anchors.fill: parent
                            radius: 70
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 2
                        }
                    }

                    // Artist Info & 3 Action Buttons
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Category Pill
                        Rectangle {
                            Layout.preferredWidth: badgeText.implicitWidth + 18
                            Layout.preferredHeight: 24
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.10)
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: "Nghệ sĩ"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        // Artist Name
                        Text {
                            Layout.fillWidth: true
                            text: (root.artistData && root.artistData.metadata && root.artistData.metadata.name) ? root.artistData.metadata.name : (root.isLoading ? "Đang tải nghệ sĩ..." : "Nghệ sĩ")
                            font.family: Theme.fontFamily
                            font.pixelSize: 32
                            font.bold: true
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        // Stats (Subscribers & Views)
                        Text {
                            Layout.fillWidth: true
                            text: {
                                var s = "";
                                if (root.artistData && root.artistData.metadata) {
                                    if (root.artistData.metadata.subscribers) s += root.artistData.metadata.subscribers + " người đăng ký";
                                    if (root.artistData.metadata.views) {
                                        if (s) s += " • ";
                                        s += root.artistData.metadata.views;
                                    }
                                }
                                return s || "Nghệ sĩ âm nhạc";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Item { Layout.preferredHeight: 4 }

                        // 3 Action Buttons: Radio, Shuffle, Subscribe
                        RowLayout {
                            spacing: 12

                            // Button 1: Radio
                            Rectangle {
                                Layout.preferredHeight: 38
                                Layout.preferredWidth: radioRow.implicitWidth + 28
                                radius: 19
                                color: radioBtnMouse.containsMouse ? "#2e2e34" : "#222226"
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    id: radioRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    SpotifyIcon {
                                        source: "../assets/icons/radio-symbolic.svg"
                                        iconSize: 16
                                        color: "#ffffff"
                                    }

                                    Text {
                                        text: "Đài phát"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: radioBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.artistData && root.artistData.metadata) {
                                            root.startRadioRequested({
                                                id: root.artistData.metadata.radioId || root.artistData.metadata.channelId,
                                                name: root.artistData.metadata.name,
                                                title: root.artistData.metadata.name,
                                                isRadio: true
                                            });
                                        }
                                    }
                                }
                            }

                            // Button 2: Shuffle
                            Rectangle {
                                Layout.preferredHeight: 38
                                Layout.preferredWidth: shuffleRow.implicitWidth + 28
                                radius: 19
                                color: shuffleBtnMouse.containsMouse ? "#2e2e34" : "#222226"
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    id: shuffleRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    SpotifyIcon {
                                        source: "../assets/icons/media-playlist-shuffle-symbolic.svg"
                                        iconSize: 16
                                        color: "#ffffff"
                                    }

                                    Text {
                                        text: "Xáo trộn"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: shuffleBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.artistData) {
                                            root.shuffleArtistRequested(root.artistData);
                                        }
                                    }
                                }
                            }

                            // Button 3: Follow / Subscribe (Dynamic Toggle)
                            Rectangle {
                                Layout.preferredHeight: 38
                                Layout.preferredWidth: followRow.implicitWidth + 28
                                radius: 19
                                color: root.isFollowed ? Theme.spotifyGreen : (followBtnMouse.containsMouse ? "#2e2e34" : "#222226")
                                border.color: root.isFollowed ? Theme.spotifyGreen : Qt.rgba(1, 1, 1, 0.18)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    id: followRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    SpotifyIcon {
                                        source: root.isFollowed ? "../assets/icons/emblem-ok-symbolic.svg" : "../assets/icons/list-add-symbolic.svg"
                                        iconSize: 15
                                        color: root.isFollowed ? "#000000" : "#ffffff"
                                    }

                                    Text {
                                        text: root.isFollowed ? "Đã theo dõi" : "Theo dõi"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: root.isFollowed ? "#000000" : "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: followBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.artistData && root.artistData.metadata) {
                                            var chId = root.artistData.metadata.channelId || root.artistData.metadata.browseId || "";
                                            var aName = root.artistData.metadata.name || "";
                                            root.toggleFollowRequested(chId, aName, root.isFollowed);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // SKELETON LOADING STATE (When isLoading is true)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: root.isLoading

                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 22
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                Repeater {
                    model: 5
                    SkeletonTrackRow {
                        Layout.fillWidth: true
                    }
                }
            }

            // 2. Section: Popular Songs (Phổ biến)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.popular && root.artistData.popular.length > 0)

                Text {
                    text: "Phổ biến"
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: (root.artistData && root.artistData.popular) ? root.artistData.popular : []

                        Rectangle {
                            id: trackRowItem
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 8
                            color: rowMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            readonly property bool isCurrentPlaying: {
                                if (!root.currentTrack) return false;
                                var p1 = root.currentTrack.videoId || root.currentTrack.path;
                                var p2 = modelData.videoId || modelData.path;
                                return (p1 && p2 && p1 === p2);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 16
                                spacing: 14

                                // Index or Play Icon
                                Item {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(index + 1)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: trackRowItem.isCurrentPlaying ? Theme.spotifyGreen : Theme.textMuted
                                        visible: !rowMouseArea.containsMouse && !trackRowItem.isCurrentPlaying
                                    }

                                    // Playing soundwave indicator
                                    SpotifyIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/media-optical-audio-symbolic.svg"
                                        iconSize: 16
                                        color: Theme.spotifyGreen
                                        visible: trackRowItem.isCurrentPlaying && !rowMouseArea.containsMouse
                                    }

                                    // Play icon on hover
                                    SpotifyIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/media-playback-start-symbolic.svg"
                                        iconSize: 16
                                        color: "#ffffff"
                                        visible: rowMouseArea.containsMouse
                                    }
                                }

                                // Track Artwork
                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 6
                                    color: "#242426"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                // Title & Album/Artist
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.name || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: trackRowItem.isCurrentPlaying ? Theme.spotifyGreen : (rowMouseArea.containsMouse ? "#ffffff" : "#e0e0e4")
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.album || modelData.artist || "Single"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                // Duration
                                Text {
                                    text: modelData.duration || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.textMuted
                                    visible: text !== "" && text !== "--:--"
                                }
                            }

                            MouseArea {
                                id: rowMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pt = trackRowItem.mapToItem(null, mouse.x, mouse.y);
                                        root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                    } else {
                                        root.playTrackRequested(modelData, index, root.artistData.popular);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Section: Albums Carousel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.albums && root.artistData.albums.length > 0)

                // Header with title and pagination arrows
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Albums"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }

                    // Prev Arrow (<)
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: albPrevMouse.containsMouse ? "#38383c" : "#222226"
                        opacity: (albumFlick.contentX > 10) ? 1.0 : 0.35
                        visible: root.artistData && root.artistData.albums && root.artistData.albums.length > 4

                        SpotifyIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/go-previous-symbolic.svg"
                            iconSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: albPrevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var targetX = Math.max(0, albumFlick.contentX - 480);
                                albAnim.to = targetX;
                                albAnim.restart();
                            }
                        }
                    }

                    // Next Arrow (>)
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: albNextMouse.containsMouse ? "#38383c" : "#222226"
                        opacity: (albumFlick.contentX < (albumFlick.contentWidth - albumFlick.width - 10)) ? 1.0 : 0.35
                        visible: root.artistData && root.artistData.albums && root.artistData.albums.length > 4

                        SpotifyIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/go-previous-symbolic.svg"
                            rotation: 180
                            iconSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: albNextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var maxX = Math.max(0, albumFlick.contentWidth - albumFlick.width);
                                var targetX = Math.min(maxX, albumFlick.contentX + 480);
                                albAnim.to = targetX;
                                albAnim.restart();
                            }
                        }
                    }
                }

                Flickable {
                    id: albumFlick
                    Layout.fillWidth: true
                    height: 236
                    contentWidth: albumRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    NumberAnimation on contentX {
                        id: albAnim
                        running: false
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                    RowLayout {
                        id: albumRow
                        spacing: 16

                        Repeater {
                            model: (root.artistData && root.artistData.albums) ? root.artistData.albums : []

                            Rectangle {
                                width: 160
                                height: 228
                                radius: 10
                                color: albCardMouse.containsMouse ? "#242428" : "#18181b"
                                border.color: albCardMouse.containsMouse ? "#38383e" : "#242428"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: width
                                        radius: 8
                                        color: "#26262a"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }

                                        // Play hover pill
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 18
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
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.year ? (modelData.year + " • ") : "") + (modelData.type || "Album")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: albCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.viewAlbumRequested(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. Section: Singles & EPs Carousel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.singles && root.artistData.singles.length > 0)

                // Header with title and pagination arrows
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Đĩa đơn & EPs"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }

                    // Prev Arrow (<)
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: singlePrevMouse.containsMouse ? "#38383c" : "#222226"
                        opacity: (singleFlick.contentX > 10) ? 1.0 : 0.35
                        visible: root.artistData && root.artistData.singles && root.artistData.singles.length > 4

                        SpotifyIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/go-previous-symbolic.svg"
                            iconSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: singlePrevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var targetX = Math.max(0, singleFlick.contentX - 480);
                                singleAnim.to = targetX;
                                singleAnim.restart();
                            }
                        }
                    }

                    // Next Arrow (>)
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: singleNextMouse.containsMouse ? "#38383c" : "#222226"
                        opacity: (singleFlick.contentX < (singleFlick.contentWidth - singleFlick.width - 10)) ? 1.0 : 0.35
                        visible: root.artistData && root.artistData.singles && root.artistData.singles.length > 4

                        SpotifyIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/go-previous-symbolic.svg"
                            rotation: 180
                            iconSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: singleNextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var maxX = Math.max(0, singleFlick.contentWidth - singleFlick.width);
                                var targetX = Math.min(maxX, singleFlick.contentX + 480);
                                singleAnim.to = targetX;
                                singleAnim.restart();
                            }
                        }
                    }
                }

                Flickable {
                    id: singleFlick
                    Layout.fillWidth: true
                    height: 236
                    contentWidth: singleRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    NumberAnimation on contentX {
                        id: singleAnim
                        running: false
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                    RowLayout {
                        id: singleRow
                        spacing: 16

                        Repeater {
                            model: (root.artistData && root.artistData.singles) ? root.artistData.singles : []

                            Rectangle {
                                width: 160
                                height: 228
                                radius: 10
                                color: singleCardMouse.containsMouse ? "#242428" : "#18181b"
                                border.color: singleCardMouse.containsMouse ? "#38383e" : "#242428"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: width
                                        radius: 8
                                        color: "#26262a"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }

                                        // Play hover pill
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: Theme.spotifyGreen
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 6
                                            visible: singleCardMouse.containsMouse

                                            SpotifyIcon {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 1
                                                source: "../assets/icons/media-playback-start-symbolic.svg"
                                                iconSize: 16
                                                color: "#000000"
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.year ? (modelData.year + " • ") : "") + "Đĩa đơn"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: singleCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.viewAlbumRequested(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. Section: Videos Carousel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.videos && root.artistData.videos.length > 0)

                Text {
                    text: "Video âm nhạc"
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                }

                Flickable {
                    id: videoFlick
                    Layout.fillWidth: true
                    height: 180
                    contentWidth: videoRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    RowLayout {
                        id: videoRow
                        spacing: 16

                        Repeater {
                            model: (root.artistData && root.artistData.videos) ? root.artistData.videos : []

                            Rectangle {
                                width: 220
                                height: 172
                                radius: 10
                                color: vidCardMouse.containsMouse ? "#242428" : "#18181b"
                                border.color: vidCardMouse.containsMouse ? "#38383e" : "#242428"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    // Video thumbnail (16:9)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 114
                                        radius: 6
                                        color: "#26262a"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }

                                        // Play hover icon
                                        Rectangle {
                                            width: 34
                                            height: 34
                                            radius: 17
                                            color: Theme.spotifyGreen
                                            anchors.centerIn: parent
                                            visible: vidCardMouse.containsMouse

                                            SpotifyIcon {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 1
                                                source: "../assets/icons/media-playback-start-symbolic.svg"
                                                iconSize: 15
                                                color: "#000000"
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.views || "Video âm nhạc"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }

                                MouseArea {
                                    id: vidCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var trk = {
                                            title: modelData.title,
                                            name: modelData.title,
                                            artist: (root.artistData && root.artistData.metadata) ? root.artistData.metadata.name : "Artist",
                                            videoId: modelData.videoId,
                                            path: "ytdl://" + modelData.videoId,
                                            image: modelData.image
                                        };
                                        root.playTrackRequested(trk, 0, [trk]);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 6. Section: Similar Artists Carousel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.related && root.artistData.related.length > 0)

                Text {
                    text: "Nghệ sĩ liên quan"
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                }

                Flickable {
                    id: relFlick
                    Layout.fillWidth: true
                    height: 196
                    contentWidth: relRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    RowLayout {
                        id: relRow
                        spacing: 20

                        Repeater {
                            model: (root.artistData && root.artistData.related) ? root.artistData.related : []

                            Rectangle {
                                width: 140
                                height: 188
                                radius: 10
                                color: relCardMouse.containsMouse ? "#242428" : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    // Round Avatar
                                    Item {
                                        Layout.preferredWidth: 108
                                        Layout.preferredHeight: 108
                                        Layout.alignment: Qt.AlignHCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 54
                                            color: "#26262a"
                                            visible: relAvatarImg.status !== Image.Ready
                                        }

                                        Image {
                                            id: relAvatarImg
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: false
                                        }

                                        Rectangle {
                                            id: relAvatarMask
                                            anchors.fill: parent
                                            radius: 54
                                            color: "#000000"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            source: relAvatarImg
                                            maskEnabled: true
                                            maskSource: relAvatarMask
                                            visible: relAvatarImg.status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 54
                                            color: "transparent"
                                            border.color: relCardMouse.containsMouse ? Theme.spotifyGreen : Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1.5
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.title || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: relCardMouse.containsMouse ? Theme.spotifyGreen : "#ffffff"
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subscribers ? (modelData.subscribers + " subs") : "Nghệ sĩ"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: relCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.openArtistRequested(modelData.name || modelData.title, modelData.browseId);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 7. Section: Bio / Description Card
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 12
                visible: !root.isLoading && (root.artistData && root.artistData.metadata && root.artistData.metadata.description)

                Text {
                    text: "Giới thiệu"
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: bioCol.implicitHeight + 32
                    radius: 12
                    color: "#161618"
                    border.color: "#28282c"
                    border.width: 1

                    property bool isExpanded: false

                    ColumnLayout {
                        id: bioCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: (root.artistData && root.artistData.metadata) ? root.artistData.metadata.description : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.4
                            color: "#c8c8cc"
                            wrapMode: Text.Wrap
                            maximumLineCount: parent.parent.isExpanded ? 100 : 4
                            elide: Text.ElideRight
                        }

                        Text {
                            text: parent.parent.isExpanded ? "Thu gọn ▲" : "Xem thêm ▼"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.spotifyGreen
                            visible: ((root.artistData && root.artistData.metadata && root.artistData.metadata.description) ? root.artistData.metadata.description.length : 0) > 220

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.parent.parent.isExpanded = !parent.parent.parent.isExpanded
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 30 }
        }
    }

    // Top Floating Navigation Bar (Back Button + Sticky Title)
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 60
        color: mainScroll.contentY > 120 ? Qt.rgba(0.08, 0.08, 0.09, 0.95) : "transparent"
        border.color: mainScroll.contentY > 120 ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        border.width: mainScroll.contentY > 120 ? 1 : 0
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16

            // Back Button
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: backMouse.containsMouse ? "#323236" : Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 16
                    color: "#ffffff"
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.backRequested()
                }
            }

            // Sticky Artist Title
            Text {
                Layout.fillWidth: true
                text: (root.artistData && root.artistData.metadata) ? (root.artistData.metadata.name || "") : ""
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.bold: true
                color: "#ffffff"
                opacity: Math.min(1.0, Math.max(0.0, (mainScroll.contentY - 140) / 60))
                elide: Text.ElideRight
            }
        }
    }
}
