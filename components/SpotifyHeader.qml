import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    height: 64
    color: "transparent"
    z: 100

    property string currentTab: "all"
    property string currentView: "home"
    property string searchMode: currentView === "library" ? "offline" : "online"
    property var suggestions: []
    property bool isSearching: false
    property bool canGoBack: currentView !== "home"

    signal tabSelected(string tab)
    signal searchRequested(string query, string mode)
    signal searchSubmitted(string query, string mode)
    signal backRequested()
    signal forwardRequested()

    onCurrentViewChanged: {
        searchMode = (currentView === "library" ? "offline" : "online");
        suggestions = [];
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14

        // Navigation buttons: Back / Forward
        RowLayout {
            spacing: 8

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: root.canGoBack && prevNavM.containsMouse ? "#282828" : "#181818"
                opacity: root.canGoBack ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on opacity { NumberAnimation { duration: 100 } }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    color: root.canGoBack ? "#ffffff" : Theme.textMuted
                }

                MouseArea {
                    id: prevNavM
                    anchors.fill: parent
                    hoverEnabled: root.canGoBack
                    cursorShape: root.canGoBack ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.canGoBack) {
                            root.backRequested();
                        }
                    }
                }
            }

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: nextNavM.containsMouse ? "#282828" : "#181818"
                opacity: 0.4
                Behavior on color { ColorAnimation { duration: 100 } }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    rotation: 180
                    color: Theme.textMuted
                }

                MouseArea {
                    id: nextNavM
                    anchors.fill: parent
                    hoverEnabled: false
                    cursorShape: Qt.ArrowCursor
                }
            }
        }

        // Search Bar Container
        Item {
            id: searchContainer
            Layout.preferredWidth: 400
            Layout.preferredHeight: 40
            z: 200

            Rectangle {
                id: searchBarBox
                anchors.fill: parent
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

                        onTextChanged: {
                            root.searchRequested(text, root.searchMode);
                        }

                        onAccepted: {
                            root.suggestions = [];
                            root.searchSubmitted(text, root.searchMode);
                        }

                        Text {
                            text: root.currentView === "library" ? "Search downloads & local library..." : "Search songs, albums, artists..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textSecondary
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    // Clear search icon
                    Item {
                        width: 20
                        height: 20
                        visible: searchInput.text.length > 0

                        SpotifyIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/window-close-symbolic.svg"
                            iconSize: 12
                            color: clearM.containsMouse ? "#ffffff" : Theme.textSecondary
                        }

                        MouseArea {
                            id: clearM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.suggestions = [];
                                root.searchRequested("", root.searchMode);
                            }
                        }
                    }
                }
            }

            // Suggestions Dropdown Popup (SimpMusic style)
            Rectangle {
                id: suggestionsPopup
                anchors.top: searchBarBox.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.min(suggestionsList.contentHeight + 12, 280)
                visible: searchInput.activeFocus && root.suggestions && root.suggestions.length > 0
                color: "#18181c"
                radius: 12
                border.color: "#323238"
                border.width: 1
                clip: true
                z: 300

                ListView {
                    id: suggestionsList
                    anchors.fill: parent
                    anchors.margins: 6
                    model: root.suggestions
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: sugItem
                        width: suggestionsList.width
                        height: 36
                        radius: 8
                        color: sugArea.containsMouse ? "#282830" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            SpotifyIcon {
                                source: root.searchMode === "online" ? "../assets/icons/system-search-symbolic.svg" : "../assets/icons/audio-only-symbolic.svg"
                                iconSize: 14
                                color: sugArea.containsMouse ? "#ffffff" : Theme.textMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: sugArea.containsMouse ? "#ffffff" : Theme.textPrimary
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: sugArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: {
                                var val = modelData;
                                searchInput.text = val;
                                root.suggestions = [];
                                root.searchSubmitted(val, root.searchMode);
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
