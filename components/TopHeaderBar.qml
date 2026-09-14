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
    property bool isSidebarVisible: false
    property bool isMaximized: false
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property Item backgroundSourceItem: null

    signal tabSelected(string tab)
    signal searchRequested(string query, string mode)
    signal searchSubmitted(string query, string mode)
    signal backRequested()
    signal forwardRequested()
    signal downloadPopoverRequested()
    signal toggleSidebarRequested()
    signal maximizeWindowRequested()
    signal closeWindowRequested()
    signal homeClicked()
    signal libraryClicked()
    signal settingsClicked()

    onCurrentViewChanged: {
        searchMode = (currentView === "library" ? "offline" : "online");
        suggestions = [];
        if (currentView !== "search" && (!searchInput.text || searchInput.text.trim() === "")) {
            isSearching = false;
        }
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

        // Search Bar Container (Collapsible: Pure Borderless Icon when idle, smooth expandable glass input on click)
        Item {
            id: searchContainer
            Layout.preferredWidth: headerRoot.isSearching ? 340 : 32
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            z: 200

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: searchBarBox
                anchors.fill: parent
                radius: 17
                color: headerRoot.isSearching ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                border.color: headerRoot.isSearching ? (searchInput.activeFocus ? headerRoot.accentColor : Qt.rgba(1, 1, 1, 0.15)) : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: headerRoot.isSearching ? 10 : 0
                    anchors.rightMargin: headerRoot.isSearching ? 10 : 0
                    spacing: 8

                    // Search Icon Button (Pure borderless icon matching Home, Downloads, Library, Settings)
                    Item {
                        id: searchIconBtn
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/system-search-symbolic.svg"
                            iconSize: 17
                            color: headerRoot.accentColor
                            opacity: (headerRoot.isSearching || searchIconMouse.containsMouse) ? 1.0 : 0.70
                            scale: searchIconMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: searchIconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!headerRoot.isSearching) {
                                    headerRoot.isSearching = true;
                                    searchInput.forceActiveFocus();
                                } else {
                                    if (searchInput.text && searchInput.text.trim().length > 0) {
                                        headerRoot.suggestions = [];
                                        headerRoot.searchSubmitted(searchInput.text.trim(), headerRoot.searchMode);
                                    } else {
                                        headerRoot.isSearching = false;
                                    }
                                }
                            }
                        }
                    }

                    // Text Input Field (Visible when expanded)
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectByMouse: true
                        visible: headerRoot.isSearching
                        clip: true

                        onTextChanged: {
                            headerRoot.searchRequested(text, headerRoot.searchMode);
                        }

                        onAccepted: {
                            headerRoot.suggestions = [];
                            headerRoot.searchSubmitted(text, headerRoot.searchMode);
                        }

                        Keys.onEscapePressed: {
                            if (text.length > 0) {
                                text = "";
                                headerRoot.suggestions = [];
                                headerRoot.searchRequested("", headerRoot.searchMode);
                            } else {
                                headerRoot.isSearching = false;
                            }
                        }

                        Text {
                            text: headerRoot.currentView === "library" ? "Search downloads..." : "Search songs, albums..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textSecondary
                            visible: !searchInput.text && !searchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Clear search icon / Close button
                    Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        visible: headerRoot.isSearching

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
                                if (searchInput.text.length > 0) {
                                    searchInput.text = "";
                                    headerRoot.suggestions = [];
                                    headerRoot.searchRequested("", headerRoot.searchMode);
                                    searchInput.forceActiveFocus();
                                } else {
                                    headerRoot.isSearching = false;
                                }
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
                visible: headerRoot.isSearching && searchInput.activeFocus && headerRoot.suggestions && headerRoot.suggestions.length > 0
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

        // Top Navigation Cluster: Downloads, Home, Library, Settings (Pure Borderless Icons matching wallpaper accent)
        RowLayout {
            spacing: 12

            // 0. Downloads Button (Icon only, pure borderless)
            Item {
                id: downloadQueueBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                readonly property bool hasActive: typeof downloadManager !== "undefined" && downloadManager && downloadManager.activeTasksCount > 0
                visible: true

                CircularSpinner {
                    anchors.centerIn: parent
                    visible: downloadQueueBtn.hasActive
                    running: downloadQueueBtn.hasActive
                    color: headerRoot.accentColor
                    size: 16
                    strokeWidth: 2
                }

                AppIcon {
                    anchors.centerIn: parent
                    visible: !downloadQueueBtn.hasActive
                    source: "../assets/icons/download-symbolic.svg"
                    iconSize: 17
                    color: headerRoot.accentColor
                    opacity: dlMouse.containsMouse ? 1.0 : 0.70
                    scale: dlMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
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

            // 1. Home Button
            Item {
                id: homeBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-home-symbolic.svg"
                    iconSize: 17
                    color: headerRoot.accentColor
                    opacity: headerRoot.currentView === "home" ? 1.0 : (homeMouse.containsMouse ? 1.0 : 0.70)
                    scale: homeMouse.containsMouse ? 1.12 : (headerRoot.currentView === "home" ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: homeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerRoot.homeClicked()
                }
            }

            // 2. Downloads / Local Library Button
            Item {
                id: libBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/folder-music-symbolic.svg"
                    iconSize: 17
                    color: headerRoot.accentColor
                    opacity: headerRoot.currentView === "library" ? 1.0 : (libMouse.containsMouse ? 1.0 : 0.70)
                    scale: libMouse.containsMouse ? 1.12 : (headerRoot.currentView === "library" ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: libMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerRoot.libraryClicked()
                }
            }

            // 3. Settings & Account Button
            Item {
                id: setBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/preferences-system-symbolic.svg"
                    iconSize: 17
                    color: headerRoot.accentColor
                    opacity: setMouse.containsMouse ? 1.0 : 0.70
                    scale: setMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: setMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerRoot.settingsClicked()
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
