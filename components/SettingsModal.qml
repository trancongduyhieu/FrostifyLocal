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

    signal closeRequested()
    signal connectRequested(string rawAuth)
    signal logoutRequested()
    signal launchBrowserLoginRequested()

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: dialog
        width: Math.min(560, root.width - 40)
        height: Math.min(480, root.height - 40)
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
                    text: "YouTube Music Account"
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

                    SpotifyIcon {
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

            // Connection Status Banner
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 8
                color: root.isLoggedIn ? "#16281e" : "#242424"
                border.color: root.isLoggedIn ? Theme.spotifyGreen : "#3a3a3a"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.isLoggedIn ? Theme.spotifyGreen : "#777777"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.isLoggedIn
                              ? ("Connected: " + (root.accountName ? root.accountName : "Google Account"))
                              : "Not Connected (Guest / Local Taste Mode)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: root.isLoggedIn ? Theme.spotifyGreen : Theme.textPrimary
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

            // 1-Click Native Login Button (SimpMusic Style)
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 21
                visible: !root.isLoggedIn
                color: root.isProcessing ? "#1db95466" : (browserLoginMouse.containsMouse ? "#1ed760" : Theme.spotifyGreen)
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
                    border.color: authInput.activeFocus ? Theme.spotifyGreen : "#2c2c2c"
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
                    text: "1-Click Sync: If you use the SimpMusic Utils browser extension, click 'Sync to Frostify (1-Click)' in the extension, or click 'Paste from Clipboard' below."
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
                color: root.statusMessage.indexOf("Success") !== -1 ? Theme.spotifyGreen : "#ff5555"
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
                    color: root.isProcessing ? "#1db95488" : (saveMouse.containsMouse ? "#1ed760" : Theme.spotifyGreen)

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
        }
    }
}
