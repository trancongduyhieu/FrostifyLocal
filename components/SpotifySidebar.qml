import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    width: 240
    color: Theme.bgApp
    radius: Theme.radiusCard

    property var playlists: []
    property int selectedIndex: 0
    property string currentView: "home"

    signal homeSelected()
    signal librarySelected()
    signal settingsRequested()
    signal playlistSelected(int index, var pl)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // 1. Primary Navigation Buttons (Home, Library/Downloads, Settings)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            // Home Button (Online YouTube Music)
            Rectangle {
                Layout.fillWidth: true
                height: 44
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
                height: 44
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
                height: 44
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
            color: "#282828"
        }

        // 2. Downloaded Playlists Section
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Local Collections"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: Theme.textSecondary
            }
        }

        // Playlists List
        ListView {
            id: plList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.playlists

            delegate: Rectangle {
                id: plItem
                width: plList.width
                height: 52
                radius: 6
                property bool isSelected: root.currentView === "library" && index === root.selectedIndex
                color: isSelected ? Theme.bgHighlight : (rowH.hovered ? Theme.bgCardHover : "transparent")

                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: rowH }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 4
                        color: modelData.id === "all" ? "#5038a0" : (modelData.id === "ado" ? "#1d75bb" : "#242424")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name.charAt(0).toUpperCase()
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: plItem.isSelected ? Theme.spotifyGreen : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (modelData.count || 0) + " songs"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedIndex = index;
                        root.playlistSelected(index, modelData);
                    }
                }
            }
        }
    }
}
