import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 280
    color: Theme.bgApp
    radius: Theme.radiusCard

    property var playlists: []
    property int selectedIndex: 0
    signal playlistSelected(int index, var pl)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Your Library Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Your Library"
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                color: Theme.textSecondary
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: plusHover.hovered ? "#282828" : "transparent"
                HoverHandler { id: plusHover }

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Theme.textSecondary
                    font.pixelSize: 20
                    font.family: Theme.fontFamily
                }
            }
        }

        // Library Filter Chips
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 8

            Rectangle {
                height: 28
                width: plChip.implicitWidth + 20
                radius: 14
                color: "#232323"

                Text {
                    id: plChip
                    anchors.centerIn: parent
                    text: "Playlists"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textPrimary
                }
            }

            Rectangle {
                height: 28
                width: albChip.implicitWidth + 20
                radius: 14
                color: "#232323"

                Text {
                    id: albChip
                    anchors.centerIn: parent
                    text: "Albums"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textPrimary
                }
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
                height: 60
                radius: 6
                property bool isSelected: index === root.selectedIndex
                color: isSelected ? Theme.bgHighlight : (rowH.hovered ? Theme.bgCardHover : "transparent")

                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: rowH }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 12

                    // Cover icon / art
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 4
                        color: modelData.id === "all" ? "#5038a0" : (modelData.id === "ado" ? "#1d75bb" : "#242424")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name.charAt(0).toUpperCase()
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    // Playlist details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: plItem.isSelected ? Theme.spotifyGreen : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Playlist • " + (modelData.count || 0) + " songs"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
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
