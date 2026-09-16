import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // =========================================================================
    // Reactive Properties forwarded from DesktopLyricsWidget harness
    // =========================================================================
    property var activeLyrics: []
    property real currentTime: 0.0
    property bool isPlaying: false
    property string magicFontFamily: "Impact"

    // Adaptive Palette Colors from wallpaper (with cel-shadows)
    property color colHighlight: "#deb06c"
    property color colActiveText: "#ffffff"
    property color colDeadText: "#a0aab8"
    property color colShadowDir: "#a6020305"
    property color colShadowAmb: "#66000000"
    property bool isLightArea: false

    implicitHeight: 150
    implicitWidth: 800

    // Condensed display gothic font with fallback for CJK / Vietnamese
    readonly property string displayFontFamily: root.isCJK
        ? "Noto Sans CJK JP, Noto Sans CJK SC, Noto Sans CJK KR, Montserrat, sans-serif"
        : "Impact, Montserrat, DejaVu Sans Condensed, Noto Sans CJK JP, sans-serif"

    // CJK & Non-Latin detection for Japanese / Chinese / Korean typography balancing
    readonly property bool isCJK: /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]/.test(currentRawText)

    // =========================================================================
    // Chromatic Salience Token Graph (color-expert principles)
    // Synchronized with Wallpaper OKLAB / OKLCH Extraction
    // =========================================================================
    readonly property color colAccent: root.colHighlight.toString() !== "" ? root.colHighlight : "#deb06c"
    readonly property color colPrimary: root.isLightArea ? "#1e1e2e" : (root.colActiveText.toString() !== "" ? root.colActiveText : "#f8fafc")
    readonly property color colSecondary: root.isLightArea
        ? Qt.darker(colAccent, 1.3)
        : Qt.tint(colPrimary, Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.45))
    readonly property color celShadow: "#000000"

    // =========================================================================
    // Synchronized Timing & Scene Director Engine
    // =========================================================================
    property int currentLyricIndex: -1
    property real currentLineStart: 0.0
    property real currentLineEnd: 0.0
    property real lineDuration: 1.0
    property real lineProgress: 0.0

    property string currentRawText: ""
    property var currentWords: []
    property string sceneType: "PUSH_LEFT"
    property int sceneCycleCount: 0

    // Anti-flash gate: Prevents the initial whole-sentence flash during transitions
    property bool isSentenceTransitioning: false

    // Measured widths cache for dynamic horizontal centering
    property var measuredWordWidths: ({})

    Timer {
        id: transitionGateTimer
        interval: 35
        repeat: false
        onTriggered: root.isSentenceTransitioning = false
    }

    onCurrentTimeChanged: updateProgress()
    onActiveLyricsChanged: updateProgress()

    function updateProgress() {
        if (!activeLyrics || activeLyrics.length === 0) {
            if (currentLyricIndex !== -1) {
                currentLyricIndex = -1;
                lineProgress = 0.0;
                currentRawText = "";
                currentWords = [];
                sceneType = "PUSH_LEFT";
            }
            return;
        }

        var idx = -1;
        var st = 0.0;
        var et = 0.0;

        for (var i = 0; i < activeLyrics.length; i++) {
            var curSt = activeLyrics[i].time;
            var curEt = (i + 1 < activeLyrics.length) ? activeLyrics[i + 1].time : (curSt + 5.0);
            if (currentTime >= curSt && currentTime < curEt) {
                idx = i;
                st = curSt;
                et = curEt;
                break;
            }
        }

        if (idx !== -1) {
            currentLineStart = st;
            currentLineEnd = et;
            lineDuration = Math.min(6.5, Math.max(0.6, et - st));
            var newProgress = Math.min(1.0, Math.max(0.0, (currentTime - st) / lineDuration));

            // Sentence change detection
            if (idx !== currentLyricIndex) {
                // Instantly lock transition gate to prevent ANY initial flash
                isSentenceTransitioning = true;
                currentLyricIndex = idx;
                lineProgress = 0.0; // Reset progress to 0 for new sentence immediately
                measuredWordWidths = {};
                sceneCycleCount++;

                var rawNew = activeLyrics[idx].text ? activeLyrics[idx].text.trim() : "";
                currentRawText = rawNew;
                classifyAndAssembleScene(rawNew);

                // Release gate after 1 frame once geometry and bindings settle
                transitionGateTimer.restart();
            } else {
                if (!isSentenceTransitioning) {
                    lineProgress = newProgress;
                }
            }
        } else {
            currentLyricIndex = -1;
            lineProgress = 0.0;
            currentRawText = "";
            currentWords = [];
            sceneType = "PUSH_LEFT";
        }
    }

    // =========================================================================
    // Intelligent Multi-Language Tokenizer (Latin whitespace + CJK Bunsetsu)
    // =========================================================================
    function tokenizeText(raw) {
        if (!raw || raw.trim() === "") return [];
        var isCjk = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]/.test(raw);
        if (!isCjk) {
            return raw.split(/\s+/).filter(function(w) { return w.length > 0; });
        }
        // CJK Tokenizer: split by punctuation & whitespace
        var pieces = raw.split(/[\s,，、。！？!?…~～·・—\-_()（）\[\]【】\"'“”‘’「」『』]+/);
        var result = [];
        for (var i = 0; i < pieces.length; i++) {
            var p = pieces[i].trim();
            if (!p) continue;
            if (/[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]/.test(p)) {
                // If contains Japanese Kana
                if (/[\u3040-\u30ff]/.test(p)) {
                    var pattern = /([\u4e00-\u9fff]+[\u3040-\u309f]{0,2}|[\u30a0-\u30ff]+|[\u3040-\u309f]{1,3}|[a-zA-Z0-9]+)/g;
                    var match;
                    var found = [];
                    while ((match = pattern.exec(p)) !== null) {
                        if (match[0]) found.push(match[0]);
                    }
                    if (found.length > 0) {
                        for (var j = 0; j < found.length; j++) result.push(found[j]);
                    } else {
                        result.push(p);
                    }
                } else {
                    // Pure Hanzi (Chinese) or Kanji compound without kana
                    if (p.length === 3) {
                        // 3-character phrase (e.g. 我爱你 -> 我, 爱, 你)
                        result.push(p.substring(0, 1));
                        result.push(p.substring(1, 2));
                        result.push(p.substring(2, 3));
                    } else if (p.length >= 4) {
                        // Group into logical 2-character words (e.g. 所以那就离开吧 -> 所以, 那就, 离开, 吧)
                        for (var k = 0; k < p.length; k += 2) {
                            result.push(p.substring(k, Math.min(p.length, k + 2)));
                        }
                    } else {
                        result.push(p);
                    }
                }
            } else {
                result.push(p);
            }
        }
        return result.length > 0 ? result : [raw.trim()];
    }

    // =========================================================================
    // Scene Classifier: Map Sentence to 1 of 10 Anime MV Choreography Patterns
    // =========================================================================
    function classifyAndAssembleScene(raw) {
        if (!raw || raw.trim() === "") {
            currentWords = [];
            sceneType = "PUSH_LEFT";
            return;
        }

        var words = tokenizeText(raw);
        if (words.length === 0) {
            currentWords = [];
            sceneType = "PUSH_LEFT";
            return;
        }

        var n = words.length;
        var chosenScene = "PUSH_LEFT";

        if (n === 1) {
            var w = words[0];
            var isCjkWord = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]/.test(w);
            if (!isCjkWord && w.length >= 4 && w.length <= 6 && (sceneCycleCount % 3 === 0)) {
                chosenScene = "LETTER_DROP"; // e.g. H-E-A-R-T (Latin only)
            } else if (!isCjkWord && w.length >= 4 && (sceneCycleCount % 3 === 1)) {
                chosenScene = "COMPOUND"; // e.g. "HELLO" -> HEL + LO (Latin only)
            } else {
                chosenScene = "GIANT_WORD"; // e.g. SAID, 知夏
            }
        } else if (n === 2) {
            if (sceneCycleCount % 2 === 0) {
                chosenScene = "FLANKING"; // e.g. OH ... NO or AM ... I
            } else {
                chosenScene = "STACK_EQUAL"; // e.g. FALLING / IN
            }
        } else if (n === 3) {
            if (sceneCycleCount % 2 === 0) {
                chosenScene = "PYRAMID"; // e.g. LOVE > WITH > ME
            } else {
                chosenScene = "VERTICAL_STACK"; // e.g. BUT / WHEN / YOU
            }
        } else if (n >= 4 && n <= 5) {
            if (sceneCycleCount % 2 === 0) {
                chosenScene = "BENTO_COLUMN"; // e.g. I WAS DOING / BETTER / ALONE
            } else {
                chosenScene = "PUSH_LEFT"; // e.g. ONE THAT COULD BREAK MY
            }
        } else {
            chosenScene = "PUSH_LEFT_FULL"; // e.g. I KNEW THAT WAS THE END OF ALL
        }

        // Allocate timing for words: All words reveal smoothly by 75% of sentence duration
        var list = [];
        var totalWords = words.length;
        var revealEndWindow = 0.75;

        for (var i = 0; i < totalWords; i++) {
            var startP = (totalWords > 1) ? (i / (totalWords - 0.25)) * revealEndWindow : 0.0;
            list.push({
                "word": words[i],
                "idx": i,
                "startProg": startP
            });
        }

        currentWords = list;
        sceneType = chosenScene;
    }

    // Helper: is word revealed? (With strict transition gate protection)
    function isWordRevealed(idx) {
        if (isSentenceTransitioning) return false;
        if (!currentWords || idx >= currentWords.length) return false;
        return lineProgress >= currentWords[idx].startProg;
    }

    // =========================================================================
    // VISUAL SCENES CONTAINER (All sizes halved for refined desktop balance)
    // =========================================================================
    Item {
        id: sceneContainer
        anchors.fill: parent
        clip: false

        // ---------------------------------------------------------------------
        // SCENE 1: FLANKING TWO WORDS (e.g. "OH ... NO" or "AM ... I")
        // ---------------------------------------------------------------------
        Item {
            id: sceneFlanking
            anchors.fill: parent
            visible: root.sceneType === "FLANKING" && root.currentWords.length >= 2

            // Left Word ("OH" / "AM")
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: flankingTextLeft.implicitWidth
                height: flankingTextLeft.implicitHeight

                property bool isRevealed: root.isWordRevealed(0)
                visible: isRevealed
                scale: isRevealed ? 1.0 : 1.15
                opacity: isRevealed ? 1.0 : 0.0
                Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                // Deep Cel Shadow
                Text {
                    x: 2.0; y: 2.5
                    text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.celShadow
                }
                // Front Text in Primary Wallpaper Color
                Text {
                    id: flankingTextLeft
                    text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.colPrimary
                }
                // Underline L-tick
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * 0.75
                    height: 1.5
                    color: root.colAccent
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 1.5
                    height: 7
                    color: root.colAccent
                }
            }

            // Right Word ("NO" / "I")
            Item {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: flankingTextRight.implicitWidth
                height: flankingTextRight.implicitHeight

                property bool isRevealed: root.isWordRevealed(1)
                visible: isRevealed
                scale: isRevealed ? 1.0 : 1.15
                opacity: isRevealed ? 1.0 : 0.0
                Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                // Deep Cel Shadow
                Text {
                    x: 2.0; y: 2.5
                    text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.celShadow
                }
                // Front Text in Accent Color
                Text {
                    id: flankingTextRight
                    text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.colAccent
                }
                // Underline R-tick
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: parent.width * 0.75
                    height: 1.5
                    color: root.colAccent
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1.5
                    height: 7
                    color: root.colAccent
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 2: STACKED EQUAL WITH L-BRACKET (e.g. "FALLING / IN")
        // ---------------------------------------------------------------------
        Item {
            id: sceneStackedEqual
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(stackedL1.implicitWidth, stackedL2.implicitWidth) + 24
            height: 90
            visible: root.sceneType === "STACK_EQUAL" && root.currentWords.length >= 2

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4

                // Word 1: FALLING (Accent color)
                Item {
                    width: stackedL1.implicitWidth
                    height: stackedL1.implicitHeight
                    property bool isRevealed: root.isWordRevealed(0)
                    visible: isRevealed
                    scale: isRevealed ? 1.0 : 1.12
                    opacity: isRevealed ? 1.0 : 0.0
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                    Text {
                        x: 2.0; y: 2.5
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 31 : 36
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: stackedL1
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 31 : 36
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colAccent
                    }
                }

                // Word 2: IN (Primary color)
                Item {
                    width: stackedL2.implicitWidth
                    height: stackedL2.implicitHeight
                    property bool isRevealed: root.isWordRevealed(1)
                    visible: isRevealed
                    scale: isRevealed ? 1.0 : 1.12
                    opacity: isRevealed ? 1.0 : 0.0
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                    Text {
                        x: 2.0; y: 2.5
                        text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 31 : 36
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: stackedL2
                        text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 31 : 36
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colPrimary
                    }
                }
            }

            // Vector L-Bracket bottom right accent
            Item {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 4
                width: 16
                height: 16
                opacity: root.isWordRevealed(1) ? 1.0 : 0.0
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 180 } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 16; height: 1.5; color: root.colAccent
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1.5; height: 16; color: root.colAccent
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 3: PYRAMID SIZES (e.g. "LOVE > WITH > ME")
        // ---------------------------------------------------------------------
        Item {
            id: scenePyramid
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(pyramidT1.implicitWidth, Math.max(pyramidT2.implicitWidth, pyramidT3.implicitWidth)) + 20
            height: 120
            visible: root.sceneType === "PYRAMID" && root.currentWords.length >= 3

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: -5

                // Word 1: LOVE (Largest, ~44px, Primary)
                Item {
                    width: pyramidT1.implicitWidth
                    height: pyramidT1.implicitHeight
                    property bool isRevealed: root.isWordRevealed(0)
                    visible: isRevealed
                    scale: isRevealed ? 1.0 : 1.15
                    opacity: isRevealed ? 1.0 : 0.0
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                    Text {
                        x: 2.0; y: 2.5
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: pyramidT1
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colPrimary
                    }
                }

                // Word 2: WITH (Medium, ~34px, Accent)
                Item {
                    width: pyramidT2.implicitWidth
                    height: pyramidT2.implicitHeight
                    property bool isRevealed: root.isWordRevealed(1)
                    visible: isRevealed
                    scale: isRevealed ? 1.0 : 1.15
                    opacity: isRevealed ? 1.0 : 0.0
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                    Text {
                        x: 2.0; y: 2.5
                        text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 29 : 34
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: pyramidT2
                        text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 29 : 34
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colAccent
                    }
                }

                // Word 3: ME (Smaller, ~26px, Secondary)
                Item {
                    width: pyramidT3.implicitWidth
                    height: pyramidT3.implicitHeight
                    property bool isRevealed: root.isWordRevealed(2)
                    visible: isRevealed
                    scale: isRevealed ? 1.0 : 1.15
                    opacity: isRevealed ? 1.0 : 0.0
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                    Text {
                        x: 1.5; y: 2.0
                        text: root.currentWords.length >= 3 ? root.currentWords[2].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 24 : 26
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: pyramidT3
                        text: root.currentWords.length >= 3 ? root.currentWords[2].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 24 : 26
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colSecondary
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 4: KINETIC PUSH-LEFT (e.g. "ONE THAT COULD BREAK MY")
        // ---------------------------------------------------------------------
        Item {
            id: scenePushLeft
            anchors.verticalCenter: parent.verticalCenter
            height: 56
            visible: (root.sceneType === "PUSH_LEFT" || root.sceneType === "PUSH_LEFT_FULL") && root.currentWords.length >= 4

            // Dynamic centering of revealed words
            property real activeClusterWidth: {
                var total = 0.0;
                var count = 0;
                for (var i = 0; i < root.currentWords.length; i++) {
                    if (root.isWordRevealed(i)) {
                        var wLen = root.currentWords[i].word.length;
                        var wEst = (root.measuredWordWidths && root.measuredWordWidths[i] > 0)
                            ? root.measuredWordWidths[i]
                            : Math.max(22.0, wLen * (root.sceneType === "PUSH_LEFT_FULL" ? 14.0 : 18.0));
                        total += wEst;
                        count++;
                    }
                }
                if (count > 1) total += (count - 1) * 9.0;
                return Math.max(30.0, total);
            }

            // Smooth X centering behavior: as new words appear on right, shifts left
            x: Math.max(10, Math.round((root.width - activeClusterWidth) / 2))
            Behavior on x { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                id: pushLeftRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Repeater {
                    model: root.currentWords

                    Item {
                        id: pushWordItem
                        property bool isRevealed: root.isWordRevealed(index)
                        width: pushWordTxt.implicitWidth
                        height: pushWordTxt.implicitHeight
                        visible: isRevealed

                        scale: isRevealed ? 1.0 : 1.15
                        opacity: isRevealed ? 1.0 : 0.0
                        Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }

                        Component.onCompleted: {
                            var map = Object.assign({}, root.measuredWordWidths);
                            map[index] = pushWordTxt.implicitWidth;
                            root.measuredWordWidths = map;
                        }

                        // Cel Shadow
                        Text {
                            x: 2.0; y: 2.5
                            text: modelData.word.toUpperCase()
                            font.family: root.displayFontFamily
                            font.pixelSize: (root.sceneType === "PUSH_LEFT_FULL") ? (root.isCJK ? 26 : 28) : (root.isCJK ? 31 : 36)
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.celShadow
                        }
                        // Front Text
                        Text {
                            id: pushWordTxt
                            text: modelData.word.toUpperCase()
                            font.family: root.displayFontFamily
                            font.pixelSize: (root.sceneType === "PUSH_LEFT_FULL") ? (root.isCJK ? 26 : 28) : (root.isCJK ? 31 : 36)
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            // Longest style (PUSH_LEFT_FULL) is strictly pure white (#ffffff)
                            // Shorter push-left alternates primary and accent for rhythm
                            color: (root.sceneType === "PUSH_LEFT_FULL") ? "#ffffff" : ((index % 2 === 0) ? root.colPrimary : root.colAccent)
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 5: VERTICAL LETTER DROP (e.g. "H - E - A - R - T")
        // ---------------------------------------------------------------------
        Item {
            id: sceneLetterDrop
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            height: 130
            visible: root.sceneType === "LETTER_DROP" && root.currentWords.length === 1

            property var letterList: {
                if (root.currentWords.length === 0) return [];
                var w = root.currentWords[0].word.toUpperCase();
                var arr = [];
                for (var i = 0; i < w.length; i++) {
                    arr.push({
                        "ch": w[i],
                        "idx": i,
                        "startProg": (i / Math.max(1, w.length)) * 0.72
                    });
                }
                return arr;
            }

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Repeater {
                    model: sceneLetterDrop.letterList

                    Item {
                        property bool isRevealed: !root.isSentenceTransitioning && (root.lineProgress >= modelData.startProg)
                        visible: isRevealed
                        width: letterTxt.implicitWidth
                        height: letterTxt.implicitHeight

                        y: isRevealed ? 0 : -10
                        opacity: isRevealed ? 1.0 : 0.0
                        scale: isRevealed ? 1.0 : 1.2
                        Behavior on y { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 160; easing.type: Easing.OutBounce } }
                        Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                        Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                        Text {
                            x: 1.5; y: 2.0
                            text: modelData.ch
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 24 : 24
                            font.weight: Font.Black
                            color: root.celShadow
                        }
                        Text {
                            id: letterTxt
                            text: modelData.ch
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 24 : 24
                            font.weight: Font.Black
                            color: root.colAccent
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 6: ARCHITECTURAL BENTO (e.g. "I WAS DOING / BETTER / ALONE")
        // ---------------------------------------------------------------------
        Item {
            id: sceneBentoColumn
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(bentoTopRow.implicitWidth, Math.max(bentoBetterItem.width, bentoAloneTxt.implicitWidth)) + 20
            height: 140
            visible: root.sceneType === "BENTO_COLUMN" && root.currentWords.length >= 4

            // Section 1: Pillar Word ("I") + Stacked Words ("WAS", "DOING")
            Row {
                id: bentoTopRow
                anchors.left: parent.left
                anchors.top: parent.top
                spacing: 6

                // Word 0: Pillar ("I") in Accent Color
                Item {
                    width: bentoPillar.implicitWidth
                    height: bentoPillar.implicitHeight
                    property bool isRevealed: root.isWordRevealed(0)
                    visible: isRevealed
                    opacity: isRevealed ? 1.0 : 0.0
                    scale: isRevealed ? 1.0 : 1.15
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        x: 2.0; y: 2.5
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 46 : 56
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.celShadow
                    }
                    Text {
                        id: bentoPillar
                        text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 46 : 56
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        color: root.colAccent
                    }
                }

                // Words 1 & 2: Stacked Right ("WAS", "DOING") in Primary Color
                Column {
                    id: bentoStackRight
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -3

                    // Word 1: "WAS"
                    Item {
                        width: bentoWasTxt.implicitWidth
                        height: bentoWasTxt.implicitHeight
                        property bool isRevealed: root.isWordRevealed(1)
                        visible: isRevealed
                        opacity: isRevealed ? 1.0 : 0.0
                        scale: isRevealed ? 1.0 : 1.15
                        Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                        Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        Text {
                            x: 1.5; y: 2.0
                            text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 22 : 24
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.celShadow
                        }
                        Text {
                            id: bentoWasTxt
                            text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 22 : 24
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.colPrimary
                        }
                    }

                    // Word 2: "DOING" with underline tick line
                    Item {
                        width: bentoDoingTxt.implicitWidth + 8
                        height: bentoDoingTxt.implicitHeight + 3
                        property bool isRevealed: root.isWordRevealed(2)
                        visible: isRevealed
                        opacity: isRevealed ? 1.0 : 0.0
                        scale: isRevealed ? 1.0 : 1.15
                        Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                        Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        Text {
                            x: 1.5; y: 2.0
                            text: root.currentWords.length >= 3 ? root.currentWords[2].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 22 : 24
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.celShadow
                        }
                        Text {
                            id: bentoDoingTxt
                            text: root.currentWords.length >= 3 ? root.currentWords[2].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 22 : 24
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.colPrimary
                        }

                        // Accent tick line underneath DOING
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1.5
                            color: root.colAccent
                        }
                    }
                }
            }

            // Word 3: "BETTER" (Spanning to match width of Top Section)
            Item {
                id: bentoBetterItem
                anchors.left: parent.left
                anchors.top: bentoTopRow.bottom
                anchors.topMargin: -4
                width: Math.max(bentoTopRow.implicitWidth, bentoBetterTxt.implicitWidth)
                height: bentoBetterTxt.implicitHeight
                property bool isRevealed: root.isWordRevealed(3)
                visible: isRevealed
                opacity: isRevealed ? 1.0 : 0.0
                scale: isRevealed ? 1.0 : 1.15
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Text {
                    x: 2.0; y: 2.5
                    text: root.currentWords.length >= 4 ? root.currentWords[3].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 31 : 34
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.celShadow
                }
                Text {
                    id: bentoBetterTxt
                    text: root.currentWords.length >= 4 ? root.currentWords[3].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 31 : 34
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.colSecondary
                }
            }

            // Word 4: "ALONE" (Large anchor)
            Item {
                anchors.left: parent.left
                anchors.top: bentoBetterItem.bottom
                anchors.topMargin: -4
                width: bentoAloneTxt.implicitWidth
                height: bentoAloneTxt.implicitHeight
                property bool isRevealed: root.isWordRevealed(4)
                visible: isRevealed
                opacity: isRevealed ? 1.0 : 0.0
                scale: isRevealed ? 1.0 : 1.15
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Text {
                    x: 2.0; y: 2.5
                    text: root.currentWords.length >= 5 ? root.currentWords[4].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 42
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.celShadow
                }
                Text {
                    id: bentoAloneTxt
                    text: root.currentWords.length >= 5 ? root.currentWords[4].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 42
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.colPrimary
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 7: VERTICAL STACK 3 WORDS (e.g. "BUT / WHEN / YOU")
        // ---------------------------------------------------------------------
        Item {
            id: sceneVertWords
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(vertW1.implicitWidth, Math.max(vertW2.implicitWidth, vertW3.implicitWidth)) + 20
            height: 120
            visible: root.sceneType === "VERTICAL_STACK" && root.currentWords.length >= 3

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4

                Repeater {
                    model: [0, 1, 2]

                    Item {
                        property bool isRevealed: root.isWordRevealed(modelData)
                        visible: isRevealed
                        width: vertTxt.implicitWidth
                        height: vertTxt.implicitHeight
                        opacity: isRevealed ? 1.0 : 0.0
                        scale: isRevealed ? 1.0 : 1.15
                        Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                        Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        Text {
                            x: 2.0; y: 2.5
                            text: root.currentWords.length > modelData ? root.currentWords[modelData].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 29 : 34
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: root.celShadow
                        }
                        Text {
                            id: vertTxt
                            text: root.currentWords.length > modelData ? root.currentWords[modelData].word.toUpperCase() : ""
                            font.family: root.displayFontFamily
                            font.pixelSize: root.isCJK ? 29 : 34
                            font.weight: Font.Black
                            font.capitalization: Font.AllUppercase
                            color: (modelData === 1) ? root.colAccent : root.colPrimary
                        }
                    }
                }
            }
            Text { id: vertW1; visible: false; font.family: root.displayFontFamily; font.pixelSize: root.isCJK ? 29 : 34; font.weight: Font.Black; text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : "" }
            Text { id: vertW2; visible: false; font.family: root.displayFontFamily; font.pixelSize: root.isCJK ? 29 : 34; font.weight: Font.Black; text: root.currentWords.length >= 2 ? root.currentWords[1].word.toUpperCase() : "" }
            Text { id: vertW3; visible: false; font.family: root.displayFontFamily; font.pixelSize: root.isCJK ? 29 : 34; font.weight: Font.Black; text: root.currentWords.length >= 3 ? root.currentWords[2].word.toUpperCase() : "" }
        }

        // ---------------------------------------------------------------------
        // SCENE 8: SINGLE GIANT WORD (e.g. "SAID")
        // ---------------------------------------------------------------------
        Item {
            id: sceneGiantWord
            anchors.centerIn: parent
            width: giantWordTxt.implicitWidth
            height: giantWordTxt.implicitHeight
            visible: root.sceneType === "GIANT_WORD" && root.currentWords.length === 1

            Item {
                anchors.fill: parent
                property bool isRevealed: root.isWordRevealed(0)
                visible: isRevealed
                opacity: isRevealed ? 1.0 : 0.0
                scale: isRevealed ? 1.0 : 1.2
                Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                Text {
                    x: 2.5; y: 3.0
                    text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 44 : 62
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.celShadow
                }
                Text {
                    id: giantWordTxt
                    text: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 44 : 62
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: root.colAccent
                }
            }
        }

        // ---------------------------------------------------------------------
        // SCENE 9: COMPOUND WORD MERGE (e.g. "“HEL” + “LO”" -> "“HELLO”")
        // ---------------------------------------------------------------------
        Item {
            id: sceneCompound
            anchors.verticalCenter: parent.verticalCenter
            height: 60
            visible: root.sceneType === "COMPOUND" && root.currentWords.length === 1

            property string fullWord: root.currentWords.length >= 1 ? root.currentWords[0].word.toUpperCase() : ""
            property int splitPos: Math.max(1, Math.ceil(fullWord.length / 2))
            property string part1: fullWord.substring(0, splitPos)
            property string part2: fullWord.substring(splitPos)

            property bool isP1Revealed: !root.isSentenceTransitioning && (root.lineProgress >= 0.0)
            property bool isP2Revealed: !root.isSentenceTransitioning && (root.lineProgress >= 0.38)

            // Smooth centering push-left
            property real currentWidth: isP2Revealed ? (compTxtP1.implicitWidth + compTxtP2.implicitWidth + 20) : compTxtP1.implicitWidth
            x: Math.max(10, Math.round((root.width - currentWidth) / 2))
            Behavior on x { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // Left quote
                Text {
                    text: "“"
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    color: root.colAccent
                    opacity: sceneCompound.isP1Revealed ? 1.0 : 0.0
                }

                // Part 1 ("HEL")
                Item {
                    width: compTxtP1.implicitWidth
                    height: compTxtP1.implicitHeight
                    visible: sceneCompound.isP1Revealed
                    opacity: sceneCompound.isP1Revealed ? 1.0 : 0.0
                    scale: sceneCompound.isP1Revealed ? 1.0 : 1.15
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        x: 2.0; y: 2.5
                        text: sceneCompound.part1
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        color: root.celShadow
                    }
                    Text {
                        id: compTxtP1
                        text: sceneCompound.part1
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        color: root.colPrimary
                    }
                }

                // Part 2 ("LO")
                Item {
                    width: compTxtP2.implicitWidth
                    height: compTxtP2.implicitHeight
                    visible: sceneCompound.isP2Revealed
                    opacity: sceneCompound.isP2Revealed ? 1.0 : 0.0
                    scale: sceneCompound.isP2Revealed ? 1.0 : 1.2
                    Behavior on opacity { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 130 } }
                    Behavior on scale { enabled: !root.isSentenceTransitioning; NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                    Text {
                        x: 2.0; y: 2.5
                        text: sceneCompound.part2
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        color: root.celShadow
                    }
                    Text {
                        id: compTxtP2
                        text: sceneCompound.part2
                        font.family: root.displayFontFamily
                        font.pixelSize: root.isCJK ? 36 : 44
                        font.weight: Font.Black
                        color: root.colAccent
                    }
                }

                // Right quote
                Text {
                    text: "”"
                    font.family: root.displayFontFamily
                    font.pixelSize: root.isCJK ? 36 : 44
                    font.weight: Font.Black
                    color: root.colAccent
                    opacity: sceneCompound.isP2Revealed ? 1.0 : 0.0
                }
            }
        }
    }
}
