import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Item {
    id: root
    width: 390
    height: 112
    visible: opacity > 0
    opacity: isShown ? 1 : 0
    z: 9999

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        NumberAnimation { duration: 250; easing.type: Easing.OutBack }
    }

    property bool isShown: false
    property var trackData: null
    property string senderName: ""
    property string senderAvatar: ""
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

    signal playNowRequested(var track)
    signal playNextRequested(var track)
    signal enqueueRequested(var track)
    signal dismissed()

    Timer {
        id: autoDismissTimer
        interval: 8000
        repeat: false
        running: root.isShown && !cardHover.hovered
        onTriggered: root.dismiss()
    }

    function showSuggestion(sName, sAvatar, trk) {
        root.senderName = sName || I18n.tr("Bạn bè", "Friend");
        root.senderAvatar = sAvatar || "";
        root.trackData = trk;
        root.isShown = true;
        autoDismissTimer.restart();
    }

    function dismiss() {
        root.isShown = false;
        autoDismissTimer.stop();
        root.dismissed();
    }

    Rectangle {
        id: toastCard
        anchors.fill: parent
        radius: 14
        color: Qt.tint(Qt.rgba(0.07, 0.07, 0.09, 0.94), Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16))
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40)
        border.width: 1

        HoverHandler { id: cardHover }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // Header: Sender info + Close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RoundedImage {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    source: root.senderAvatar
                    borderColor: root.accentColor
                    borderWidth: 1.0
                    fallbackIcon: "../assets/icons/preferences-system-symbolic.svg"
                    placeholderColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                    visible: root.senderAvatar !== ""
                }

                // Dynamic live dot if no avatar
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root.accentColor
                    visible: root.senderAvatar === ""
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr(root.senderName + " đề xuất bài hát:", root.senderName + " suggested a track:")
                    color: root.accentColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // Close button [✕]
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                    HoverHandler { id: closeHover }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 9
                        color: closeHover.hovered ? "#ffffff" : "#a1a1aa"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }
            }

            // Track info row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Track Cover Art
                RoundedImage {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 6
                    source: (root.trackData && (root.trackData.image || root.trackData.cover || root.trackData.thumbnail)) ? (root.trackData.image || root.trackData.cover || root.trackData.thumbnail) : ""
                    fallbackIcon: "../assets/icons/media-optical-audio-symbolic.svg"
                    placeholderColor: "#202024"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: (root.trackData && (root.trackData.title || root.trackData.name)) ? (root.trackData.title || root.trackData.name) : I18n.tr("Bài hát", "Track")
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (root.trackData && root.trackData.artist) ? root.trackData.artist : I18n.tr("Nghệ sĩ chưa rõ", "Unknown Artist")
                        color: "#a1a1aa"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            // Action buttons row: [ ▶ Phát ngay ] | [ ⏭ Phát kế tiếp ] | [ 🗏 Hàng đợi ]
            // Nằm phẳng trên mặt phẳng, không nằm trong box, 3 nút đều nhau 100%
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // 1. Play Now Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    radius: 6
                    color: playHover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                    border.width: 0

                    HoverHandler { id: playHover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        AppIcon {
                            source: "../assets/icons/media-playback-start-symbolic.svg"
                            iconSize: 11
                            color: root.accentColor
                        }

                        Text {
                            text: I18n.tr("Phát ngay", "Play now")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = root.trackData;
                            root.dismiss();
                            if (t) root.playNowRequested(t);
                        }
                    }
                }

                // 2. Play Next Button (Chèn ngay sau bài đang phát)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    radius: 6
                    color: playNextHover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20) : "transparent"
                    border.width: 0

                    HoverHandler { id: playNextHover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        AppIcon {
                            source: "../assets/icons/media-skip-forward-symbolic.svg"
                            iconSize: 11
                            color: root.accentColor
                        }

                        Text {
                            text: I18n.tr("Phát kế tiếp", "Play next")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = root.trackData;
                            root.dismiss();
                            if (t) root.playNextRequested(t);
                        }
                    }
                }

                // 3. Enqueue Button (Thêm vào cuối hàng đợi)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    radius: 6
                    color: queueHover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20) : "transparent"
                    border.width: 0

                    HoverHandler { id: queueHover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        AppIcon {
                            source: "../assets/icons/view-queue-symbolic.svg"
                            iconSize: 11
                            color: Qt.rgba(1, 1, 1, 0.75)
                        }

                        Text {
                            text: I18n.tr("Hàng đợi", "Queue")
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = root.trackData;
                            root.dismiss();
                            if (t) root.enqueueRequested(t);
                        }
                    }
                }
            }
        }
    }
}
