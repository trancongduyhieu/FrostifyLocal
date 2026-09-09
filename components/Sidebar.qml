import QtQuick.Controls.Basic
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    property var playlists: []
    property int selectedIndex: 0

    signal playlistSelected(int index, var playlist)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // App Branding / Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 6
            spacing: 8

            Text {
                text: "❄"
                font.pixelSize: 18
                color: Theme.accent
            }

            Text {
                text: "frostify"
                color: Theme.text
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 0.5
            }

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 18
                radius: 4
                color: Theme.accentSoft
                border.color: Theme.accent
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "OFFLINE"
                    color: Theme.accent
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }

        // Section Label
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.topMargin: 6
            text: "PLAYLISTS"
            color: Theme.subtext
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
        }

        // Playlists List
        ListView {
            id: plView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: root.playlists

            delegate: Rectangle {
                id: plRow
                width: plView.width
                height: 34
                radius: Theme.radiusSm
                property bool isSelected: index === root.selectedIndex

                color: isSelected ? Theme.sel
                                  : (plHover.hovered ? Theme.glassSoft : "transparent")

                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: plHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: modelData.pinned ? "📌"
                            : (modelData.id === "all" ? "♫"
                            : (modelData.id === "simp" ? "🎧"
                            : (modelData.id === "downloads" ? "📥" : "♥")))
                        color: plRow.isSelected ? Theme.selText : Theme.teal
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: plRow.isSelected ? Theme.selText : Theme.text
                        font.pixelSize: 13
                        font.bold: plRow.isSelected
                        elide: Text.ElideRight
                    }

                    Text {
                        text: String(modelData.count || 0)
                        color: plRow.isSelected ? Theme.selText : Theme.subtext
                        font.pixelSize: 11
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

        // Bottom shortcut card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: Theme.radiusSm
            color: Theme.glassSoft
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Text {
                    text: "⌨ Phím tắt"
                    color: Theme.teal
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    text: "Space: Phát/Dừng • ↑/↓: Chọn bài"
                    color: Theme.subtext
                    font.pixelSize: 10
                }
            }
        }
    }
}
