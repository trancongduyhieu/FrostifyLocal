import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.75)
    visible: false
    z: 999

    property bool isLoggedIn: false
    property string accountName: ""
    property string accountThumb: ""
    property string statusMessage: ""
    property bool isProcessing: false
    property bool syncHistoryToGoogle: true
    property int currentTab: 0 // 0: Google Account, 1: Desktop Lyrics
    property bool desktopLyricsEnabled: true
    property int lyricsPreset: 2 // 1: Gacha, 2: Apple Music 3-Line
    property int customX: -1
    property int customY: -1

    signal closeRequested()
    signal connectRequested(string rawAuth)
    signal logoutRequested()
    signal launchBrowserLoginRequested()
    signal toggleSyncHistoryRequested(bool enabled)
    signal toggleDesktopLyricsRequested(bool enabled)
    signal selectLyricsPresetRequested(int preset)
    signal resetLyricsPositionRequested()

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: dialog
        width: Math.min(560, root.width - 40)
        height: Math.min(540, root.height - 40)
        anchors.centerIn: parent
        radius: 12
        color: "#181818"
        border.color: "#333333"
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            // Prevent clicks inside dialog from closing it
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header: Title & Close Button
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.currentTab === 0 ? "Google & Cloud Account" : "Cài đặt Lời bài hát Desktop"
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeHover.hovered ? "#333333" : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: closeHover }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 14
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // Tab Switcher
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Tab 0: Account
                Rectangle {
                    Layout.preferredWidth: 140
                    height: 34
                    radius: 8
                    color: root.currentTab === 0 ? "#2c2c2c" : (tab0Hover.hovered ? "#222222" : "transparent")
                    border.color: root.currentTab === 0 ? "#444444" : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: tab0Hover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon {
                            source: "../assets/icons/preferences-system-symbolic.svg"
                            iconSize: 14
                            color: root.currentTab === 0 ? Theme.textPrimary : Theme.textSecondary
                        }
                        Text {
                            text: "Tài khoản"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: root.currentTab === 0
                            color: root.currentTab === 0 ? Theme.textPrimary : Theme.textSecondary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 0
                    }
                }

                // Tab 1: Desktop Lyrics
                Rectangle {
                    Layout.preferredWidth: 175
                    height: 34
                    radius: 8
                    color: root.currentTab === 1 ? "#2c2c2c" : (tab1Hover.hovered ? "#222222" : "transparent")
                    border.color: root.currentTab === 1 ? "#444444" : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: tab1Hover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon {
                            source: "../assets/icons/view-lyrics-symbolic.svg"
                            iconSize: 14
                            color: root.currentTab === 1 ? Theme.textPrimary : Theme.textSecondary
                        }
                        Text {
                            text: "Lời bài hát Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: root.currentTab === 1
                            color: root.currentTab === 1 ? Theme.textPrimary : Theme.textSecondary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 1
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // =========================================================
            // TAB 0: Google & Cloud Account
            // =========================================================
            ColumnLayout {
                id: tab0Content
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16
                visible: root.currentTab === 0

            // Connection Status Banner
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 8
                color: root.isLoggedIn ? "#16281e" : "#242424"
                border.color: root.isLoggedIn ? Theme.accentGreen : "#3a3a3a"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.isLoggedIn ? Theme.accentGreen : "#777777"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.isLoggedIn
                              ? ("Connected: " + (root.accountName ? root.accountName : "Google Account"))
                              : "Not Connected (Guest Mode)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: root.isLoggedIn ? Theme.accentGreen : Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    // Logout Button when logged in
                    Rectangle {
                        visible: root.isLoggedIn
                        height: 28
                        width: 80
                        radius: 14
                        color: logoutH.hovered ? "#e22" : "#333333"

                        HoverHandler { id: logoutH }

                        Text {
                            anchors.centerIn: parent
                            text: "Log Out"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.logoutRequested()
                        }
                    }
                }
            }

            // Sync History to Google Toggle (Item 14)
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 8
                color: "#202024"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    AppIcon {
                        source: "../assets/icons/media-playlist-consecutive-symbolic.svg"
                        iconSize: 18
                        color: root.syncHistoryToGoogle ? Theme.accentGreen : Theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Sync Playback History to Cloud Account"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Updates Google Watch History & personalized recommendations"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Toggle switch
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.syncHistoryToGoogle ? Theme.accentGreen : "#3a3a3a"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.syncHistoryToGoogle ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.syncHistoryToGoogle = !root.syncHistoryToGoogle;
                                root.toggleSyncHistoryRequested(root.syncHistoryToGoogle);
                            }
                        }
                    }
                }
            }

            // 1-Click Native Login Button (Nutsty Style)
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 21
                visible: !root.isLoggedIn
                color: root.isProcessing ? "#1db95466" : (browserLoginMouse.containsMouse ? "#1ed760" : Theme.accentGreen)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: root.isProcessing ? "Waiting for Google Sign-In in browser window..." : "Open Google Sign-In Window (1-Click)"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: "#000000"
                }

                MouseArea {
                    id: browserLoginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: root.isProcessing ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root.isProcessing
                    onClicked: root.launchBrowserLoginRequested()
                }
            }

            // Separator text
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !root.isLoggedIn

                Rectangle { Layout.fillWidth: true; height: 1; color: "#2c2c2c" }
                Text {
                    text: "OR PASTE COOKIES MANUALLY"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: "#666666"
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#2c2c2c" }
            }

            // Instructions when not connected
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !root.isLoggedIn

                Text {
                    text: "Paste your Cookie or Request Headers from browser:"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textSecondary
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    radius: 8
                    color: "#121212"
                    border.color: authInput.activeFocus ? Theme.accentGreen : "#2c2c2c"
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8

                        TextArea {
                            id: authInput
                            placeholderText: "Paste raw cookie (e.g. SAPISID=...; SSID=...) or full cURL/Request Headers here..."
                            placeholderTextColor: "#555555"
                            font.family: "Monospace"
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            background: null
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "1-Click Sync: If you use the browser extension, click 'Sync to Nutsty (1-Click)' in the extension, or click 'Paste from Clipboard' below."
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: "#888888"
                    wrapMode: Text.Wrap
                }
            }

            // Status message (e.g. error or success)
            Text {
                Layout.fillWidth: true
                text: root.statusMessage
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: root.statusMessage.indexOf("Success") !== -1 ? Theme.accentGreen : "#ff5555"
                visible: root.statusMessage.length > 0
                wrapMode: Text.Wrap
            }

            Item { Layout.fillHeight: true }

            // Action Buttons with Clean Typography (No emoji, No distracting icons)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !root.isLoggedIn

                // 1-Click Paste from Clipboard button
                Rectangle {
                    height: 38
                    radius: 19
                    color: pasteMouse.containsMouse ? "#333333" : "#242424"
                    border.color: "#3a3a3a"
                    border.width: 1
                    Layout.preferredWidth: pasteTxt.implicitWidth + 32

                    Text {
                        id: pasteTxt
                        anchors.centerIn: parent
                        text: "Paste from Clipboard"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: pasteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            authInput.selectAll();
                            authInput.paste();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 38
                    width: 90
                    radius: 19
                    color: cancelMouse.containsMouse ? "#333333" : "#242424"

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }

                Rectangle {
                    height: 38
                    width: 140
                    radius: 19
                    color: root.isProcessing ? "#1db95488" : (saveMouse.containsMouse ? "#1ed760" : Theme.accentGreen)

                    Text {
                        anchors.centerIn: parent
                        text: root.isProcessing ? "Verifying..." : "Connect & Save"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: "#000000"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: root.isProcessing ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.isProcessing && authInput.text.trim().length > 0
                        onClicked: root.connectRequested(authInput.text.trim())
                    }
                }
            }
        } // Close tab0Content

        // =========================================================
        // TAB 1: Desktop Lyrics Widget Settings
        // =========================================================
        ColumnLayout {
            id: tab1Content
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            visible: root.currentTab === 1

            // Card 1: Toggle On/Off
            Rectangle {
                Layout.fillWidth: true
                height: 64
                radius: 8
                color: "#242424"
                border.color: root.desktopLyricsEnabled ? Theme.accentGreen : "#3a3a3a"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: root.desktopLyricsEnabled ? Qt.rgba(0.11, 0.73, 0.33, 0.2) : "#333333"

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/view-lyrics-symbolic.svg"
                            iconSize: 18
                            color: root.desktopLyricsEnabled ? Theme.accentGreen : Theme.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Hiển thị lời bài hát trên Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Hiển thị lời bài hát nổi trực tiếp trên hình nền Wayland"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                    }

                    // Toggle Switch Pill
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.desktopLyricsEnabled ? Theme.accentGreen : "#444444"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            x: root.desktopLyricsEnabled ? 23 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDesktopLyricsRequested(!root.desktopLyricsEnabled)
                        }
                    }
                }
            }

            // Header for Presets
            Text {
                text: "CHỌN MẪU GIAO DIỆN (PRESETS)"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
                color: Theme.textMuted
                Layout.topMargin: 4
            }

            // Card Mẫu 1: Gacha / Anime Pop
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 8
                color: root.lyricsPreset === 1 ? "#1e2a22" : (p1Hover.hovered ? "#282828" : "#242424")
                border.color: root.lyricsPreset === 1 ? Theme.accentGreen : "#3a3a3a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: p1Hover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: "transparent"
                        border.color: root.lyricsPreset === 1 ? Theme.accentGreen : "#666666"
                        border.width: 2

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accentGreen
                            visible: root.lyricsPreset === 1
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Mẫu 1: Gacha / Anime Pop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectLyricsPresetRequested(1)
                }
            }

            // Card Mẫu 2: Apple Music 5-Line Fluid Sync
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 8
                color: root.lyricsPreset === 2 ? "#1e2a22" : (p2Hover.hovered ? "#282828" : "#242424")
                border.color: root.lyricsPreset === 2 ? Theme.accentGreen : "#3a3a3a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: p2Hover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: "transparent"
                        border.color: root.lyricsPreset === 2 ? Theme.accentGreen : "#666666"
                        border.width: 2

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accentGreen
                            visible: root.lyricsPreset === 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Mẫu 2: Apple Music 5-Line Fluid Sync"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Rectangle {
                            height: 16
                            width: 38
                            radius: 4
                            color: Theme.accentGreen

                            Text {
                                anchors.centerIn: parent
                                text: "MỚI"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: "#000000"
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectLyricsPresetRequested(2)
                }
            }

            // Card 3: Positioning & Reset
            Rectangle {
                Layout.fillWidth: true
                height: 64
                radius: 8
                color: "#1e1e1e"
                border.color: "#333333"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Vị trí hiển thị trên màn hình"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: (root.customX >= 0 && root.customY >= 0) ? ("Tùy chỉnh (" + root.customX + ", " + root.customY + ") • Kéo thả trực tiếp trên Desktop.") : "Mặc định (theo tỷ lệ màn hình) • Kéo thả trực tiếp trên Desktop."
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    Rectangle {
                        height: 32
                        width: 140
                        radius: 6
                        color: resetHover.hovered ? "#3a3a3a" : "#2c2c2c"
                        border.color: "#444444"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        HoverHandler { id: resetHover }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            AppIcon {
                                source: "../assets/icons/media-playlist-repeat-symbolic.svg"
                                iconSize: 12
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "Đặt lại mặc định"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetLyricsPositionRequested()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
}

