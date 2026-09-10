import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Rectangle {
    id: root
    color: "#121212"
    radius: Theme.radiusCard
    clip: true

    property var moods: []
    property string selectedMood: "All"
    property var quickPicks: []
    property var featuredPlaylists: []
    property bool isLoading: false
    property var currentTrack: null
    property bool isPlaying: false

    signal moodSelected(string title, string params)
    signal trackPlayRequested(var trk)
    signal playlistSelected(var pl)

    function getGreeting() {
        var h = new Date().getHours();
        if (h >= 5 && h < 12) return "Good Morning";
        if (h >= 12 && h < 18) return "Good Afternoon";
        return "Good Evening";
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: contentCol.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 24

            Item { height: 16 } // Top spacing

            // 1. Header Greeting & Mood Pills Bar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 14

                Text {
                    text: root.getGreeting()
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.textPrimary
                }

                // Mood Pills Horizontal Scroll
                Flickable {
                    Layout.fillWidth: true
                    height: 36
                    contentWidth: moodRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    RowLayout {
                        id: moodRow
                        spacing: 8

                        Repeater {
                            model: root.moods.length > 0 ? root.moods : [
                                { "title": "All", "params": "" },
                                { "title": "Relax", "params": "ggM8SgQIBxADSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Sleep", "params": "ggM8SgQIBxABSgQIBRADSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Energize", "params": "ggM8SgQIBxABSgQIBRABSgQICRADSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Sad", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChADSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Romance", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRADSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Party", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhADSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Commute", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxADSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Feel good", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBADSgQIBhABSgQIBBAB" },
                                { "title": "Focus", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhADSgQIBBAB" },
                                { "title": "Workout", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAD" }
                            ]

                            Rectangle {
                                id: pillRect
                                height: 32
                                width: pillTxt.implicitWidth + 24
                                radius: Theme.radiusPill
                                color: root.selectedMood === modelData.title ? Theme.accentPill : (pillMouse.containsMouse ? "#333333" : "#242424")
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: pillTxt
                                    anchors.centerIn: parent
                                    text: modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.selectedMood === modelData.title ? Theme.accentPillText : Theme.textPrimary
                                }

                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedMood = modelData.title;
                                        root.moodSelected(modelData.title, modelData.params || "");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. Section: "Quick picks" (LET'S START WITH A RADIO)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 12
                visible: root.quickPicks && root.quickPicks.length > 0

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "LET'S START WITH A RADIO"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Quick picks"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                // Grid of Quick picks (2 columns of rows)
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.width > 900 ? 3 : 2
                    rowSpacing: 8
                    columnSpacing: 12

                    Repeater {
                        model: root.quickPicks.slice(0, 18)

                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            radius: 6
                            color: qpMouse.containsMouse ? "#282828" : "#1a1a1a"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 12

                                // Thumbnail with hover play overlay
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 4
                                    color: "#282828"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.4)
                                        visible: qpMouse.containsMouse || (root.currentTrack && root.currentTrack.path === modelData.path)

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            source: (root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying)
                                                    ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                    : "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
                                            color: Theme.spotifyGreen
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
                                        font.bold: true
                                        color: (root.currentTrack && root.currentTrack.path === modelData.path) ? Theme.spotifyGreen : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.artist || "YouTube Music"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: qpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.trackPlayRequested(modelData)
                            }
                        }
                    }
                }
            }

            // 3. Section: "Featured playlists for you"
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 14
                visible: root.featuredPlaylists && root.featuredPlaylists.length > 0

                Text {
                    text: root.selectedMood === "All" ? "Featured playlists for you" : (root.selectedMood + " Playlists")
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: Theme.textPrimary
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 16

                    Repeater {
                        model: root.featuredPlaylists

                        Rectangle {
                            width: 172
                            height: 240
                            radius: Theme.radiusCard
                            color: plMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width
                                    radius: 6
                                    color: "#282828"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    // Spotify Floating Green Play Button on Hover
                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: Theme.spotifyGreen
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        visible: plMouse.containsMouse

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            source: "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
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
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.subtitle || "Playlist"
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
                                id: plMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playlistSelected(modelData)
                            }
                        }
                    }
                }
            }

            // Bottom padding for scroll
            Item { height: 24 }
        }
    }
}
