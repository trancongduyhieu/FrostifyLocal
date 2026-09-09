import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property real progress: 0.0
    property bool isActive: false
    property bool isDead: false
    property string fontFamily: "Instrument Serif"
    property int fontSize: 36

    // Smart Font Fallback: English -> Instrument Serif; Vietnamese -> Noto Serif
    readonly property bool hasVietnamese: /[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i.test(root.text)
    readonly property string activeFontFamily: hasVietnamese ? "Noto Serif" : (root.fontFamily !== "" ? root.fontFamily : "Instrument Serif")

    // Dynamic Adaptive Colors (from wallpaper palette)
    property color colHighlight: "#deb06c"
    property color colActiveText: "#f8fafc"
    property color colDeadText: "#cbd5e1"
    property color colShadowDirectional: "#a6020305"
    property color colShadowAmbient: "#66000000"
    property bool isLightArea: false

    Behavior on colHighlight { ColorAnimation { duration: 350 } }
    Behavior on colActiveText { ColorAnimation { duration: 350 } }
    Behavior on colDeadText { ColorAnimation { duration: 350 } }
    Behavior on colShadowDirectional { ColorAnimation { duration: 350 } }
    Behavior on colShadowAmbient { ColorAnimation { duration: 350 } }

    implicitHeight: root.fontSize + 24
    implicitWidth: wordRow.implicitWidth

    property var wordList: []

    onTextChanged: assembleWords(text)

    function assembleWords(raw) {
        if (!raw || raw.trim() === "") {
            wordList = [];
            return;
        }

        var words = raw.split(/\s+/).filter(function(w) { return w.length > 0; });
        var totalLen = raw.length;
        var list = [];
        var curPos = 0;

        // Natural, subtle staggered baseline offsets (Swing Lynn Frostify reference)
        var offsets = [-2.5, 3.5, -2.0, 2.5, -3.0, 2.0, -1.5, 2.5];

        for (var i = 0; i < words.length; i++) {
            var wStr = words[i];
            var sIdx = raw.indexOf(wStr, curPos);
            if (sIdx === -1) sIdx = curPos;
            var eIdx = sIdx + wStr.length;
            curPos = eIdx;

            var startProg = totalLen > 1 ? (sIdx / totalLen) : 0.0;
            var endProg = totalLen > 1 ? (eIdx / totalLen) : 1.0;

            list.push({
                "word": wStr,
                "idx": i,
                "startProg": startProg,
                "endProg": endProg,
                "yOffset": offsets[i % offsets.length]
            });
        }
        wordList = list;
    }

    // Main Scaled Sentence Row
    Item {
        id: stage
        anchors.verticalCenter: parent.verticalCenter
        width: wordRow.implicitWidth
        height: root.fontSize + 24
        transformOrigin: Item.Left
        scale: Math.min(1.0, root.width > 0 ? (root.width / Math.max(1, wordRow.implicitWidth)) : 1.0)

        Row {
            id: wordRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(root.fontSize * 0.26)

            Repeater {
                id: wordRepeater
                model: root.wordList

                Item {
                    id: wordItem
                    implicitWidth: wordTxt.implicitWidth
                    implicitHeight: root.fontSize + 24
                    y: modelData.yOffset

                    // Timing Trigger
                    property bool shouldBeSung: root.isDead || (root.isActive && root.progress >= modelData.startProg)
                    property bool isSung: false

                    property real wordAlpha: 0.0
                    property real wordScale: 0.88
                    property color currentColor: root.colActiveText

                    onShouldBeSungChanged: {
                        if (root.isDead) {
                            wordAlpha = 1.0;
                            wordScale = 1.0;
                            currentColor = root.colDeadText;
                            isSung = true;
                            return;
                        }

                        if (shouldBeSung && !isSung) {
                            isSung = true;
                            gachaPopAnim.restart();
                        } else if (!shouldBeSung && isSung && root.progress < (modelData.startProg - 0.04)) {
                            isSung = false;
                            wordAlpha = 0.0;
                            wordScale = 0.88;
                            currentColor = root.colActiveText;
                        }
                    }

                    transform: [
                        Scale {
                            origin.x: wordItem.width / 2
                            origin.y: wordItem.height / 2
                            xScale: wordItem.wordScale
                            yScale: wordItem.wordScale
                        }
                    ]

                    opacity: root.isDead ? 1.0 : wordAlpha

                    // Gacha Pop Animation: Base Color Pop -> Smooth Transition to Highlight
                    SequentialAnimation {
                        id: gachaPopAnim

                        // 1. Pop In
                        ParallelAnimation {
                            NumberAnimation { target: wordItem; property: "wordAlpha"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
                            NumberAnimation { target: wordItem; property: "wordScale"; from: 0.88; to: 1.06; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.20 }
                            PropertyAction { target: wordItem; property: "currentColor"; value: root.colActiveText }
                        }

                        // 2. Settle Scale & Transition to Highlight
                        ParallelAnimation {
                            NumberAnimation { target: wordItem; property: "wordScale"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                            ColorAnimation { target: wordItem; property: "currentColor"; to: root.colHighlight; duration: 240; easing.type: Easing.InOutQuad }
                        }
                    }

                    Component.onCompleted: {
                        if (root.isDead) {
                            wordAlpha = 1.0;
                            wordScale = 1.0;
                            currentColor = root.colDeadText;
                            isSung = true;
                        } else if (shouldBeSung) {
                            wordAlpha = 1.0;
                            wordScale = 1.0;
                            currentColor = root.colHighlight;
                            isSung = true;
                        } else {
                            wordAlpha = 0.0;
                            wordScale = 0.88;
                            currentColor = root.colActiveText;
                            isSung = false;
                        }
                    }

                    // Layer 1: Ambient Diffuse Halo (when isLightArea: multi-angle backlight glow)
                    Text {
                        id: shadowHaloTL
                        visible: root.isLightArea
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1.2
                        anchors.verticalCenterOffset: -1.2
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowAmbient
                        style: Text.Normal
                    }
                    Text {
                        id: shadowHaloTR
                        visible: root.isLightArea
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.2
                        anchors.verticalCenterOffset: -1.2
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowAmbient
                        style: Text.Normal
                    }
                    Text {
                        id: shadowHaloBL
                        visible: root.isLightArea
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1.2
                        anchors.verticalCenterOffset: 1.2
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowAmbient
                        style: Text.Normal
                    }
                    Text {
                        id: shadowHaloBR
                        visible: root.isLightArea
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.2
                        anchors.verticalCenterOffset: 1.2
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowAmbient
                        style: Text.Normal
                    }

                    // Layer 1b: Ambient Deep Drop Shadow (when dark area)
                    Text {
                        id: shadowAmbientDark
                        visible: !root.isLightArea
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 3.5
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowAmbient
                        style: Text.Normal
                    }

                    // Layer 2: Directional Sharp Drop Shadow
                    Text {
                        id: shadowDirectional
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.2
                        anchors.verticalCenterOffset: 1.8
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.colShadowDirectional
                        style: Text.Normal
                    }

                    // Layer 3: Main Pristine Word (Razor-sharp Instrument Serif typography)
                    Text {
                        id: wordTxt
                        anchors.centerIn: parent
                        text: modelData.word
                        font.family: root.activeFontFamily
                        font.pixelSize: root.fontSize
                        font.bold: false
                        color: root.isDead ? root.colDeadText : (gachaPopAnim.running ? wordItem.currentColor : (wordItem.isSung ? root.colHighlight : root.colActiveText))
                        style: Text.Normal
                    }
                }
            }
        }
    }
}
