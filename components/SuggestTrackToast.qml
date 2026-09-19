import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Item {
    id: root
    width: 360
    height: 110
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
        color: Qt.rgba(0.08, 0.08, 0.10, 0.95)
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
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
                    fallbackIcon: "../assets/icons/preferences-system-symbolic.svg"
                    placeholderColor: "#27272a"
                    visible: root.senderAvatar !== ""
                }

                // Emerald live dot if no avatar
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: "#10b981"
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

            // Action buttons row: [ ▶ Phát ngay ] & [ + Thêm vào hàng đợi ]
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Play Now Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: 6
                    color: playHover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                    border.color: root.accentColor
                    border.width: 1

                    HoverHandler { id: playHover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        AppIcon {
                            source: "../assets/icons/media-playback-start-symbolic.svg"
                            iconSize: 10
                            color: "#ffffff"
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

                // Enqueue Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: 6
                    color: queueHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    HoverHandler { id: queueHover }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        AppIcon {
                            source: "../assets/icons/view-queue-symbolic.svg"
                            iconSize: 10
                            color: "#e4e4e7"
                        }

                        Text {
                            text: I18n.tr("Thêm hàng đợi", "Add to queue")
                            color: "#e4e4e7"
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
