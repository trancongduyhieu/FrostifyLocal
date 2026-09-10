import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    height: 64
    color: "transparent"

    property string currentTab: "all"
    property string currentView: "home"
    signal tabSelected(string tab)
    signal searchRequested(string query)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14

        // Spotify Navigation buttons: Back / Forward
        RowLayout {
            spacing: 8

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: prevNavH.hovered ? "#282828" : "#181818"
                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: prevNavH }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    color: Theme.textSecondary
                }
            }

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: nextNavH.hovered ? "#282828" : "#181818"
                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: nextNavH }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    rotation: 180
                    color: Theme.textMuted
                }
            }
        }

        // Spotify Search Bar
        Rectangle {
            Layout.preferredWidth: 340
            Layout.preferredHeight: 40
            radius: 20
            color: "#242424"
            border.color: searchInput.activeFocus ? "#535353" : "transparent"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                SpotifyIcon {
                    source: "../assets/icons/system-search-symbolic.svg"
                    iconSize: 16
                    color: searchInput.activeFocus ? "#ffffff" : Theme.textSecondary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    selectByMouse: true
                    onTextChanged: root.searchRequested(text)

                    Text {
                        text: root.currentTab === "ytmusic" ? "Search YouTube Music online..." : "What do you want to play?"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textSecondary
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                // Clear search icon
                Item {
                    width: 20; height: 20
                    visible: searchInput.text.length > 0
                    HoverHandler { id: clearH }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 12
                        color: clearH.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            root.searchRequested("");
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
