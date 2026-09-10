import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    width: 176
    height: 250
    radius: Theme.radiusCard
    color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard

    Behavior on color { ColorAnimation { duration: 120 } }

    property var track: null
    property bool isPlaying: false
    signal playRequested(var trk)
    signal detailsRequested(var trk)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Album Art Image Container
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width
            radius: 6
            color: "#282828"
            clip: true

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.track && root.track.image ? root.track.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            // Fallback gradient cover if image fails or missing
            Rectangle {
                anchors.fill: parent
                visible: !coverImg.visible
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#333333" }
                    GradientStop { position: 1.0; color: "#181818" }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.track && root.track.artist ? root.track.artist.charAt(0).toUpperCase() : "A"
                    font.family: Theme.fontFamily
                    font.pixelSize: 42
                    font.bold: true
                    color: "#555555"
                }
            }

            // Spotify Floating Green Play Button on Hover
            Rectangle {
                id: greenPlayBtn
                width: 44
                height: 44
                radius: 22
                color: Theme.spotifyGreen
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                z: 10

                // Fade & Slide up on hover
                opacity: cardMouse.containsMouse || root.isPlaying ? 1.0 : 0.0
                y: cardMouse.containsMouse || root.isPlaying ? parent.height - height - 8 : parent.height - height
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                SpotifyIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                    source: root.isPlaying ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                    iconSize: 18
                    color: "#000000"
                }
            }
        }

        // Title
        Text {
            Layout.fillWidth: true
            text: root.track ? root.track.name : ""
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            color: Theme.textPrimary
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // Artist / Subtitle
        Text {
            Layout.fillWidth: true
            text: root.track ? root.track.artist : ""
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textSecondary
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        Item { Layout.fillHeight: true }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        z: 20
        onClicked: root.playRequested(root.track)
    }
}
