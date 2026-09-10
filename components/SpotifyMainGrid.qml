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
            spacing: 28

            // Section 1: Popular & Highlights
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.sectionTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.isLoading ? "Loading..." : (root.tracks ? root.tracks.length + " tracks" : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textSecondary
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
                    visible: !root.isLoading && (!root.tracks || root.tracks.length === 0)
                    text: "No tracks found. Type in search bar to explore YouTube Music!"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }

                // Grid of tracks
                Flow {
                    Layout.fillWidth: true
                    spacing: 16

                    Repeater {
                        model: root.tracks

                        TrackCard {
                            track: modelData
                            isPlaying: root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying
                            onPlayRequested: trk => root.trackPlayRequested(trk)
                            onDetailsRequested: trk => root.trackDetailsRequested(trk)
                        }
                    }
                }
            }
        }
    }
}
