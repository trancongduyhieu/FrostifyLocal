import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: root
    color: "transparent"
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
    property Item backgroundSourceItem: null
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

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

    // Dynamic feed sections model with fallbacks
    readonly property var activeFeedSections: {
        if (root.sections && root.sections.length > 0) {
            return root.sections;
        }
        if (root.isLoading) {
            return [
                { type: "skeleton_section", title: "Recommended for you", subtitle: "LOADING", items: [1, 2, 3, 4, 5, 6] },
                { type: "skeleton_section", title: "Listen again", subtitle: "DISCOVER", items: [1, 2, 3, 4, 5, 6] }
            ];
        }
        var fallbacks = [];
        if (root.quickPicks && root.quickPicks.length > 0) {
            fallbacks.push({
                type: "fallback_quick_picks",
                title: "Quick picks",
                subtitle: "LET'S START WITH A RADIO",
                items: root.quickPicks
            });
        }
        if (root.featuredPlaylists && root.featuredPlaylists.length > 0) {
            fallbacks.push({
                type: "fallback_playlists",
                title: root.selectedMood === "All" ? "Featured playlists for you" : (root.selectedMood + " Playlists"),
                items: root.featuredPlaylists
            });
        }
        return fallbacks;
    }

    // =========================================================================
    // VIRTUALIZED MAIN VIEWPORT (ListView with Culling, Recycling & CacheBuffer)
    // =========================================================================
    ListView {
        id: feedListView
        anchors.fill: parent
        clip: true
        spacing: 28
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true
        maximumFlickVelocity: 6000
        flickDeceleration: 1500
        cacheBuffer: 800
        reuseItems: true
        model: root.activeFeedSections

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // ---------------------------------------------------------------------
        // 1. Header: Greeting & Mood Pills Bar
        // ---------------------------------------------------------------------
        header: Item {
            width: feedListView.width
            height: headerCol.implicitHeight + 16

            ColumnLayout {
                id: headerCol
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 14

                Text {
                    text: root.getGreeting()
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.textPrimary
                }

                // Separated Mood Filter Pills with Sliding Liquid Glass Lens (True Keo 502 Refraction)
                Item {
                    id: moodDockContainer
                    Layout.fillWidth: true
                    height: 38

                    // Horizontal Scrollable Mood Items
                    Flickable {
                        id: homeMoodFlickable
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        contentWidth: moodRow.width + 16
                        contentHeight: height
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        pixelAligned: true
                        clip: false

                        DragHandler {
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false
                            cursorShape: Qt.OpenHandCursor
                            onTranslationChanged: {
                                var newX = homeMoodFlickable.contentX - translation.x;
                                homeMoodFlickable.contentX = Math.max(0, Math.min(homeMoodFlickable.contentWidth - homeMoodFlickable.width, newX));
                            }
                        }

                        WheelHandler {
                            target: homeMoodFlickable
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                var delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x);
                                homeMoodFlickable.contentX = Math.max(0, Math.min(homeMoodFlickable.contentWidth - homeMoodFlickable.width, homeMoodFlickable.contentX - delta));
                            }
                        }

                        readonly property real accentLuminance: (0.299 * root.accentColor.r + 0.587 * root.accentColor.g + 0.114 * root.accentColor.b)

                        // Ambient drop shadow for the sliding active Keo 502 gel capsule
                        MultiEffect {
                            anchors.fill: activeMoodIndicator
                            source: activeMoodIndicator
                            shadowEnabled: true
                            shadowColor: "#50000000"
                            shadowVerticalOffset: 2
                            shadowBlur: 0.45
                            visible: activeMoodIndicator.width > 0
                            z: 1
                        }

                        // Sliding Keo 502 Glossy Gel Capsule (Fluid Meniscus, Rich Solid-Glass Contrast, ZERO glare streaks!)
                        Rectangle {
                            id: activeMoodIndicator
                            height: 30
                            radius: 15
                            y: (homeMoodFlickable.height - height) / 2
                            z: 2
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.90)
                            border.color: Qt.rgba(root.accentColor.r * 1.15, root.accentColor.g * 1.15, root.accentColor.b * 1.15, 0.95)
                            border.width: 1
                            visible: width > 0

                            // Inner Meniscus Specular Rim (Tension highlight without bleaching text)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 14
                                color: "transparent"
                                border.color: Qt.rgba(1.0, 1.0, 1.0, homeMoodFlickable.accentLuminance > 0.55 ? 0.35 : 0.22)
                                border.width: 1
                            }

                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }

                        // Separated Mood Pills Row
                        Row {
                            id: moodRow
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            z: 5

                            Repeater {
                                id: moodRepeater
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

                                delegate: Item {
                                    id: pillItem
                                    height: 30
                                    width: pillTxt.implicitWidth + 24
                                    readonly property bool isSelected: root.selectedMood === modelData.title
                                    readonly property bool isHovered: pillMouse.containsMouse

                                    onIsSelectedChanged: {
                                        if (isSelected) {
                                            activeMoodIndicator.x = pillItem.x;
                                            activeMoodIndicator.width = pillItem.width;
                                        }
                                    }
                                    Component.onCompleted: {
                                        if (isSelected) {
                                            activeMoodIndicator.x = pillItem.x;
                                            activeMoodIndicator.width = pillItem.width;
                                        }
                                    }

                                    // Standalone Inactive Dark Glass Capsule (Zero white glare streaks, clean optical glass)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: pillItem.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16) : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                        border.width: 1
                                        border.color: pillItem.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                        opacity: pillItem.isSelected ? 0.0 : 1.0
                                        scale: (pillItem.isHovered && !pillItem.isSelected) ? 1.03 : 1.0

                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                    }

                                    Text {
                                        id: pillTxt
                                        anchors.centerIn: parent
                                        text: modelData.title
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: pillItem.isSelected ? Font.Bold : Font.DemiBold
                                        color: pillItem.isSelected 
                                               ? (homeMoodFlickable.accentLuminance > 0.55 ? "#0f0f11" : "#ffffff") 
                                               : (pillItem.isHovered ? "#ffffff" : Qt.rgba(1.0, 1.0, 1.0, 0.70))
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    MouseArea {
                                        id: pillMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedMood = modelData.title;
                                            root.moodSelected(modelData.title, modelData.params || "");
                                        }
                                    }
                                }
                            }
                        }

                        function updateActiveIndicator() {
                            for (var i = 0; i < moodRepeater.count; ++i) {
                                var itm = moodRepeater.itemAt(i);
                                if (itm && itm.isSelected) {
                                    activeMoodIndicator.x = itm.x;
                                    activeMoodIndicator.width = itm.width;
                                    return;
                                }
                            }
                        }

                        Component.onCompleted: Qt.callLater(updateActiveIndicator)
                    }

                    Connections {
                        target: root
                        function onSelectedMoodChanged() {
                            homeMoodFlickable.updateActiveIndicator();
                        }
                        function onMoodsChanged() {
                            Qt.callLater(homeMoodFlickable.updateActiveIndicator);
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. Footer: Bottom Padding for Floating Player Bar Dock
        // ---------------------------------------------------------------------
        footer: Item {
            width: feedListView.width
            height: 120
        }

        // ---------------------------------------------------------------------
        // 3. Delegate: Virtualized Section Renderer
        // ---------------------------------------------------------------------
        delegate: Item {
            id: secDelegate
            width: feedListView.width
            height: sectionCol.implicitHeight

            ColumnLayout {
                id: sectionCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 12

                // --- Section Header Row ---
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

                            AppIcon {
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

                            AppIcon {
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

                // =============================================================
                // Case A: Track Grid Layout (2-3 Columns of Compact Rows)
                // =============================================================
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
                            clip: true
                            color: (root.currentTrack && root.currentTrack.path === modelData.path)
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                                   : (rowMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.07) : Qt.rgba(1.0, 1.0, 1.0, 0.02))
                            border.color: (root.currentTrack && root.currentTrack.path === modelData.path)
                                          ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                          : (rowMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06))
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 12

                                Item {
                                    width: 44
                                    height: 44

                                    Rectangle {
                                        id: rowImgMask
                                        anchors.fill: parent
                                        radius: 6
                                        color: "#ffffff"
                                        visible: false
                                        layer.enabled: true
                                    }

                                    Item {
                                        anchors.fill: parent
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: rowImgMask
                                            autoPaddingEnabled: false
                                        }

                                        Image {
                                            id: rowImg
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            sourceSize: Qt.size(64, 64)
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        // Skeleton Pulsing Shimmer Placeholder
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#2c2c34"
                                            visible: rowImg.status !== Image.Ready
                                            SequentialAnimation on opacity {
                                                running: parent.visible
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 0.30; to: 0.70; duration: 750; easing.type: Easing.InOutQuad }
                                                NumberAnimation { from: 0.70; to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: Qt.rgba(0, 0, 0, 0.45)
                                        visible: rowMouse.containsMouse || (root.currentTrack && root.currentTrack.path === modelData.path)

                                        AppIcon {
                                            anchors.centerIn: parent
                                            source: (root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying)
                                                    ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                    : "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
                                            color: root.accentColor
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
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
                                        color: (root.currentTrack && root.currentTrack.path === modelData.path) ? root.accentColor : Theme.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.artist || "Cloud Stream").split("\n")[0]
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
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
                                        root.trackPlayRequested(modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // Case B: Card Carousel Layout (Horizontal Scroll)
                // =============================================================
                Flickable {
                    id: carouselFlick
                    Layout.fillWidth: true
                    height: 236
                    visible: modelData.type === "card_carousel"
                    contentWidth: cardRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    pixelAligned: true
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
                                color: cardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.02)
                                border.color: cardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: width

                                        Rectangle {
                                            id: cCoverMask
                                            anchors.fill: parent
                                            radius: 8
                                            color: "#ffffff"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: cCoverMask
                                                autoPaddingEnabled: false
                                            }

                                            Image {
                                                id: cCoverImg
                                                anchors.fill: parent
                                                source: modelData.image || ""
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize: Qt.size(220, 220)
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }

                                            // Skeleton Pulsing Shimmer Placeholder
                                            Rectangle {
                                                anchors.fill: parent
                                                color: "#2c2c34"
                                                visible: cCoverImg.status !== Image.Ready
                                                SequentialAnimation on opacity {
                                                    running: parent.visible
                                                    loops: Animation.Infinite
                                                    NumberAnimation { from: 0.30; to: 0.70; duration: 750; easing.type: Easing.InOutQuad }
                                                    NumberAnimation { from: 0.70; to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
                                                }
                                            }
                                        }

                                        // 1px Hairline Border Overlay on top of image
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: "transparent"
                                            border.color: cardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.40) : Qt.rgba(1.0, 1.0, 1.0, 0.16)
                                            border.width: 1
                                            z: 1
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                        }

                                        Rectangle {
                                            width: 38
                                            height: 38
                                            radius: 19
                                            color: root.accentColor
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 6
                                            visible: cardMouse.containsMouse
                                            z: 2

                                            AppIcon {
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
                                        text: modelData.subtitle || modelData.artist || "Cloud Stream"
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
                                            if (modelData.type === "album" || (modelData.browseId && String(modelData.browseId).startsWith("MPREb_")) || (modelData.playlistId && String(modelData.playlistId).startsWith("MPREb_"))) {
                                                root.playlistSelected(modelData);
                                            } else if (modelData.type === "track" || (modelData.path && modelData.path.indexOf("ytdl://") === 0) || modelData.videoId) {
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

                // =============================================================
                // Case C: Fallback Quick Picks Grid
                // =============================================================
                GridLayout {
                    Layout.fillWidth: true
                    visible: modelData.type === "fallback_quick_picks"
                    columns: root.width > 900 ? 3 : 2
                    rowSpacing: 8
                    columnSpacing: 12

                    Repeater {
                        model: modelData.type === "fallback_quick_picks" ? modelData.items.slice(0, 18) : []

                        Rectangle {
                            id: qpCard
                            Layout.fillWidth: true
                            height: 56
                            radius: 6
                            clip: true
                            color: (root.currentTrack && root.currentTrack.path === modelData.path)
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                                   : (qpMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.07) : Qt.rgba(1.0, 1.0, 1.0, 0.02))
                            border.color: (root.currentTrack && root.currentTrack.path === modelData.path)
                                          ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                          : (qpMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06))
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

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
                                        id: qpImg
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(64, 64)
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    // Skeleton Pulsing Shimmer Placeholder
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#2c2c34"
                                        visible: qpImg.status !== Image.Ready
                                        SequentialAnimation on opacity {
                                            running: parent.visible
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.30; to: 0.70; duration: 750; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.4)
                                        visible: qpMouse.containsMouse || (root.currentTrack && root.currentTrack.path === modelData.path)

                                        AppIcon {
                                            anchors.centerIn: parent
                                            source: (root.currentTrack && root.currentTrack.path === modelData.path && root.isPlaying)
                                                    ? "../assets/icons/media-playback-pause-symbolic.svg"
                                                    : "../assets/icons/media-playback-start-symbolic.svg"
                                            iconSize: 18
                                            color: root.accentColor
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
                                        color: (root.currentTrack && root.currentTrack.path === modelData.path) ? root.accentColor : Theme.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.artist || "Cloud Stream").split("\n")[0]
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
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

                // =============================================================
                // Case D: Fallback Featured Playlists Flow
                // =============================================================
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: modelData.type === "fallback_playlists"

                    Repeater {
                        model: modelData.type === "fallback_playlists" ? modelData.items : []

                        Rectangle {
                            width: 172
                            height: 240
                            radius: Theme.radiusCard
                            color: plMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.02)
                            border.color: plMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

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
                                        id: plImg
                                        anchors.fill: parent
                                        source: modelData.image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(200, 200)
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    // Skeleton Pulsing Shimmer Placeholder
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#2c2c34"
                                        visible: plImg.status !== Image.Ready
                                        SequentialAnimation on opacity {
                                            running: parent.visible
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.30; to: 0.70; duration: 750; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: root.accentColor
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        visible: plMouse.containsMouse

                                        AppIcon {
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

                // =============================================================
                // Case E: Skeleton Placeholder Row (Initial Loading State)
                // =============================================================
                Flickable {
                    Layout.fillWidth: true
                    height: 250
                    visible: modelData.type === "skeleton_section"
                    contentWidth: skelRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true
                    interactive: false

                    RowLayout {
                        id: skelRow
                        spacing: 16

                        Repeater {
                            model: [
                                { tw: 120, sw: 80 },
                                { tw: 140, sw: 95 },
                                { tw: 110, sw: 75 },
                                { tw: 130, sw: 85 },
                                { tw: 125, sw: 90 },
                                { tw: 135, sw: 80 }
                            ]

                            SkeletonTrackCard {
                                width: 160
                                height: 230
                                titleWidth: modelData.tw
                                subtitleWidth: modelData.sw
                            }
                        }
                    }
                }

                Item { height: 16 }
            }
        }
    }
}
