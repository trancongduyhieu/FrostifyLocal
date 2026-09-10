import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    height: 48
    radius: 8
    color: isCurrentTrack ? Qt.rgba(168/255, 85/255, 247/255, 0.20) : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
    border.color: isCurrentTrack ? "#a855f7" : "transparent"
    border.width: 1

    property int indexNumber: 1
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackSource: ""
    property string trackPath: ""
    property bool isCurrentTrack: false
    property bool isPlaying: false

    signal trackClicked()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        // Play icon or Index number
        Item {
            width: 24
            height: 24

            SpotifyIcon {
                anchors.centerIn: parent
                visible: mouseArea.containsMouse || row.isCurrentTrack
                source: (row.isCurrentTrack && row.isPlaying)
                        ? "../assets/icons/media-playback-pause-symbolic.svg"
                        : "../assets/icons/media-playback-start-symbolic.svg"
                iconSize: 14
                color: row.isCurrentTrack ? Theme.spotifyGreen : Theme.textPrimary
            }

            Text {
                anchors.centerIn: parent
                visible: !mouseArea.containsMouse && !row.isCurrentTrack
                text: String(row.indexNumber)
                color: Theme.textSecondary
                font.pixelSize: 12
                font.family: Theme.fontFamily
            }
        }

        // Title and Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: row.trackTitle
                color: row.isCurrentTrack ? "#f3e8ff" : "#ffffff"
                font.pixelSize: 13
                font.bold: row.isCurrentTrack
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: row.trackArtist
                color: "#a1a1aa"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Source Pill
        Rectangle {
            width: row.trackSource === "SimpMusic" ? 76 : 70
            height: 20
            radius: 10
            color: row.trackSource === "SimpMusic" ? Qt.rgba(168/255, 85/255, 247/255, 0.2) : Qt.rgba(56/255, 189/255, 248/255, 0.2)
            border.color: row.trackSource === "SimpMusic" ? "#a855f7" : "#38bdf8"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: row.trackSource
                color: row.trackSource === "SimpMusic" ? "#d8b4fe" : "#7dd3fc"
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onDoubleClicked: row.trackClicked()
        onClicked: row.trackClicked()
    }
}
