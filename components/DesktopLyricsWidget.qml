import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var activeLyrics: []
    property real currentTime: 0.0
    property bool isPlaying: false
    property var currentTrack: null
    property bool enabled: true
    property int lyricsPreset: 2 // 1: Gacha / Anime Pop, 2: Apple Music 3-Line
    property int customX: -1
    property int customY: -1

    signal positionChanged(int newX, int newY)

    screen: Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "frostify:desktop_lyrics"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Instrument Serif (Cinematic Typeface) & Fonts
    FontLoader {
        id: instrumentSerifFont
        source: "../assets/fonts/InstrumentSerif-Regular.ttf"
    }

    FontLoader {
        id: instrumentSerifItalicFont
        source: "../assets/fonts/InstrumentSerif-Italic.ttf"
    }

    readonly property string magicFontFamily: (instrumentSerifFont.status === FontLoader.Ready && instrumentSerifFont.name !== "") ? instrumentSerifFont.name : "Instrument Serif"

    // =========================================================================
    // Dynamic Adaptive Palette Engine (Auto-syncs with active wallpaper)
    // =========================================================================
    property var frostifyPalette: ({
        "isLightArea": false,
        "baseTextColor": "#f8fafc",
        "highlightColor": "#deb06c",
        "deadTextColor": "#f1f5f9",
        "shadowDirectional": "#a6020305",
        "shadowAmbient": "#66000000"
    })

    Timer {
        id: delayedPaletteRead
        interval: 80
        repeat: false
        running: false
        onTriggered: {
            if (frostifyPaletteFile.loaded) {
                parseFrostifyPalette(frostifyPaletteFile.text());
            }
        }
    }

    FileView {
        id: frostifyPaletteFile
        path: Quickshell.env("HOME") + "/.config/noctalia/nutsty_palette.json"
        watchChanges: true
        onFileChanged: {
            this.reload();
            delayedPaletteRead.start();
        }
        onLoadedChanged: {
            if (this.loaded) {
                parseFrostifyPalette(this.text());
            }
        }
        Component.onCompleted: {
            if (this.loaded) {
                parseFrostifyPalette(this.text());
            }
        }
    }

    function parseFrostifyPalette(raw) {
        if (!raw || raw.trim() === "") return;
        try {
            var obj = JSON.parse(raw);
            var updated = Object.assign({}, root.frostifyPalette);
            for (var k in obj) {
                updated[k] = obj[k];
            }
            root.frostifyPalette = updated;
        } catch(e) {}
    }

    readonly property color colHighlight: root.frostifyPalette.highlightColor || "#deb06c"
    readonly property color colActiveText: root.frostifyPalette.baseTextColor || "#f8fafc"
    readonly property color colDeadText: root.frostifyPalette.deadTextColor || "#f1f5f9"
    readonly property color colShadowDir: root.frostifyPalette.shadowDirectional || "#a6020305"
    readonly property color colShadowAmb: root.frostifyPalette.shadowAmbient || "#66000000"
    readonly property bool isLightArea: !!root.frostifyPalette.isLightArea

    // =========================================================================
    // Synchronized Timing Engine (Single Line Active + Deep Languid Exiting Fade)
    // =========================================================================
    property int currentLyricIndex: -1
    property real currentLineStart: 0.0
    property real currentLineEnd: 0.0
    property real lineProgress: 0.0

    property string activeLineText: ""
    property string fadingLineText: ""

    // Raised position on the maid skirt/lap area (y ≈ 72.5%)
    readonly property int activeY: Math.round(root.height * 0.725)
    readonly property int activeX: Math.round(root.width * 0.145)

    onCurrentTimeChanged: updateProgress()
    onActiveLyricsChanged: updateProgress()

    function updateProgress() {
        if (!activeLyrics || activeLyrics.length === 0) {
            currentLyricIndex = -1;
            lineProgress = 0.0;
            activeLineText = "";
            fadingLineText = "";
            return;
        }

        var idx = -1;
        for (var i = 0; i < activeLyrics.length; i++) {
            var startTime = activeLyrics[i].time;
            var nextTime = (i + 1 < activeLyrics.length) ? activeLyrics[i + 1].time : (startTime + 5.0);
            if (currentTime >= startTime && currentTime < nextTime) {
                idx = i;
                currentLineStart = startTime;
                currentLineEnd = nextTime;
                var duration = Math.max(0.4, nextTime - startTime);
                lineProgress = Math.min(1.0, Math.max(0.0, (currentTime - startTime) / duration));
                break;
            }
        }

        if (idx !== currentLyricIndex) {
            if (currentLyricIndex >= 0 && idx > currentLyricIndex && activeLyrics && currentLyricIndex < activeLyrics.length) {
                // Completed previous line -> trigger smooth, deep fade-down exit!
                triggerFadeOutLine(activeLyrics[currentLyricIndex].text);
            }
            currentLyricIndex = idx;
            if (idx >= 0 && activeLyrics && idx < activeLyrics.length) {
                activeLineText = activeLyrics[idx].text;
            } else {
                activeLineText = "";
            }
        }
    }

    function triggerFadeOutLine(oldText) {
        fadingLineText = oldText;
        fadingContainer.opacity = 0.78;
        fadingContainer.y = activeY;
        fadingContainer.rotation = 0;
        fadeDownExitAnim.restart();
    }

    // =========================================================================
    // PRESET 1: Gacha / Pop Anime Instrument Serif (1 Active Line + Falling Fade)
    // =========================================================================
    Item {
        id: preset1Container
        anchors.fill: parent
        visible: root.enabled && root.lyricsPreset === 1 && root.activeLyrics.length > 0 && (activeLineText !== "" || fadingLineText !== "")

        // EXITING LINE: Sinks deep (+52px), lingers gracefully, then fades smoothly to 0
        Item {
            id: fadingContainer
            x: (root.customX >= 0) ? root.customX : root.activeX
            y: (root.customY >= 0) ? root.customY : root.activeY
            width: Math.min(740, Math.round(parent.width * 0.45))
            height: 68
            transformOrigin: Item.Left
            opacity: 0.0
            visible: fadingLineText !== "" && opacity > 0.01

            EnchantingSentence {
                id: fadingSentence
                anchors.fill: parent
                text: root.fadingLineText
                progress: 1.0
                isActive: false
                isDead: true
                fontFamily: root.magicFontFamily
                fontSize: 35
                colHighlight: root.colHighlight
                colActiveText: root.colActiveText
                colDeadText: root.colDeadText
                colShadowDirectional: root.colShadowDir
                colShadowAmbient: root.colShadowAmb
                isLightArea: root.isLightArea
            }

            SequentialAnimation {
                id: fadeDownExitAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: fadingContainer
                        property: "y"
                        from: (root.customY >= 0) ? root.customY : root.activeY
                        to: ((root.customY >= 0) ? root.customY : root.activeY) + 52
                        duration: 1600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: fadingContainer
                        property: "rotation"
                        from: 0
                        to: 1.8
                        duration: 1600
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: fadingContainer
                            property: "opacity"
                            from: 0.78
                            to: 0.65
                            duration: 450
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: fadingContainer
                            property: "opacity"
                            from: 0.65
                            to: 0.0
                            duration: 1150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                ScriptAction {
                    script: {
                        root.fadingLineText = "";
                    }
                }
            }
        }

        // ACTIVE LYRIC LINE: 1-Line only
        Item {
            id: activeContainer
            x: (root.customX >= 0) ? root.customX : root.activeX
            y: (root.customY >= 0) ? root.customY : root.activeY
            width: Math.min(740, Math.round(parent.width * 0.45))
            height: 68

            EnchantingSentence {
                id: activeSentence
                anchors.fill: parent
                text: root.activeLineText
                progress: root.lineProgress
                isActive: root.currentLyricIndex >= 0
                isDead: false
                fontFamily: root.magicFontFamily
                fontSize: 35
                colHighlight: root.colHighlight
                colActiveText: root.colActiveText
                colDeadText: root.colDeadText
                colShadowDirectional: root.colShadowDir
                colShadowAmbient: root.colShadowAmb
                isLightArea: root.isLightArea
            }
        }
    }

    // =========================================================================
    // PRESET 2: Apple Music 3-Line Fluid Sync (Depth-of-Field + Neon Karaoke Wipe)
    // =========================================================================
    AppleMusicDesktopLyrics {
        anchors.fill: parent
        visible: root.enabled && root.lyricsPreset === 2
        activeLyrics: root.activeLyrics
        currentTime: root.currentTime
        isPlaying: root.isPlaying
        currentTrack: root.currentTrack
        colHighlight: root.colHighlight
        colActiveText: root.colActiveText
        colShadowDir: root.colShadowDir
        colShadowAmb: root.colShadowAmb
        customX: root.customX
        customY: root.customY
        onPositionChanged: (newX, newY) => {
            root.customX = newX;
            root.customY = newY;
            root.positionChanged(newX, newY);
        }
    }
}
