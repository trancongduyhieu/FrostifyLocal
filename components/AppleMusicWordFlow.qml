import QtQuick
import "."

Item {
    id: root

    property var words: []
    property real currentTime: 0.0
    property bool isLineActive: false
    property int fontSize: 28
    property string fontFamily: Theme.fontFamily
    property int fontWeight: Font.Bold
    property color accentColor: Theme.accent
    property int wordSpacing: 8

    readonly property real effectiveTime: root.currentTime
    readonly property var effectiveWords: root.words || []

    implicitWidth: parent ? parent.width : 300
    implicitHeight: wordsFlow.implicitHeight + 8

    Flow {
        id: wordsFlow
        y: 4
        width: root.width
        spacing: root.wordSpacing

        Repeater {
            model: root.effectiveWords

            delegate: Item {
                id: wordContainer
                width: baseWordTxt.implicitWidth
                height: baseWordTxt.implicitHeight

                Item {
                    id: wordVisual
                    anchors.fill: parent
                    transformOrigin: Item.Center

                    readonly property real wStart: modelData.start
                    readonly property real wEnd: modelData.end
                    readonly property real wDur: Math.max(0.08, modelData.duration || (wEnd - wStart))
                    readonly property bool isHeld: modelData.isHeld || (wDur >= 0.85)
                    readonly property bool isPast: root.effectiveTime >= wEnd
                    readonly property bool isSinging: root.effectiveTime >= wStart && root.effectiveTime < wEnd
                    readonly property real wordProgress: isPast ? 1.0 : (isSinging ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur)) : 0.0)

                    // AMLL Emphasize micro-scale breath:
                    // Words remain firmly anchored on the horizontal baseline (y = 0.0px).
                    // During active singing, word gently expands up to 1.025x at mid-syllable and settles back smoothly.
                    scale: isSinging ? (1.0 + (isHeld ? 0.025 : 0.015) * Math.sin(Math.PI * wordProgress)) : 1.0

                    // 1. AMLL Dimmed Base Layer: Muted slate-gray text underneath
                    Text {
                        id: baseWordTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: "#757a88"
                    }

                    // 2. AMLL Phosphor Bloom Layer for Held Notes: Soft luminous crest
                    Text {
                        id: bloomGlowTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: Qt.rgba(1.0, 1.0, 1.0, 0.4)
                        opacity: (wordVisual.isSinging && wordVisual.isHeld) ? Math.sin(Math.PI * wordVisual.wordProgress) * 0.75 : 0.0
                        visible: opacity > 0.01
                    }

                    // 3. AMLL Bright Layer with Smooth Horizontal Sweep:
                    // Reveals pure white text in continuous pixel increments as syllables are sung
                    Item {
                        id: brightClip
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.round(parent.width * wordVisual.wordProgress)
                        clip: true
                        visible: width > 0

                        Text {
                            id: brightWordTxt
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text || ""
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.weight: root.fontWeight
                            color: "#ffffff"
                        }
                    }

                    // 4. AMLL Soft Leading Edge Feather: Subtle light beam at the sweeping wavefront
                    Rectangle {
                        id: sweepFeather
                        anchors.right: brightClip.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.min(10, brightClip.width)
                        visible: wordVisual.isSinging && brightClip.width > 2 && brightClip.width < parent.width
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.35) }
                        }
                    }
                }
            }
        }
    }
}
