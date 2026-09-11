import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Rectangle {
    id: root
    color: "#121212"
    radius: Theme.radiusCard
    clip: true

    property var moods: []
    property string selectedMood: "All"
    property var sections: []
    property var quickPicks: []
    property var featuredPlaylists: []
    property bool isLoading: false
    property var currentTrack: null
    property bool isPlaying: false

    signal moodSelected(string title, string params)
    signal trackPlayRequested(var trk)
    signal playlistSelected(var pl)
    signal trackContextMenuRequested(var trk, real globalX, real globalY)

    function getGreeting() {
        var h = new Date().getHours();
        if (h >= 5 && h < 12) return "Good Morning";
        if (h >= 12 && h < 18) return "Good Afternoon";
        return "Good Evening";
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: contentCol.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: console.log("[Flickable] contentY changed to:", contentY)
        Component.onCompleted: contentY = 0

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 24

            Item { height: 16 } // Top spacing

            // 1. Header Greeting & Mood Pills Bar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 14

                Text {
                    text: root.getGreeting()
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.textPrimary
                }

                // Mood Pills Horizontal Scroll
                Flickable {
                    Layout.fillWidth: true
                    height: 36
                    contentWidth: moodRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    RowLayout {
                        id: moodRow
                        spacing: 8

                        Repeater {
                            model: root.moods.length > 0 ? root.moods : [
                                { "title": "All", "params": "" },
                                { "title": "Relax", "params": "ggM8SgQIBxADSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Sleep", "params": "ggM8SgQIBxABSgQIBRADSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Energize", "params": "ggM8SgQIBxABSgQIBRABSgQICRADSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Sad", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChADSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Romance", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRADSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Party", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhADSgQIAxABSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Commute", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxADSgQICBABSgQIBhABSgQIBBAB" },
                                { "title": "Feel good", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBADSgQIBhABSgQIBBAB" },
                                { "title": "Focus", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhADSgQIBBAB" },
                                { "title": "Workout", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAD" }
                            ]

                            Rectangle {
                                id: pillRect
                                height: 32
                                width: pillTxt.implicitWidth + 24
                                radius: Theme.radiusPill
                                color: root.selectedMood === modelData.title ? Theme.accentPill : (pillMouse.containsMouse ? "#333333" : "#242424")
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: pillTxt
                                    anchors.centerIn: parent
                                    text: modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.selectedMood === modelData.title ? Theme.accentPillText : Theme.textPrimary
                                }

                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedMood = modelData.title;
                                        root.moodSelected(modelData.title, modelData.params || "");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // 2. Dynamic Multi-Section Home Feed (for any tab with rich sections)
            // =========================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 28
                visible: root.sections && root.sections.length > 0

                Repeater {
                    model: root.sections || []

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        spacing: 12

                        // Section Header with Carousel Navigation
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.subtitle ? modelData.subtitle.toUpperCase() : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.textSecondary
                                    visible: text.length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            // Carousel Navigation Buttons (< and >)
                            RowLayout {
                                spacing: 8
                                visible: modelData.type === "card_carousel" && modelData.items && modelData.items.length > 4

                                // Prev Button (<)
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: prevMouse.containsMouse ? "#383838" : "#242424"
                                    opacity: carouselFlick.contentX > 2 ? 1.0 : 0.35
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    SpotifyIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/go-previous-symbolic.svg"
                                        iconSize: 14
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        id: prevMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var targetX = Math.max(0, carouselFlick.contentX - 520);
                                            scrollAnim.to = targetX;
                                            scrollAnim.restart();
                                        }
                                    }
                                }

                                // Next Button (>)
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: nextMouse.containsMouse ? "#383838" : "#242424"
                                    opacity: (carouselFlick.contentX < (carouselFlick.contentWidth - carouselFlick.width - 10)) ? 1.0 : 0.35
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    SpotifyIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/go-previous-symbolic.svg"
                                        rotation: 180
                                        iconSize: 14
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        id: nextMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var maxX = Math.max(0, carouselFlick.contentWidth - carouselFlick.width);
                                            var targetX = Math.min(maxX, carouselFlick.contentX + 520);
                                            scrollAnim.to = targetX;
                                            scrollAnim.restart();
                                        }
                                    }
                                }
                            }
                        }

                        // Case A: Track Grid Layout
                        GridLayout {
                            Layout.fillWidth: true
                            visible: modelData.type === "track_grid"
                            columns: root.width > 900 ? 3 : 2
                            rowSpacing: 8
                            columnSpacing: 12

                            Repeater {
                                model: modelData.type === "track_grid" ? modelData.items.slice(0, 18) : []

                                Rectangle {
                                    id: gridItem
                                    Layout.fillWidth: true
                                    height: 56
                                    radius: 6
                                    color: rowMouse.containsMouse ? "#282828" : "#1a1a1a"
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 12

                                        Rectangle {
                                            width: 44
                                            height: 44
                                            radius: 4
                                            color: "#282828"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: modelData.image || ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(0, 0, 0, 0.4)
                                                visible: rowMouse.containsMouse || (root.currentTrack && root.currentTrack.path === modelData.path)

                                                SpotifyIcon {
                                                    anchors.centerIn: parent
                                                    source: (root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying)
                                                            ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                            : "../assets/icons/media-playback-start-symbolic.svg"
                                                    iconSize: 18
                                                    color: Theme.spotifyGreen
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.title || modelData.name || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: (root.currentTrack && root.currentTrack.path === modelData.path) ? Theme.spotifyGreen : Theme.textPrimary
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.artist || modelData.subtitle || "YouTube Music"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.textSecondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            text: modelData.duration || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.textMuted
                                            Layout.rightMargin: 8
                                            visible: modelData.duration && modelData.duration !== "--:--"
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                var pt = gridItem.mapToItem(null, mouse.x, mouse.y);
                                                root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                            } else {
                                                if (modelData.type === "playlist") {
                                                    root.playlistSelected(modelData);
                                                } else {
                                                    root.trackPlayRequested(modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Case B: Card Carousel Layout (Horizontal Scroll)
                        Flickable {
                            id: carouselFlick
                            Layout.fillWidth: true
                            height: 236
                            visible: modelData.type === "card_carousel"
                            contentWidth: cardRow.implicitWidth
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.HorizontalFlick
                            clip: true

                            NumberAnimation on contentX {
                                id: scrollAnim
                                running: false
                                duration: 280
                                easing.type: Easing.OutCubic
                            }

                            RowLayout {
                                id: cardRow
                                spacing: 16

                                Repeater {
                                    model: modelData.type === "card_carousel" ? modelData.items : []

                                    Rectangle {
                                        id: cCard
                                        width: 160
                                        height: 230
                                        radius: Theme.radiusCard
                                        color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: width
                                                radius: 6
                                                color: "#282828"
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.image || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }

                                                Rectangle {
                                                    width: 38
                                                    height: 38
                                                    radius: 19
                                                    color: Theme.spotifyGreen
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    visible: cardMouse.containsMouse

                                                    SpotifyIcon {
                                                        anchors.centerIn: parent
                                                        anchors.horizontalCenterOffset: 1
                                                        source: "../assets/icons/media-playback-start-symbolic.svg"
                                                        iconSize: 16
                                                        color: "#000000"
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.title || modelData.name || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.subtitle || modelData.artist || "YouTube Music"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.textSecondary
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }

                                            Item { Layout.fillHeight: true }
                                        }

                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    var pt = cCard.mapToItem(null, mouse.x, mouse.y);
                                                    root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                                } else {
                                                    if (modelData.type === "track" || (modelData.path && modelData.path.indexOf("ytdl://") === 0) || modelData.videoId) {
                                                        root.trackPlayRequested(modelData);
                                                    } else {
                                                        root.playlistSelected(modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // 3. Fallback View (when sections is empty or loading)
            // =========================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: !root.sections || root.sections.length === 0

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "LET'S START WITH A RADIO"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Quick picks"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                // Grid of Quick picks (2 columns of rows)
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.width > 900 ? 3 : 2
                    rowSpacing: 8
                    columnSpacing: 12

                    Repeater {
                        model: root.quickPicks.slice(0, 18)

                        Rectangle {
                            id: qpCard
                            Layout.fillWidth: true
                            height: 56
                            radius: 6
                            color: qpMouse.containsMouse ? "#282828" : "#1a1a1a"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 12

                                // Thumbnail with hover play overlay
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 4
                                    color: "#282828"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.4)
                                        visible: qpMouse.containsMouse || (root.currentTrack && root.currentTrack.path === modelData.path)

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            source: (root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying)
                                                    ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                    : "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
                                            color: Theme.spotifyGreen
                                        }
                                    }
                                }

                                // Title & Artist
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.name || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: (root.currentTrack && root.currentTrack.path === modelData.path) ? Theme.spotifyGreen : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.artist || "YouTube Music"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: qpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pt = qpCard.mapToItem(null, mouse.x, mouse.y);
                                        root.trackContextMenuRequested(modelData, pt.x, pt.y);
                                    } else {
                                        root.trackPlayRequested(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Section: "Featured playlists for you"
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 14
                visible: root.featuredPlaylists && root.featuredPlaylists.length > 0

                Text {
                    text: root.selectedMood === "All" ? "Featured playlists for you" : (root.selectedMood + " Playlists")
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: Theme.textPrimary
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 16

                    Repeater {
                        model: root.featuredPlaylists

                        Rectangle {
                            width: 172
                            height: 240
                            radius: Theme.radiusCard
                            color: plMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width
                                    radius: 6
                                    color: "#282828"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    // Spotify Floating Green Play Button on Hover
                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: Theme.spotifyGreen
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        visible: plMouse.containsMouse

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            source: "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
                                            color: "#000000"
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.subtitle || "Playlist"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                Item { Layout.fillHeight: true }
                            }

                            MouseArea {
                                id: plMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playlistSelected(modelData)
                            }
                        }
                    }
                }
            }

            // Bottom padding for scroll
            Item { height: 24 }
        }
    }
}
