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
    z: 10005

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
    property string currentLanguage: I18n.locale
    property string streamingQuality: "high_opus"
    property string downloadQuality: "high_opus"
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property bool manualCookieExpanded: false

    onVisibleChanged: {
        if (!visible) {
            closeAllDropdowns();
            if (root.isProcessing) {
                root.isProcessing = false;
            }
        }
    }

    Timer {
        id: loginTimeoutTimer
        interval: 60000 // 60 seconds fail-safe timeout
        running: root.isProcessing
        repeat: false
        onTriggered: {
            if (root.isProcessing) {
                root.isProcessing = false;
                root.statusMessage = I18n.tr(
                    "Đã hết thời gian chờ trình duyệt (60s). Hãy thử lại hoặc dùng dán cookie dự phòng ở dưới.",
                    "Browser login timed out (60s). Please try again or use backup cookie paste below."
                );
            }
        }
    }

    function pasteAndConnectFromClipboard() {
        var text = "";
        if (typeof __NutstyBridge !== "undefined" && typeof __NutstyBridge.getClipboardText === "function") {
            text = __NutstyBridge.getClipboardText();
        }
        if (!text && typeof authInput !== "undefined" && authInput) {
            authInput.selectAll();
            authInput.paste();
            text = authInput.text;
        }
        text = (text || "").trim();
        if (!text) {
            root.statusMessage = I18n.tr("Clipboard đang rỗng. Hãy copy mã cookie rồi thử lại.", "Clipboard is empty. Please copy cookie text first.");
            root.manualCookieExpanded = true;
            return;
        }

        var textLower = text.toLowerCase();
        var hasAuthToken = textLower.indexOf("sapisid=") !== -1 ||
                           textLower.indexOf("__secure-3papisid=") !== -1 ||
                           textLower.indexOf("login_info=") !== -1 ||
                           textLower.indexOf("cookie:") !== -1 ||
                           textLower.indexOf("sid=") !== -1;

        if (typeof authInput !== "undefined" && authInput) {
            authInput.text = text;
        }

        if (hasAuthToken) {
            root.statusMessage = I18n.tr("Đã nhận diện cookie từ Clipboard! Đang kết nối...", "Detected cookie from Clipboard! Connecting...");
            root.connectRequested(text);
        } else {
            root.statusMessage = I18n.tr("Dữ liệu Clipboard không chứa cookie YouTube Music hợp lệ. Hãy kiểm tra lại.", "Clipboard does not contain valid YouTube Music cookies. Please check.");
            root.manualCookieExpanded = true;
        }
    }

    // =========================================================================
    // Signals (100% preserved for shell.qml integration)
    // =========================================================================
    signal closeRequested()
    signal selectLanguageRequested(string lang)
    signal selectStreamingQualityRequested(string quality)
    signal selectDownloadQualityRequested(string quality)
    signal connectRequested(string rawAuth)
    signal logoutRequested()
    signal launchBrowserLoginRequested()
    signal toggleSyncHistoryRequested(bool enabled)
    signal toggleAnimatedCoverRequested(bool enabled)
    signal toggleDesktopLyricsRequested(bool enabled)
    signal selectLyricsPresetRequested(int preset)
    signal resetLyricsPositionRequested()

    function getQualityLabel(qual, isDownload) {
        if (qual === "high_opus") {
            return I18n.tr("Cao - Opus (256 kbps)", "High - Opus (256 kbps)");
        } else if (qual === "high_aac") {
            return I18n.tr("Cao - AAC (256 kbps)", "High - AAC (256 kbps)");
        } else if (qual === "medium") {
            return isDownload
                ? I18n.tr("Tiêu chuẩn (128 kbps)", "Standard (128 kbps)")
                : I18n.tr("Tiêu chuẩn (129 kbps)", "Standard (129 kbps)");
        } else if (qual === "low") {
            return isDownload
                ? I18n.tr("Tiết kiệm (64 kbps)", "Data Saver (64 kbps)")
                : I18n.tr("Tiết kiệm (66 kbps)", "Data Saver (66 kbps)");
        }
        return I18n.tr("Cao - Opus (256 kbps)", "High - Opus (256 kbps)");
    }

    function closeAllDropdowns() {
        if (typeof langRowItem !== "undefined" && langRowItem) langRowItem.menuOpen = false;
        if (typeof streamQualityRowItem !== "undefined" && streamQualityRowItem) streamQualityRowItem.menuOpen = false;
        if (typeof downloadQualityRowItem !== "undefined" && downloadQualityRowItem) downloadQualityRowItem.menuOpen = false;
    }

    function toggleStreamingQualityMenu() {
        var next = !(typeof streamQualityRowItem !== "undefined" && streamQualityRowItem.menuOpen);
        closeAllDropdowns();
        if (typeof streamQualityRowItem !== "undefined") streamQualityRowItem.menuOpen = next;
    }

    function toggleDownloadQualityMenu() {
        var next = !(typeof downloadQualityRowItem !== "undefined" && downloadQualityRowItem.menuOpen);
        closeAllDropdowns();
        if (typeof downloadQualityRowItem !== "undefined") downloadQualityRowItem.menuOpen = next;
    }

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
                return root.isLoggedIn ? Math.min(590, root.height - 48) : Math.min(620, root.height - 48);
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

        // Intercept clicks inside dialog so modal doesn't dismiss, and close active dropdowns
        MouseArea {
            anchors.fill: parent
            z: 2
            onClicked: root.closeAllDropdowns()
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
                    text: I18n.tr("Cài đặt", "Settings")
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
                            text: I18n.tr("Tài khoản", "Account")
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
                            onClicked: {
                                root.closeAllDropdowns();
                                root.currentTab = 0;
                            }
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
                            text: I18n.tr("Lời bài hát Desktop", "Desktop Lyrics")
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
                            onClicked: {
                                root.closeAllDropdowns();
                                root.currentTab = 1;
                            }
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
                    implicitHeight: (root.currentTab === 0
                                     ? tab0Content.implicitHeight + (langRowItem.menuOpen || streamQualityRowItem.menuOpen || downloadQualityRowItem.menuOpen ? 210 : 30)
                                     : tab1Content.implicitHeight) + 8

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

                        // User Avatar (Zero Black Artifacts Framed Squircle: 44x44, radius: 12)
                        Item {
                            width: 44
                            height: 44

                            // Mask for the avatar image
                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: 12
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            // Inner Avatar Container with MultiEffect Mask (fills 100% of parent)
                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: avatarMask
                                    autoPaddingEnabled: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#202024"
                                }

                                Image {
                                    anchors.fill: parent
                                    source: root.accountThumb
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.accountThumb !== ""
                                    asynchronous: true
                                    cache: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: (typeof win !== "undefined" && win.accentColor) ? Qt.tint(win.accentColor, Qt.rgba(0.2, 0.1, 0.4, 0.7)) : "#6366f1"
                                    visible: root.accountThumb === ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.accountName && root.accountName.length > 0) ? root.accountName.substring(0, 1).toUpperCase() : "G"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            // Concentric Hairline Outer Border directly framing the avatar edge
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                border.color: Qt.rgba(255, 255, 255, 0.20)
                                border.width: 1
                            }
                        }

                        // Name & Email / Channel Handle
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 60

                            Text {
                                text: root.accountName ? root.accountName : I18n.tr("Tài khoản Google", "Google Account")
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.accountEmail ? root.accountEmail : I18n.tr("Đã kết nối Cloud", "Connected to Cloud")
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Logout Button (Option 1: Destructive Ghost Action Button)
                    Rectangle {
                        id: logoutBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: logoutTxt.implicitWidth + 18
                        radius: 6
                        color: logoutMouse.containsMouse ? Qt.rgba(244, 63, 94, 0.14) : "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: logoutTxt
                            anchors.centerIn: parent
                            text: I18n.tr("Đăng xuất", "Log out")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: logoutMouse.containsMouse ? "#fda4af" : "#f87171"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: logoutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.logoutRequested()
                        }
                    }
                }


                // =============================================================
                // Unified Account Login Block (When NOT Logged In)
                // =============================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !root.isLoggedIn

                    // 1-Click Native Browser Login Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 12
                        color: root.isProcessing ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : (browserLoginMouse.containsMouse ? Qt.lighter(root.accentColor, 1.12) : root.accentColor)
                        border.color: Qt.rgba(255, 255, 255, 0.16)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 12
                            spacing: 8

                            AppIcon {
                                source: root.isProcessing ? "../assets/icons/process-working-symbolic.svg" : "../assets/icons/arrow-outward-symbolic.svg"
                                iconSize: 14
                                color: "#000000"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.isProcessing ? I18n.tr("Đang chờ đăng nhập trên trình duyệt...", "Waiting for browser login...") : I18n.tr("Đăng nhập Google qua Trình duyệt (1-Chạm)", "Sign in with Google via Browser (1-Click)")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#000000"
                                elide: Text.ElideRight
                            }

                            // Quick Cancel Button when process is waiting
                            Rectangle {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 28
                                radius: 6
                                visible: root.isProcessing
                                color: cancelWaitMouse.containsMouse ? Qt.rgba(244, 63, 94, 0.35) : Qt.rgba(244, 63, 94, 0.20)
                                border.color: Qt.rgba(244, 63, 94, 0.40)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Hủy", "Cancel")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: cancelWaitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isProcessing = false;
                                        root.statusMessage = I18n.tr("Đã hủy chờ đăng nhập.", "Login cancelled.");
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: browserLoginMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.isProcessing ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !root.isProcessing
                            onClicked: {
                                loginTimeoutTimer.restart();
                                root.launchBrowserLoginRequested();
                            }
                        }
                    }

                    // Smart Backup Actions Row (Zero Extension Required)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Quick Auto-Paste from Clipboard & Login (2-Second Fallback)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 8
                            color: pasteAutoMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.30)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    source: "../assets/icons/edit-select-all-symbolic.svg"
                                    iconSize: 12
                                    color: root.accentColor
                                }

                                Text {
                                    text: I18n.tr("Dán nhanh từ Clipboard & Đăng nhập", "Quick Paste Clipboard & Sign In")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            MouseArea {
                                id: pasteAutoMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isProcessing
                                onClicked: root.pasteAndConnectFromClipboard()
                            }
                        }

                        // Toggle Manual Input Accordion
                        Rectangle {
                            Layout.preferredWidth: manualToggleTxt.implicitWidth + 28
                            Layout.preferredHeight: 34
                            radius: 8
                            color: manualToggleMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                            border.color: Qt.rgba(255, 255, 255, 0.10)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    id: manualToggleTxt
                                    text: root.manualCookieExpanded ? I18n.tr("Thu gọn", "Collapse") : I18n.tr("Nhập thủ công", "Manual Paste")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                }

                                AppIcon {
                                    source: "../assets/icons/go-down-symbolic.svg"
                                    iconSize: 10
                                    color: Theme.textSecondary
                                    rotation: root.manualCookieExpanded ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: 160 } }
                                }
                            }

                            MouseArea {
                                id: manualToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.manualCookieExpanded = !root.manualCookieExpanded
                            }
                        }
                    }

                    // Collapsible Manual Cookie Entry Panel
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.manualCookieExpanded ? manualCol.implicitHeight + 20 : 0
                        radius: 10
                        color: Qt.rgba(255, 255, 255, 0.03)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: root.manualCookieExpanded ? 1 : 0
                        clip: true
                        visible: height > 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: manualCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: I18n.tr(
                                    "💡 Mẹo: Mở trình duyệt > Vào music.youtube.com > F12 > Thẻ Network > F5 > Bấm dòng 'music.youtube.com' > Copy giá trị 'cookie' và dán vào đây.",
                                    "💡 Tip: Open browser > Go to music.youtube.com > F12 > Network tab > F5 > Click 'music.youtube.com' > Copy 'cookie' value and paste here."
                                )
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Qt.rgba(255, 255, 255, 0.65)
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                radius: 8
                                color: "#0a0a0f"
                                border.color: (typeof authInput !== "undefined" && authInput.activeFocus) ? root.accentColor : Qt.rgba(255, 255, 255, 0.10)
                                border.width: 1

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 6

                                    TextArea {
                                        id: authInput
                                        placeholderText: I18n.tr("Dán mã cookie (SAPISID=...; SSID=...) hoặc Request Headers...", "Paste cookie (SAPISID=...; SSID=...) or Request Headers...")
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

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: pasteManualTxt.implicitWidth + 16
                                    radius: 6
                                    color: pasteManualMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1

                                    Text {
                                        id: pasteManualTxt
                                        anchors.centerIn: parent
                                        text: I18n.tr("Dán", "Paste")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: pasteManualMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            authInput.selectAll();
                                            authInput.paste();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: clearManualTxt.implicitWidth + 16
                                    radius: 6
                                    color: clearManualMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1

                                    Text {
                                        id: clearManualTxt
                                        anchors.centerIn: parent
                                        text: I18n.tr("Xóa", "Clear")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: clearManualMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: authInput.text = ""
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: 120
                                    radius: 6
                                    color: (!root.isProcessing && authInput.text.trim().length > 0) ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isProcessing ? I18n.tr("Đang xác thực...", "Verifying...") : I18n.tr("Xác thực & Kết nối", "Verify & Connect")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
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
                        }
                    }

                    // Direct Status & Diagnostic Feedback Message
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: root.statusMessage.length > 0

                        Text {
                            Layout.fillWidth: true
                            text: root.statusMessage
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: (root.statusMessage.indexOf("Success") !== -1 || root.statusMessage.indexOf("Connected") !== -1) ? root.accentColor : "#f87171"
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: I18n.tr(
                                "Log chẩn đoán: ~/.config/noctalia/browser_login.log (Linux) hoặc %TEMP%\\nutsty\\browser_login.log (Windows)",
                                "Diagnostic log: ~/.config/noctalia/browser_login.log (Linux) or %TEMP%\\nutsty\\browser_login.log (Windows)"
                            )
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Qt.rgba(255, 255, 255, 0.40)
                            wrapMode: Text.Wrap
                            visible: root.statusMessage.indexOf("Error") !== -1 || root.statusMessage.indexOf("Failed") !== -1 || root.statusMessage.indexOf("timed out") !== -1
                        }
                    }
                }

                // Language Selection Row (100% Borderless, Expandable Clean Dropdown Pinned to Right)
                Item {
                    id: langRowItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    z: menuOpen ? 100 : 3

                    property bool menuOpen: false

                    Column {
                        anchors.left: parent.left
                        anchors.right: langDropdownBtn.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: I18n.tr("Ngôn ngữ giao diện", "Interface Language")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Toàn bộ ứng dụng hiển thị theo ngôn ngữ đã chọn", "All application UI displays in selected language")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Dropdown Trigger (Option 1: Chromatic Ghost Action Button)
                    Rectangle {
                        id: langDropdownBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: langBtnRow.implicitWidth + 16
                        radius: 6
                        color: (langBtnMouse.containsMouse || langRowItem.menuOpen)
                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                               : "transparent"
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: langBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: I18n.locale === "vi" ? "Tiếng Việt" : "English"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: (langBtnMouse.containsMouse || langRowItem.menuOpen) ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "../assets/icons/go-down-symbolic.svg"
                                iconSize: 10
                                color: root.accentColor
                                rotation: langRowItem.menuOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            id: langBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = !langRowItem.menuOpen;
                                root.closeAllDropdowns();
                                langRowItem.menuOpen = next;
                            }
                        }
                    }

                    // Chromatic Salience Dropdown Popover Menu (Zero Dull Grey)
                    Rectangle {
                        id: langDropdownMenu
                        visible: langRowItem.menuOpen
                        anchors.top: langDropdownBtn.bottom
                        anchors.topMargin: 6
                        anchors.right: langDropdownBtn.right
                        width: 146
                        height: langCol.implicitHeight + 10
                        radius: 10
                        color: Qt.rgba(0.06 + root.accentColor.r * 0.08, 0.06 + root.accentColor.g * 0.08, 0.08 + root.accentColor.b * 0.12, 0.96)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        border.width: 1
                        z: 100

                        Column {
                            id: langCol
                            anchors.top: parent.top
                            anchors.topMargin: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 3

                            readonly property var languages: [
                                { code: "vi", name: "Tiếng Việt" },
                                { code: "en", name: "English" }
                            ]

                            Repeater {
                                model: langCol.languages
                                delegate: Rectangle {
                                    width: langCol.width - 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 32
                                    radius: 7
                                    color: (I18n.locale === modelData.code)
                                           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.26)
                                           : (langItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14) : "transparent")
                                    border.color: (I18n.locale === modelData.code)
                                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                                  : (langItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : "transparent")
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: I18n.locale === modelData.code
                                            color: (I18n.locale === modelData.code) ? "#ffffff" : (langItemMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.75))
                                        }

                                        AppIcon {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../assets/icons/emblem-ok-symbolic.svg"
                                            iconSize: 12
                                            color: root.accentColor
                                            visible: I18n.locale === modelData.code
                                        }
                                    }

                                    MouseArea {
                                        id: langItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectLanguageRequested(modelData.code);
                                            langRowItem.menuOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Streaming Audio Quality Row (100% Borderless, Expandable Clean Dropdown Pinned to Right)
                Item {
                    id: streamQualityRowItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    z: menuOpen ? 100 : 2

                    property bool menuOpen: false

                    Column {
                        anchors.left: parent.left
                        anchors.right: streamDropdownBtn.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: I18n.tr("Chất lượng phát trực tuyến", "Streaming Audio Quality")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Độ phân giải âm thanh khi nghe trực tuyến từ YouTube Music", "Audio stream bitrate when listening online from YouTube Music")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Dropdown Trigger (Option 1: Chromatic Ghost Action Button)
                    Rectangle {
                        id: streamDropdownBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: streamBtnRow.implicitWidth + 16
                        radius: 6
                        color: (streamBtnMouse.containsMouse || streamQualityRowItem.menuOpen)
                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                               : "transparent"
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: streamBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.getQualityLabel(root.streamingQuality, false)
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: (streamBtnMouse.containsMouse || streamQualityRowItem.menuOpen) ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "../assets/icons/go-down-symbolic.svg"
                                iconSize: 10
                                color: root.accentColor
                                rotation: streamQualityRowItem.menuOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            id: streamBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = !streamQualityRowItem.menuOpen;
                                root.closeAllDropdowns();
                                streamQualityRowItem.menuOpen = next;
                            }
                        }
                    }

                    // Chromatic Salience Dropdown Popover Menu (Zero Dull Grey)
                    Rectangle {
                        id: streamDropdownMenu
                        visible: streamQualityRowItem.menuOpen
                        anchors.top: streamDropdownBtn.bottom
                        anchors.topMargin: 6
                        anchors.right: streamDropdownBtn.right
                        width: 250
                        height: streamCol.implicitHeight + 10
                        radius: 10
                        color: Qt.rgba(0.06 + root.accentColor.r * 0.08, 0.06 + root.accentColor.g * 0.08, 0.08 + root.accentColor.b * 0.12, 0.96)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        border.width: 1
                        z: 100

                        Column {
                            id: streamCol
                            anchors.top: parent.top
                            anchors.topMargin: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 3

                            readonly property var qualityOptions: [
                                {
                                    key: "high_opus",
                                    name: I18n.tr("Cao - Opus (256 kbps)", "High - Opus (256 kbps)"),
                                    desc: I18n.tr("Chi tiết cao nhất, nén Opus hiện đại", "Highest detail, modern Opus compression")
                                },
                                {
                                    key: "high_aac",
                                    name: I18n.tr("Cao - AAC (256 kbps)", "High - AAC (256 kbps)"),
                                    desc: I18n.tr("Âm thanh ấm áp, tương thích tối đa", "Warm sound, maximum compatibility")
                                },
                                {
                                    key: "medium",
                                    name: I18n.tr("Tiêu chuẩn (129 kbps)", "Standard (129 kbps)"),
                                    desc: I18n.tr("Cân bằng băng thông và chất lượng", "Balanced data usage and quality")
                                },
                                {
                                    key: "low",
                                    name: I18n.tr("Tiết kiệm (66 kbps)", "Data Saver (66 kbps)"),
                                    desc: I18n.tr("Tối ưu khi mạng yếu hoặc 4G", "Optimized for slow network or 4G")
                                }
                            ]

                            Repeater {
                                model: streamCol.qualityOptions
                                delegate: Rectangle {
                                    width: streamCol.width - 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 42
                                    radius: 7
                                    color: (root.streamingQuality === modelData.key)
                                           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.26)
                                           : (streamItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14) : "transparent")
                                    border.color: (root.streamingQuality === modelData.key)
                                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                                  : (streamItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : "transparent")
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: streamCheckIcon.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: modelData.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.bold: root.streamingQuality === modelData.key
                                                color: (root.streamingQuality === modelData.key) ? "#ffffff" : (streamItemMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85))
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.desc
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: (root.streamingQuality === modelData.key) ? Qt.rgba(255, 255, 255, 0.80) : Theme.textSecondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        AppIcon {
                                            id: streamCheckIcon
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../assets/icons/emblem-ok-symbolic.svg"
                                            iconSize: 12
                                            color: root.accentColor
                                            visible: root.streamingQuality === modelData.key
                                        }
                                    }

                                    MouseArea {
                                        id: streamItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectStreamingQualityRequested(modelData.key);
                                            streamQualityRowItem.menuOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Download Audio Quality Row (100% Borderless, Expandable Clean Dropdown Pinned to Right)
                Item {
                    id: downloadQualityRowItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    z: menuOpen ? 100 : 1

                    property bool menuOpen: false

                    Column {
                        anchors.left: parent.left
                        anchors.right: dlDropdownBtn.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: I18n.tr("Chất lượng tải nhạc về máy", "Download Audio Quality")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Định dạng và bitrate khi lưu bài hát về bộ nhớ máy", "Format and bitrate used when saving tracks to local storage")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    // Dropdown Trigger (Option 1: Chromatic Ghost Action Button)
                    Rectangle {
                        id: dlDropdownBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: dlBtnRow.implicitWidth + 16
                        radius: 6
                        color: (dlBtnMouse.containsMouse || downloadQualityRowItem.menuOpen)
                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                               : "transparent"
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: dlBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.getQualityLabel(root.downloadQuality, true)
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: (dlBtnMouse.containsMouse || downloadQualityRowItem.menuOpen) ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "../assets/icons/go-down-symbolic.svg"
                                iconSize: 10
                                color: root.accentColor
                                rotation: downloadQualityRowItem.menuOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            id: dlBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = !downloadQualityRowItem.menuOpen;
                                root.closeAllDropdowns();
                                downloadQualityRowItem.menuOpen = next;
                            }
                        }
                    }

                    // Chromatic Salience Dropdown Popover Menu (Zero Dull Grey)
                    Rectangle {
                        id: dlDropdownMenu
                        visible: downloadQualityRowItem.menuOpen
                        anchors.top: dlDropdownBtn.bottom
                        anchors.topMargin: 6
                        anchors.right: dlDropdownBtn.right
                        width: 250
                        height: dlCol.implicitHeight + 10
                        radius: 10
                        color: Qt.rgba(0.06 + root.accentColor.r * 0.08, 0.06 + root.accentColor.g * 0.08, 0.08 + root.accentColor.b * 0.12, 0.96)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        border.width: 1
                        z: 100

                        Column {
                            id: dlCol
                            anchors.top: parent.top
                            anchors.topMargin: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 3

                            readonly property var qualityOptions: [
                                {
                                    key: "high_opus",
                                    name: I18n.tr("Cao - Opus (256 kbps)", "High - Opus (256 kbps)"),
                                    desc: I18n.tr("Trích xuất Opus 256k nguyên gốc, chi tiết cao", "Direct Opus 256k extract, highest detail")
                                },
                                {
                                    key: "high_aac",
                                    name: I18n.tr("Cao - AAC (256 kbps)", "High - AAC (256 kbps)"),
                                    desc: I18n.tr("Trích xuất M4A/AAC 256k tương thích mọi nơi", "Direct M4A/AAC 256k, universal compatibility")
                                },
                                {
                                    key: "medium",
                                    name: I18n.tr("Tiêu chuẩn (128 kbps)", "Standard (128 kbps)"),
                                    desc: I18n.tr("Dung lượng vừa phải, định dạng M4A chuẩn", "Moderate file size, standard M4A")
                                },
                                {
                                    key: "low",
                                    name: I18n.tr("Tiết kiệm (64 kbps)", "Data Saver (64 kbps)"),
                                    desc: I18n.tr("Dung lượng siêu nhẹ cho bộ nhớ máy nhỏ", "Ultra light storage for small disk spaces")
                                }
                            ]

                            Repeater {
                                model: dlCol.qualityOptions
                                delegate: Rectangle {
                                    width: dlCol.width - 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 42
                                    radius: 7
                                    color: (root.downloadQuality === modelData.key)
                                           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.26)
                                           : (dlItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14) : "transparent")
                                    border.color: (root.downloadQuality === modelData.key)
                                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                                  : (dlItemMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : "transparent")
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: dlCheckIcon.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: modelData.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.bold: root.downloadQuality === modelData.key
                                                color: (root.downloadQuality === modelData.key) ? "#ffffff" : (dlItemMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85))
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.desc
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: (root.downloadQuality === modelData.key) ? Qt.rgba(255, 255, 255, 0.80) : Theme.textSecondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        AppIcon {
                                            id: dlCheckIcon
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../assets/icons/emblem-ok-symbolic.svg"
                                            iconSize: 12
                                            color: root.accentColor
                                            visible: root.downloadQuality === modelData.key
                                        }
                                    }

                                    MouseArea {
                                        id: dlItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectDownloadQualityRequested(modelData.key);
                                            downloadQualityRowItem.menuOpen = false;
                                        }
                                    }
                                }
                            }
                        }
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
                            text: I18n.tr("Đồng bộ lịch sử nghe nhạc lên Cloud (YouTube Music)", "Sync listening history to Cloud (YouTube Music)")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Cập nhật lịch sử xem và gợi ý cá nhân hóa trên tài khoản Google", "Update watch history and personalized recommendations on Google Account")
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
                            text: I18n.tr("Bìa album động Apple Music (Animated Cover)", "Apple Music Animated Album Artwork")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Tự động phát video loop nghệ thuật từ Apple Music thay cho ảnh tĩnh", "Play artistic loop video from Apple Music instead of static artwork")
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

                // Status Message (When Logged In)
                Text {
                    Layout.fillWidth: true
                    text: root.statusMessage
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: (root.statusMessage.indexOf("Success") !== -1 || root.statusMessage.indexOf("Connected") !== -1) ? root.accentColor : "#f87171"
                    visible: root.isLoggedIn && root.statusMessage.length > 0
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
                            text: I18n.tr("Hiển thị lời bài hát trên Desktop", "Desktop Lyrics Display")
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: I18n.tr("Hiển thị lời bài hát nổi trực tiếp trên hình nền Wayland", "Display floating lyrics directly on Wayland desktop wallpaper")
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
                    text: I18n.tr("CHỌN MẪU GIAO DIỆN (PRESETS)", "CHOOSE DISPLAY PRESETS")
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
                                text: I18n.tr("Mẫu 1: Gacha Pop", "Preset 1: Gacha Pop")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: root.lyricsPreset === 1 ? "#ffffff" : (p1Hover.hovered ? "#ffffff" : Theme.textPrimary)
                            }

                            Text {
                                text: I18n.tr("1 dòng • Instrument Serif", "1 line • Instrument Serif")
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
                                    text: I18n.tr("Mẫu 2: Apple Music", "Preset 2: Apple Music")
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
                                        text: I18n.tr("MỚI", "NEW")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: I18n.tr("5 dòng • DoF quang học", "5 lines • Optical DoF")
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
                                    text: I18n.tr("Mẫu 3: Tối giản lướt", "Preset 3: Minimal Glide")
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
                                        text: I18n.tr("MỚI", "NEW")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: I18n.tr("2 dòng • Motion Blur", "2 lines • Motion Blur")
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
                                    text: I18n.tr("Mẫu 4: MV Kinetic", "Preset 4: MV Kinetic")
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
                                        text: I18n.tr("MỚI", "NEW")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: I18n.tr("Chữ khối • Bento Frame", "Block text • Bento Frame")
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
                            text: I18n.tr("Vị trí hiển thị trên màn hình", "Screen Display Position")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: (root.customX >= 0 && root.customY >= 0) ? I18n.tr("Kéo thả trực tiếp trên Desktop để dời vị trí.", "Drag directly on Desktop to reposition.") : I18n.tr("Tự động căn theo tỷ lệ màn hình • Kéo thả trực tiếp trên Desktop.", "Auto-aligned to screen ratio • Drag directly on Desktop.")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    Rectangle {
                        id: resetBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: resetRow.implicitWidth + 16
                        radius: 6
                        color: resetMouse.containsMouse
                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                               : "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: resetRow
                            anchors.centerIn: parent
                            spacing: 6

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "../assets/icons/media-playlist-repeat-symbolic.svg"
                                iconSize: 12
                                color: root.accentColor
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Đặt lại mặc định", "Reset Defaults")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: resetMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
