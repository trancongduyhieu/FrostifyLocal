import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: headerRoot
    height: 64
    color: "transparent"
    z: 100

    property string currentTab: "all"
    property string currentView: "home"
    property string searchMode: currentView === "library" ? "offline" : "online"
    property var suggestions: []
    property bool isSearching: false
    property bool canGoBack: currentView !== "home"
    property bool isSidebarVisible: true
    property bool isMaximized: false

    signal tabSelected(string tab)
    signal searchRequested(string query, string mode)
    signal searchSubmitted(string query, string mode)
    signal backRequested()
    signal forwardRequested()
    signal downloadPopoverRequested()
    signal toggleSidebarRequested()
    signal maximizeWindowRequested()
    signal closeWindowRequested()

    onCurrentViewChanged: {
        searchMode = (currentView === "library" ? "offline" : "online");
        suggestions = [];
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14

        // Navigation buttons: Sidebar Toggle / Back / Forward
        RowLayout {
            spacing: 8

            // Left Sidebar Collapse / Expand Toggle
            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: sbM.containsMouse ? "#282828" : "#181818"
                Behavior on color { ColorAnimation { duration: 100 } }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/view-queue-symbolic.svg"
                    iconSize: 15
                    color: headerRoot.isSidebarVisible ? Theme.accentGreen : (sbM.containsMouse ? "#ffffff" : Theme.textMuted)
                }

                MouseArea {
                    id: sbM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerRoot.toggleSidebarRequested()
                }
            }

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: headerRoot.canGoBack && prevNavM.containsMouse ? "#282828" : "#181818"
                opacity: headerRoot.canGoBack ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on opacity { NumberAnimation { duration: 100 } }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 14
                    color: headerRoot.canGoBack ? "#ffffff" : Theme.textMuted
                }

                MouseArea {
                    id: prevNavM
                    anchors.fill: parent
                    hoverEnabled: headerRoot.canGoBack
                    cursorShape: headerRoot.canGoBack ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (headerRoot.canGoBack) {
                            headerRoot.backRequested();
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

                AppIcon {
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

                    AppIcon {
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
                            headerRoot.searchRequested(text, headerRoot.searchMode);
                        }

                        onAccepted: {
                            headerRoot.suggestions = [];
                            headerRoot.searchSubmitted(text, headerRoot.searchMode);
                        }

                        Text {
                            text: headerRoot.currentView === "library" ? "Search downloads & local library..." : "Search songs, albums, artists..."
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

                        AppIcon {
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
                                headerRoot.suggestions = [];
                                headerRoot.searchRequested("", headerRoot.searchMode);
                            }
                        }
                    }
                }
            }

            // Suggestions Dropdown Popup (Nutsty style)
            Rectangle {
                id: suggestionsPopup
                anchors.top: searchBarBox.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.min(suggestionsList.contentHeight + 12, 280)
                visible: searchInput.activeFocus && headerRoot.suggestions && headerRoot.suggestions.length > 0
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
                    model: headerRoot.suggestions
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

                            AppIcon {
                                source: headerRoot.searchMode === "online" ? "../assets/icons/system-search-symbolic.svg" : "../assets/icons/audio-only-symbolic.svg"
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
                                headerRoot.suggestions = [];
                                headerRoot.searchSubmitted(val, headerRoot.searchMode);
                            }
                        }
                    }
                }
            }
        }

        // Active Download Queue Pill (Nutsty Style - Persistent & Interactive)
        Rectangle {
            id: downloadQueuePill
            Layout.preferredHeight: 34
            Layout.preferredWidth: dlRow.implicitWidth + 24
            radius: 17
            readonly property bool hasActive: typeof downloadManager !== "undefined" && downloadManager && downloadManager.activeTasksCount > 0
            color: dlMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.color: hasActive ? Qt.rgba(30, 215, 96, 0.4) : (dlMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08))
            border.width: 1
            visible: true

            RowLayout {
                id: dlRow
                anchors.centerIn: parent
                spacing: 8

                CircularSpinner {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    visible: downloadQueuePill.hasActive
                    running: downloadQueuePill.hasActive
                    color: Theme.accentGreen
                    size: 14
                    strokeWidth: 2
                }

                AppIcon {
                    visible: !downloadQueuePill.hasActive
                    source: "../assets/icons/download-symbolic.svg"
                    iconSize: 14
                    color: dlMouse.containsMouse ? "#ffffff" : Theme.textSecondary
                }

                Text {
                    text: downloadQueuePill.hasActive
                          ? ("Downloading (" + (downloadManager ? downloadManager.activeTasksCount : 0) + ")")
                          : "Downloads"
                    color: downloadQueuePill.hasActive ? Theme.accentGreen : (dlMouse.containsMouse ? "#ffffff" : Theme.textSecondary)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: dlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    headerRoot.downloadPopoverRequested();
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Window Maximize / Restore Button [ ◻ ]
        Rectangle {
            id: maxBtn
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: maxMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            AppIcon {
                anchors.centerIn: parent
                source: headerRoot.isMaximized ? "../assets/icons/window-restore-symbolic.svg" : "../assets/icons/window-maximize-symbolic.svg"
                iconSize: 14
                color: "#ffffff"
            }

            MouseArea {
                id: maxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: headerRoot.maximizeWindowRequested()
            }
        }

        // Window Close Button [ ✕ ] (Closes / Minimizes to Desktop Widget)
        Rectangle {
            id: closeBtn
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: closeMouse.containsMouse ? "#E81123" : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            AppIcon {
                anchors.centerIn: parent
                source: "../assets/icons/window-close-symbolic.svg"
                iconSize: 14
                color: "#ffffff"
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: headerRoot.closeWindowRequested()
            }
        }
    }
}
