import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Rectangle {
    id: root
    width: 240
    color: Theme.bgApp
    radius: Theme.radiusCard

    property var playlists: []
    property var onlinePlaylists: []
    property var queueTracks: []
    property int selectedIndex: 0
    property string currentView: "home"
    property string activePlaylistId: ""
    property var currentTrack: null
    property bool isPlaying: false
    property string sidebarTab: "playlists" // "playlists" or "queue"

    signal homeSelected()
    signal librarySelected()
    signal settingsRequested()
    signal playlistSelected(int index, var pl)
    signal onlinePlaylistSelected(var pl)
    signal trackSelected(var trk)
    signal trackContextMenuRequested(var trk, real globalX, real globalY, bool isQueue)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // 1. Primary Navigation Buttons (Home, Library/Downloads, Settings)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            // Home Button (Online YouTube Music)
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 6
                color: root.currentView === "home" ? Theme.bgHighlight : (homeH.hovered ? Theme.bgCardHover : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                HoverHandler { id: homeH }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 14

                    SpotifyIcon {
                        source: "../assets/icons/go-home-symbolic.svg"
                        iconSize: 18
                        color: root.currentView === "home" ? Theme.spotifyGreen : (homeH.hovered ? "#ffffff" : Theme.textSecondary)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Home (Online)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: root.currentView === "home" ? Theme.spotifyGreen : (homeH.hovered ? "#ffffff" : Theme.textSecondary)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.homeSelected()
                }
            }

            // Downloads / Library Button
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 6
                color: root.currentView === "library" ? Theme.bgHighlight : (libH.hovered ? Theme.bgCardHover : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                HoverHandler { id: libH }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 14

                    SpotifyIcon {
                        source: "../assets/icons/folder-music-symbolic.svg"
                        iconSize: 18
                        color: root.currentView === "library" ? Theme.spotifyGreen : (libH.hovered ? "#ffffff" : Theme.textSecondary)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Downloads (Local)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: root.currentView === "library" ? Theme.spotifyGreen : (libH.hovered ? "#ffffff" : Theme.textSecondary)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.librarySelected()
                }
            }

            // Settings Button
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 6
                color: setH.hovered ? Theme.bgCardHover : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                HoverHandler { id: setH }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 14

                    SpotifyIcon {
                        source: "../assets/icons/preferences-system-symbolic.svg"
                        iconSize: 18
                        color: setH.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Settings & Account"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: setH.hovered ? "#ffffff" : Theme.textSecondary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsRequested()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // 2. Interactive Segmented Tab Switcher [ Playlists | Queue ]
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: "#181818"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                // Playlists Tab Pill
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: root.sidebarTab === "playlists" ? "#282828" : (plTabH.hovered ? "#222222" : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: plTabH }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        SpotifyIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "../assets/icons/media-playlist-consecutive-symbolic.svg"
                            iconSize: 13
                            color: root.sidebarTab === "playlists" ? Theme.spotifyGreen : (plTabH.hovered ? "#ffffff" : Theme.textSecondary)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Playlists"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: root.sidebarTab === "playlists"
                            color: root.sidebarTab === "playlists" ? "#ffffff" : (plTabH.hovered ? "#ffffff" : Theme.textSecondary)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sidebarTab = "playlists"
                    }
                }

                // Queue Tab Pill
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: root.sidebarTab === "queue" ? "#282828" : (qTabH.hovered ? "#222222" : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: qTabH }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        SpotifyIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "../assets/icons/view-queue-symbolic.svg"
                            iconSize: 13
                            color: root.sidebarTab === "queue" ? Theme.spotifyGreen : (qTabH.hovered ? "#ffffff" : Theme.textSecondary)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Queue"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: root.sidebarTab === "queue"
                            color: root.sidebarTab === "queue" ? "#ffffff" : (qTabH.hovered ? "#ffffff" : Theme.textSecondary)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.queueTracks && root.queueTracks.length > 0
                            text: "(" + (root.queueTracks ? root.queueTracks.length : 0) + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.sidebarTab === "queue"
                            color: root.sidebarTab === "queue" ? Theme.spotifyGreen : Theme.textMuted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sidebarTab = "queue"
                    }
                }
            }
        }

        // 3. Tab Content (Playlists List or Queue List)
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.sidebarTab === "playlists" ? 0 : 1

            // Page 0: Playlists List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    // Header subtitle
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.currentView === "library" ? "Local Collections" : "Featured & Moods"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        Text {
                            text: (root.currentView === "library" ? (root.playlists ? root.playlists.length : 0) : ((root.onlinePlaylists && root.onlinePlaylists.length > 0) ? root.onlinePlaylists.length : (root.playlists ? root.playlists.length : 0))) + ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }
                    }

                    ListView {
                        id: plList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        model: root.currentView === "library" ? root.playlists : ((root.onlinePlaylists && root.onlinePlaylists.length > 0) ? root.onlinePlaylists : root.playlists)

                        delegate: Rectangle {
                            id: plItem
                            width: plList.width
                            height: 52
                            radius: 6

                            readonly property bool isLocal: root.currentView === "library" || !modelData.playlistId
                            readonly property bool isSelected: isLocal ? (root.currentView === "library" && index === root.selectedIndex) : ((modelData.playlistId && modelData.playlistId === root.activePlaylistId) || (modelData.id && modelData.id === root.activePlaylistId))

                            color: isSelected ? Theme.bgHighlight : (plH.hovered ? Theme.bgCardHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            HoverHandler { id: plH }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                // 38x38 Thumbnail with rounded corners
                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 4
                                    color: "#242424"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || modelData.thumbnail || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: !!source
                                    }

                                    // Local Collection Letter Avatar Fallback
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !modelData.image && !modelData.thumbnail
                                        text: (modelData.name || modelData.title || "P").charAt(0).toUpperCase()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }

                                // Playlist Title and Subtitle
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.name || "Playlist"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: plItem.isSelected ? Theme.spotifyGreen : (plH.hovered ? "#ffffff" : Theme.textPrimary)
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subtitle || (modelData.count ? (modelData.count + " songs") : (modelData.author || "YouTube Music"))
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }

                                // Equalizer indicator when active and playing
                                Row {
                                    Layout.preferredWidth: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    visible: plItem.isSelected && root.isPlaying

                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 3
                                            height: index === 0 ? 10 : (index === 1 ? 14 : 8)
                                            radius: 1.5
                                            color: Theme.spotifyGreen
                                            anchors.bottom: parent.bottom

                                            SequentialAnimation on height {
                                                running: plItem.isSelected && root.isPlaying
                                                loops: Animation.Infinite
                                                NumberAnimation { to: index === 0 ? 14 : (index === 1 ? 7 : 13); duration: 240 + index * 90; easing.type: Easing.InOutQuad }
                                                NumberAnimation { to: index === 0 ? 6 : (index === 1 ? 14 : 5); duration: 240 + index * 90; easing.type: Easing.InOutQuad }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (plItem.isLocal) {
                                        root.selectedIndex = index;
                                        root.playlistSelected(index, modelData);
                                    } else {
                                        root.activePlaylistId = modelData.playlistId || modelData.id || "";
                                        root.onlinePlaylistSelected(modelData);
                                        root.playlistSelected(index, modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Page 1: Queue List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    // Header subtitle
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4

                        Text {
                            Layout.fillWidth: true
                            text: "Now Playing Queue"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        Text {
                            text: (root.queueTracks ? root.queueTracks.length : 0) + " tracks"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }
                    }

                    // Empty Queue Notice
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        visible: !root.queueTracks || root.queueTracks.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            SpotifyIcon {
                                Layout.alignment: Qt.AlignHCenter
                                source: "../assets/icons/view-queue-symbolic.svg"
                                iconSize: 28
                                color: Theme.textMuted
                            }

                            Text {
                                text: "Queue is empty"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: "Play a playlist or track to start"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Queue ListView
                    ListView {
                        id: qList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 3
                        visible: root.queueTracks && root.queueTracks.length > 0
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        model: root.queueTracks

                        delegate: Rectangle {
                            id: qItem
                            width: qList.width
                            height: 48
                            radius: 6

                            readonly property bool isCurrent: root.currentTrack && (
                                (modelData.videoId && root.currentTrack.videoId && modelData.videoId === root.currentTrack.videoId) ||
                                (modelData.path && root.currentTrack.path && modelData.path === root.currentTrack.path) ||
                                (modelData.id && root.currentTrack.id && modelData.id === root.currentTrack.id)
                            )

                            color: isCurrent ? Theme.bgHighlight : (qRowH.hovered ? Theme.bgCardHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            HoverHandler { id: qRowH }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Track Number or Miniature Cover
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 4
                                    color: "#242424"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: !!source
                                    }

                                    // Fallback index number
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !modelData.image
                                        text: (index + 1) + ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: qItem.isCurrent ? Theme.spotifyGreen : Theme.textMuted
                                    }

                                    // Overlay equalizer if current and playing
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.6)
                                        visible: qItem.isCurrent && root.isPlaying

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Repeater {
                                                model: 3
                                                Rectangle {
                                                    width: 2.5
                                                    height: index === 0 ? 8 : (index === 1 ? 12 : 6)
                                                    radius: 1
                                                    color: Theme.spotifyGreen
                                                    anchors.bottom: parent.bottom

                                                    SequentialAnimation on height {
                                                        running: qItem.isCurrent && root.isPlaying
                                                        loops: Animation.Infinite
                                                        NumberAnimation { to: index === 0 ? 12 : (index === 1 ? 6 : 11); duration: 220 + index * 80; easing.type: Easing.InOutQuad }
                                                        NumberAnimation { to: index === 0 ? 5 : (index === 1 ? 12 : 4); duration: 220 + index * 80; easing.type: Easing.InOutQuad }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Track Details
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.name || "Track"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: qItem.isCurrent ? Theme.spotifyGreen : (qRowH.hovered ? "#ffffff" : Theme.textPrimary)
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.artist || modelData.author || "YouTube Music"
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
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    visible: !!text && text !== "--:--"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pt = qItem.mapToItem(null, mouse.x, mouse.y);
                                        root.trackContextMenuRequested(modelData, pt.x, pt.y, true);
                                    } else {
                                        root.trackSelected(modelData);
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
