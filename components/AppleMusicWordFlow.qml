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

    // Compensate for 80ms audio buffer latency so words light up on-beat
    readonly property real effectiveTime: root.currentTime + 0.08
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
                    readonly property bool isHeld: modelData.isHeld || (wDur >= 0.75)
                    readonly property bool isPast: root.effectiveTime >= wEnd
                    readonly property bool isSinging: root.effectiveTime >= wStart && root.effectiveTime < wEnd
                    readonly property real wordProgress: isPast ? 1.0 : (isSinging ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur)) : 0.0)

                    // Anticipation within 0.12s before singing
                    readonly property bool isApproaching: !isSinging && !isPast && (root.effectiveTime >= wStart - 0.12)

                    // Apple Music Dynamic Wave Lift & Micro-Scale Breath:
                    // Rises smoothly with a pure sine trajectory (peaks at mid-word, lands smoothly back to 0 at end).
                    // Isolated in Translate so it never displaces or jerks the Flow layout.
                    transform: Translate {
                        y: wordVisual.isSinging ? (-3.0 * Math.sin(Math.PI * wordVisual.wordProgress)) : 0.0
                    }

                    scale: wordVisual.isSinging
                        ? (1.0 + (wordVisual.isHeld ? 0.045 : 0.025) * Math.sin(Math.PI * wordVisual.wordProgress))
                        : 1.0

                    // 1. Phosphor Bloom Glow Layer for Active / Singing Word
                    Text {
                        id: bloomGlowTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                        opacity: wordVisual.isSinging ? (0.65 * Math.sin(Math.PI * wordVisual.wordProgress)) : 0.0
                        visible: opacity > 0.01
                    }

                    // 2. Main Crisp Typography (Pure intact glyphs, zero vertical divider cuts)
                    Text {
                        id: baseWordTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: {
                            if (wordVisual.isPast || wordVisual.isSinging) return "#ffffff";
                            if (wordVisual.isApproaching) return "#9ba1b2";
                            return "#757a88"; // Elegant muted slate gray
                        }
                    }
                }
            }
        }
    }
}
