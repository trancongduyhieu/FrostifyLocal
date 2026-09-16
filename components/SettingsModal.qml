import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.58)
    visible: false
    z: 999

    // =========================================================================
    // Core Properties & State (100% preserved for shell.qml integration)
    // =========================================================================
    property Item backgroundSourceItem: null
    property bool isLoggedIn: false
    property string accountName: ""
    property string accountThumb: ""
    property string accountEmail: ""
    property string statusMessage: ""
    property bool isProcessing: false
    property bool syncHistoryToGoogle: true
    property bool animatedCoverEnabled: true
    property int currentTab: 0 // 0: Google Account, 1: Desktop Lyrics
    property bool desktopLyricsEnabled: true
    property int lyricsPreset: 2 // 1: Gacha, 2: Apple Music 5-Line, 3: Minimalist Blur, 4: Anime MV Kinetic
    property int customX: -1
    property int customY: -1
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

    // =========================================================================
    // Signals (100% preserved for shell.qml integration)
    // =========================================================================
    signal closeRequested()
    signal connectRequested(string rawAuth)
    signal logoutRequested()
    signal launchBrowserLoginRequested()
    signal toggleSyncHistoryRequested(bool enabled)
    signal toggleAnimatedCoverRequested(bool enabled)
    signal toggleDesktopLyricsRequested(bool enabled)
    signal selectLyricsPresetRequested(int preset)
    signal resetLyricsPositionRequested()

    // =========================================================================
    // Authentic Fonts for Bento Preview Displays
    // =========================================================================
    FontLoader {
        id: instrumentSerifFont
        source: "../assets/fonts/InstrumentSerif-Regular.ttf"
    }

    FontLoader {
        id: instrumentSerifItalicFont
        source: "../assets/fonts/InstrumentSerif-Italic.ttf"
    }

    readonly property string magicFontFamily: (instrumentSerifFont.status === FontLoader.Ready && instrumentSerifFont.name !== "") ? instrumentSerifFont.name : "Instrument Serif"

    FontLoader {
        id: montserratBlackFont
        source: "../assets/fonts/Montserrat-Black.ttf"
    }

    readonly property string heavyFontFamily: (montserratBlackFont.status === FontLoader.Ready && montserratBlackFont.name !== "") ? montserratBlackFont.name : "Montserrat"

    // Click on backdrop dismisses modal
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // =========================================================================
    // Elevation: MultiEffect Drop Shadow behind Dialog
    // =========================================================================
    Rectangle {
        id: shadowShape
        anchors.fill: dialog
        radius: dialog.radius
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: shadowShape
        source: shadowShape
        shadowEnabled: true
        shadowColor: "#80000000"
        shadowVerticalOffset: 6
        shadowBlur: 0.65
        z: 1
    }

    // =========================================================================
    // Main Dialog Container: Keo 502 Optical Resin (LiquidGlass, 20px Radius)
    // =========================================================================
    LiquidGlass {
        id: dialog
        width: Math.min(600, root.width - 32)
        height: {
            if (root.currentTab === 1) {
                return Math.min(540, root.height - 48);
            } else {
                return root.isLoggedIn ? Math.min(320, root.height - 48) : Math.min(480, root.height - 48);
            }
        }
        anchors.centerIn: parent
        radius: 20
        displacement: 22.0
        aberration: 0.03
        bevelWidth: 26.0
        tintColor: Qt.rgba(0.04, 0.05, 0.08, 0.92)
        backgroundSourceItem: root.backgroundSourceItem
        isFlowActive: (typeof win !== "undefined" && win.isPlaying && win.currentTrack !== null)
        clip: true
        z: 2

        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        // Shaded Tint Overlay: Ensures effortless text contrast over background music cards
        Rectangle {
            anchors.fill: parent
            radius: dialog.radius
            color: Qt.rgba(0.04, 0.05, 0.08, 0.88)
            z: 1
        }

        // 1px Hairline Border: Keo 502 Surface Tension Rim
        Rectangle {
            anchors.fill: parent
            radius: dialog.radius
            color: "transparent"
            border.color: Qt.rgba(255, 255, 255, 0.18)
            border.width: 1
            z: 20
        }

        // Intercept clicks inside dialog so modal doesn't dismiss
        MouseArea {
            anchors.fill: parent
            z: 2
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            z: 5

            // -----------------------------------------------------------------
            // Header Row: Title & Close Button
            // -----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                Text {
                    text: "Cài đặt"
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                    border.color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: closeHover }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 12
                        color: closeHover.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // -----------------------------------------------------------------
            // Tab Switcher (Frameless Underline Indicator ___ - Image 1 Style)
            // -----------------------------------------------------------------
            Item {
                id: tabSwitcherRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Row {
                    id: tabsRow
                    spacing: 24
                    anchors.verticalCenter: parent.verticalCenter

                    // Tab 0: Tài khoản
                    Item {
                        id: tab0Btn
                        width: tab0Txt.implicitWidth
                        height: 32

                        Text {
                            id: tab0Txt
                            anchors.centerIn: parent
                            text: "Tài khoản"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: root.currentTab === 0
                            color: root.currentTab === 0 ? "#ffffff" : (tab0H.hovered ? "#ffffff" : Qt.rgba(255, 255, 255, 0.60))
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        HoverHandler { id: tab0H }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 0
                        }
                    }

                    // Tab 1: Lời bài hát Desktop
                    Item {
                        id: tab1Btn
                        width: tab1Txt.implicitWidth
                        height: 32

                        Text {
                            id: tab1Txt
                            anchors.centerIn: parent
                            text: "Lời bài hát Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: root.currentTab === 1
                            color: root.currentTab === 1 ? "#ffffff" : (tab1H.hovered ? "#ffffff" : Qt.rgba(255, 255, 255, 0.60))
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        HoverHandler { id: tab1H }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 1
                        }
                    }
                }

                // Sliding Underline Indicator (___) - The only active underline indicator
                Rectangle {
                    id: tabUnderline
                    anchors.bottom: parent.bottom
                    height: 2
                    radius: 1
                    color: "#ffffff"
                    x: root.currentTab === 0 ? tab0Btn.x : tab1Btn.x
                    width: root.currentTab === 0 ? tab0Btn.width : tab1Btn.width

                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }

            // Flickable Container: Drag up/down with left mouse button, zero scrollbar column
            Flickable {
                id: settingsFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: scrollContentContainer.height
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 1500
                pressDelay: 60
                interactive: true

                WheelHandler {
                    onWheel: event => {
                        settingsFlickable.contentY = Math.max(0, Math.min(settingsFlickable.contentHeight - settingsFlickable.height, settingsFlickable.contentY - event.angleDelta.y));
                    }
                }

                Item {
                    id: scrollContentContainer
                    width: settingsFlickable.width
                    height: implicitHeight
                    implicitHeight: (root.currentTab === 0 ? tab0Content.implicitHeight : tab1Content.implicitHeight) + 8

                    // =========================================================
                    // TAB 0: Google & Cloud Account Content (100% Frameless)
                    // =========================================================
                    ColumnLayout {
                        id: tab0Content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 14
                        visible: root.currentTab === 0

                // Compact User Profile Row (When Logged In - Frameless)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    visible: root.isLoggedIn

                    Row {
                        anchors.left: parent.left
                        anchors.right: logoutBtn.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        // User Avatar (Circular 42px)
                        Item {
                            width: 42
                            height: 42

                            Rectangle {
                                anchors.fill: parent
                                radius: 21
                                color: Qt.rgba(255, 255, 255, 0.08)
                                border.color: Qt.rgba(255, 255, 255, 0.15)
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.accountThumb
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.accountThumb !== ""
                                    asynchronous: true
                                    cache: true
                                }

                                AppIcon {
                                    anchors.centerIn: parent
                                    source: "../assets/icons/preferences-system-symbolic.svg"
                                    iconSize: 20
                                    color: Theme.textSecondary
                                    visible: root.accountThumb === ""
                                }
                            }
                        }

                        // Name & Email / Channel Handle
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 56

                            Text {
                                text: root.accountName ? root.accountName : "Tài khoản Google"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.accountEmail ? root.accountEmail : "Đã kết nối Cloud"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Logout Button (Subtle Pill pinned to right)
                    Rectangle {
                        id: logoutBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        width: 86
                        radius: 15
                        color: logoutHover.hovered ? Qt.rgba(239, 68, 68, 0.20) : Qt.rgba(255, 255, 255, 0.07)
                        border.color: logoutHover.hovered ? Qt.rgba(239, 68, 68, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: logoutHover }

                        Text {
                            anchors.centerIn: parent
                            text: "Đăng xuất"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: logoutHover.hovered ? "#fca5a5" : Theme.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.logoutRequested()
                        }
                    }
                }


                // 1-Click Native Login Button (When NOT Logged In)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    visible: !root.isLoggedIn
                    color: root.isProcessing ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40) : (browserLoginMouse.containsMouse ? Qt.lighter(root.accentColor, 1.12) : root.accentColor)
                    border.color: Qt.rgba(255, 255, 255, 0.16)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        AppIcon {
                            source: "../assets/icons/arrow-outward-symbolic.svg"
                            iconSize: 14
                            color: "#000000"
                        }

                        Text {
                            text: root.isProcessing ? "Đang chờ đăng nhập trên trình duyệt..." : "Đăng nhập Google qua Trình duyệt (1-Chạm)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: "#000000"
                        }
                    }

                    MouseArea {
                        id: browserLoginMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: false
                        cursorShape: root.isProcessing ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.isProcessing
                        onClicked: root.launchBrowserLoginRequested()
                    }
                }

                // Sync History to Google Toggle (Frameless Row, Toggle Pinned to Right)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46

                    Column {
                        anchors.left: parent.left
                        anchors.right: toggleSyncHistory.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Đồng bộ lịch sử nghe nhạc lên Cloud (YouTube Music)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Cập nhật lịch sử xem và gợi ý cá nhân hóa trên tài khoản Google"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Toggle Switch Pill (Pinned to Right)
                    Rectangle {
                        id: toggleSyncHistory
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 24
                        radius: 12
                        color: root.syncHistoryToGoogle ? root.accentColor : Qt.rgba(255, 255, 255, 0.14)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.syncHistoryToGoogle ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.syncHistoryToGoogle = !root.syncHistoryToGoogle;
                                root.toggleSyncHistoryRequested(root.syncHistoryToGoogle);
                            }
                        }
                    }
                }

                // Apple Music Animated Album Artwork Toggle (Frameless Row, Toggle Pinned to Right)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46

                    Column {
                        anchors.left: parent.left
                        anchors.right: toggleAnimatedCover.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Bìa album động Apple Music (Animated Cover)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Tự động phát video loop nghệ thuật từ Apple Music thay cho ảnh tĩnh"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Toggle Switch Pill (Pinned to Right)
                    Rectangle {
                        id: toggleAnimatedCover
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 24
                        radius: 12
                        color: root.animatedCoverEnabled ? root.accentColor : Qt.rgba(255, 255, 255, 0.14)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.animatedCoverEnabled ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.animatedCoverEnabled = !root.animatedCoverEnabled;
                                root.toggleAnimatedCoverRequested(root.animatedCoverEnabled);
                            }
                        }
                    }
                }

                // Separator Hairline (When NOT Logged In)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: !root.isLoggedIn

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255, 255, 255, 0.07) }
                    Text {
                        text: "HOẶC NHẬP MÃ COOKIE DỰ PHÒNG"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#666666"
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255, 255, 255, 0.07) }
                }

                // Cookie Input Box (When NOT Logged In)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: 10
                    visible: !root.isLoggedIn
                    color: "#0e0e13"
                    border.color: authInput.activeFocus ? root.accentColor : Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8

                        TextArea {
                            id: authInput
                            placeholderText: "Dán mã raw cookie (SAPISID=...; SSID=...) hoặc Request Headers tại đây..."
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

                // Cookie Actions Row (When NOT Logged In)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: !root.isLoggedIn

                    Rectangle {
                        height: 32
                        Layout.preferredWidth: pasteTxt.implicitWidth + 24
                        radius: 8
                        color: pasteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Text {
                            id: pasteTxt
                            anchors.centerIn: parent
                            text: "Dán từ Clipboard"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: pasteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                authInput.selectAll();
                                authInput.paste();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 32
                        Layout.preferredWidth: 70
                        radius: 8
                        color: cancelMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Hủy"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }

                    Rectangle {
                        height: 32
                        Layout.preferredWidth: 120
                        radius: 8
                        color: (!root.isProcessing && authInput.text.trim().length > 0) ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                        Text {
                            anchors.centerIn: parent
                            text: root.isProcessing ? "Đang xác thực..." : "Kết nối & Lưu"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: "#000000"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (!root.isProcessing && authInput.text.trim().length > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !root.isProcessing && authInput.text.trim().length > 0
                            onClicked: root.connectRequested(authInput.text.trim())
                        }
                    }
                }

                // Status Message
                Text {
                    Layout.fillWidth: true
                    text: root.statusMessage
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: root.statusMessage.indexOf("Success") !== -1 ? root.accentColor : "#ff6b6b"
                    visible: root.statusMessage.length > 0
                    wrapMode: Text.Wrap
                }

            } // Close tab0Content

            // =================================================================
            // TAB 1: Desktop Lyrics Settings Content (100% Frameless)
            // =================================================================
            ColumnLayout {
                id: tab1Content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 12
                visible: root.currentTab === 1

                // Master Switch: Desktop Lyrics (Frameless Row, Toggle Pinned to Right)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46

                    Column {
                        anchors.left: parent.left
                        anchors.right: toggleDesktopLyrics.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
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
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Toggle Switch Pill (Pinned to Right)
                    Rectangle {
                        id: toggleDesktopLyrics
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 24
                        radius: 12
                        color: root.desktopLyricsEnabled ? root.accentColor : Qt.rgba(255, 255, 255, 0.14)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.desktopLyricsEnabled ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDesktopLyricsRequested(!root.desktopLyricsEnabled)
                        }
                    }
                }

                // Section Title
                Text {
                    text: "CHỌN MẪU GIAO DIỆN (PRESETS)"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.textMuted
                    Layout.topMargin: 2
                }

                // -------------------------------------------------------------
                // PRESET 1: Gacha / Anime Pop (100% Frameless Row)
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 8
                    color: p1Hover.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: p1Hover }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        // Left: Title & Subtitle
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: 168

                            Text {
                                text: "Mẫu 1: Gacha Pop"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: root.lyricsPreset === 1 ? "#ffffff" : (p1Hover.hovered ? "#ffffff" : Theme.textPrimary)
                            }

                            Text {
                                text: "1 dòng • Instrument Serif"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                        }

                        // Center: Live Lyric Typography Preview (Floating naturally on glass)
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 178
                            anchors.right: check1.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "君の笑顔が 眩しくて..."
                            font.family: root.magicFontFamily
                            font.italic: true
                            font.pixelSize: 15
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        // Right: Circular Radio Checkmark Badge (Pinned to Right)
                        Rectangle {
                            id: check1
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: root.lyricsPreset === 1 ? "#ffffff" : "transparent"
                            border.color: root.lyricsPreset === 1 ? "#ffffff" : (p1Hover.hovered ? Qt.rgba(255, 255, 255, 0.40) : Qt.rgba(255, 255, 255, 0.20))
                            border.width: root.lyricsPreset === 1 ? 0 : 1.5
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/emblem-ok-symbolic.svg"
                                iconSize: 12
                                color: "#000000"
                                visible: root.lyricsPreset === 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectLyricsPresetRequested(1)
                    }
                }

                // -------------------------------------------------------------
                // PRESET 2: Apple Music 5-Line Fluid Sync (100% Frameless Row)
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 8
                    color: p2Hover.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: p2Hover }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        // Left: Title & Subtitle
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: 168

                            Row {
                                spacing: 6
                                Text {
                                    text: "Mẫu 2: Apple Music"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.lyricsPreset === 2 ? "#ffffff" : (p2Hover.hovered ? "#ffffff" : Theme.textPrimary)
                                }
                                Rectangle {
                                    height: 14
                                    width: 30
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.16)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "MỚI"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: "5 dòng • DoF quang học"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                        }

                        // Center: Live Lyric Typography Preview (Floating naturally on glass)
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 178
                            anchors.right: check2.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Soft memories remain..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: "#ffffff"
                                opacity: 0.35
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: "And every melody feels alive"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: "Until the morning light..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: "#ffffff"
                                opacity: 0.35
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right: Circular Radio Checkmark Badge (Pinned to Right)
                        Rectangle {
                            id: check2
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: root.lyricsPreset === 2 ? "#ffffff" : "transparent"
                            border.color: root.lyricsPreset === 2 ? "#ffffff" : (p2Hover.hovered ? Qt.rgba(255, 255, 255, 0.40) : Qt.rgba(255, 255, 255, 0.20))
                            border.width: root.lyricsPreset === 2 ? 0 : 1.5
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/emblem-ok-symbolic.svg"
                                iconSize: 12
                                color: "#000000"
                                visible: root.lyricsPreset === 2
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectLyricsPresetRequested(2)
                    }
                }

                // -------------------------------------------------------------
                // PRESET 3: Tối giản lướt (100% Frameless Row)
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 8
                    color: p3Hover.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: p3Hover }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        // Left: Title & Subtitle
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: 168

                            Row {
                                spacing: 6
                                Text {
                                    text: "Mẫu 3: Tối giản lướt"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.lyricsPreset === 3 ? "#ffffff" : (p3Hover.hovered ? "#ffffff" : Theme.textPrimary)
                                }
                                Rectangle {
                                    height: 14
                                    width: 30
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.16)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "MỚI"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: "2 dòng • Motion Blur"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                        }

                        // Center: Live Lyric Typography Preview (Floating naturally on glass)
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 178
                            anchors.right: check3.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Yesterday is fading away"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.textSecondary
                                opacity: 0.50
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: "Now tomorrow is singing"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right: Circular Radio Checkmark Badge (Pinned to Right)
                        Rectangle {
                            id: check3
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: root.lyricsPreset === 3 ? "#ffffff" : "transparent"
                            border.color: root.lyricsPreset === 3 ? "#ffffff" : (p3Hover.hovered ? Qt.rgba(255, 255, 255, 0.40) : Qt.rgba(255, 255, 255, 0.20))
                            border.width: root.lyricsPreset === 3 ? 0 : 1.5
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/emblem-ok-symbolic.svg"
                                iconSize: 12
                                color: "#000000"
                                visible: root.lyricsPreset === 3
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectLyricsPresetRequested(3)
                    }
                }

                // -------------------------------------------------------------
                // PRESET 4: Anime MV Kinetic Typography (100% Frameless Row)
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 8
                    color: p4Hover.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: p4Hover }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        // Left: Title & Subtitle
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: 168

                            Row {
                                spacing: 6
                                Text {
                                    text: "Mẫu 4: MV Kinetic"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.lyricsPreset === 4 ? "#ffffff" : (p4Hover.hovered ? "#ffffff" : Theme.textPrimary)
                                }
                                Rectangle {
                                    height: 14
                                    width: 30
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.16)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "MỚI"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: "Chữ khối • Bento Frame"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                        }

                        // Center: Live Lyric Typography Preview (Floating naturally on glass)
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 178
                            anchors.right: check4.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "[ KINETIC TYPO ]"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 2.0
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        // Right: Circular Radio Checkmark Badge (Pinned to Right)
                        Rectangle {
                            id: check4
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: root.lyricsPreset === 4 ? "#ffffff" : "transparent"
                            border.color: root.lyricsPreset === 4 ? "#ffffff" : (p4Hover.hovered ? Qt.rgba(255, 255, 255, 0.40) : Qt.rgba(255, 255, 255, 0.20))
                            border.width: root.lyricsPreset === 4 ? 0 : 1.5
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/emblem-ok-symbolic.svg"
                                iconSize: 12
                                color: "#000000"
                                visible: root.lyricsPreset === 4
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectLyricsPresetRequested(4)
                    }
                }

                // Bottom Frameless Row: Positioning & Reset (Button Pinned to Right)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    Column {
                        anchors.left: parent.left
                        anchors.right: resetBtn.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Vị trí hiển thị trên màn hình"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: (root.customX >= 0 && root.customY >= 0) ? "Kéo thả trực tiếp trên Desktop để dời vị trí." : "Tự động căn theo tỷ lệ màn hình • Kéo thả trực tiếp trên Desktop."
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Reset Position Button (Pill button pinned to right)
                    Rectangle {
                        id: resetBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        width: 136
                        radius: 15
                        color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                        border.color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

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
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetLyricsPositionRequested()
                        }
                    }
                }
            } // Close tab1Content
        } // Close inner Item
    } // Close settingsScroll
} // Close ColumnLayout
    } // Close dialog
}
