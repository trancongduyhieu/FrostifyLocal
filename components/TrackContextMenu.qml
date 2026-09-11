import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: isOpen ? 1 : 0
    z: 9999

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    property bool isOpen: false
    property var track: null
    property bool isQueueItem: false
    property real targetX: 0
    property real targetY: 0

    signal playNextRequested(var track)
    signal addToQueueRequested(var track)
    signal startRadioRequested(var track)
    signal openFolderRequested(var track)
    signal downloadTrackRequested(var track)
    signal removeFromQueueRequested(var track)
    signal deleteTrackRequested(var track)

    function openAt(posTrack, xPos, yPos, queueItem) {
        root.track = posTrack;
        root.isQueueItem = !!queueItem;
        root.targetX = xPos;
        root.targetY = yPos;
        root.isOpen = true;
    }

    function closeMenu() {
        root.isOpen = false;
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.closeMenu()
    }

    // Context Menu Card
    Rectangle {
        id: menuCard
        width: 230
        height: menuCol.implicitHeight + 16
        radius: 10
        color: Qt.rgba(0.11, 0.11, 0.13, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        // Clamping to avoid window borders
        x: Math.max(12, Math.min(root.targetX, root.width - width - 12))
        y: Math.max(12, Math.min(root.targetY, root.height - height - 12))

        scale: root.isOpen ? 1 : 0.95
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }

        // Prevent click propagation through menu card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => mouse.accepted = true
        }

        Column {
            id: menuCol
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            // Track header
            Item {
                width: parent.width
                height: 40
                visible: root.track !== null

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 4
                        color: "#222"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: (root.track && root.track.image) ? root.track.image : ""
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: (root.track && (root.track.title || root.track.name)) ? (root.track.title || root.track.name) : "Track"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (root.track && root.track.artist) ? root.track.artist : "Unknown Artist"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - 16
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.track !== null
            }

            // Action 1: Play next
            MenuItemButton {
                text: "Play next"
                iconSource: "../assets/icons/media-playlist-consecutive-symbolic.svg"
                onClicked: {
                    root.closeMenu();
                    root.playNextRequested(root.track);
                }
            }

            // Action 2: Add to queue
            MenuItemButton {
                text: "Add to queue"
                iconSource: "../assets/icons/view-queue-symbolic.svg"
                onClicked: {
                    root.closeMenu();
                    root.addToQueueRequested(root.track);
                }
            }

            // Action 3: Start radio
            MenuItemButton {
                text: "Start radio"
                iconSource: "../assets/icons/radio-symbolic.svg"
                onClicked: {
                    root.closeMenu();
                    root.startRadioRequested(root.track);
                }
            }

            Rectangle {
                width: parent.width - 16
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Action 4: Open folder (local) or Download (online)
            MenuItemButton {
                property bool isLocal: root.track && !root.track.videoId && (!root.track.path || !root.track.path.startsWith("ytdl://"))
                text: isLocal ? "Open containing folder" : "Download track"
                iconSource: isLocal ? "../assets/icons/folder-music-symbolic.svg" : "../assets/icons/download-symbolic.svg"
                onClicked: {
                    root.closeMenu();
                    if (isLocal) {
                        root.openFolderRequested(root.track);
                    } else {
                        root.downloadTrackRequested(root.track);
                    }
                }
            }

            Rectangle {
                width: parent.width - 16
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.isQueueItem || (root.track && !root.track.videoId && (!root.track.path || !root.track.path.startsWith("ytdl://")))
            }

            // Action 5: Remove from Queue or Delete
            MenuItemButton {
                visible: root.isQueueItem || (root.track && !root.track.videoId && (!root.track.path || !root.track.path.startsWith("ytdl://")))
                text: root.isQueueItem ? "Remove from queue" : "Delete from library"
                textColor: "#ff5252"
                iconColor: "#ff5252"
                iconSource: "../assets/icons/user-trash-symbolic.svg"
                onClicked: {
                    root.closeMenu();
                    if (root.isQueueItem) {
                        root.removeFromQueueRequested(root.track);
                    } else {
                        root.deleteTrackRequested(root.track);
                    }
                }
            }
        }
    }

    component MenuItemButton: Rectangle {
        id: itemBtn
        width: parent ? parent.width - 8 : 214
        height: 32
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 6
        color: btnHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent"

        property string text: ""
        property string iconSource: ""
        property color textColor: Theme.textPrimary
        property color iconColor: Theme.textSecondary
        signal clicked()

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            SpotifyIcon {
                source: itemBtn.iconSource
                color: btnHover.hovered ? itemBtn.textColor : itemBtn.iconColor
                iconSize: 15
            }

            Text {
                Layout.fillWidth: true
                text: itemBtn.text
                color: itemBtn.textColor
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            id: btnHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: itemBtn.clicked()
        }
    }
}
