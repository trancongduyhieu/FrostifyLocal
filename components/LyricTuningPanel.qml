import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "."

Item {
    id: root

    width: isCollapsed ? 120 : 340
    height: isCollapsed ? 42 : Math.min(parent ? (parent.height - 120) : 660, 680)

    property bool isCollapsed: false

    // Dark Glass Panel
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.06, 0.07, 0.10, 0.94)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
        border.width: 1
        clip: true

        // Header / Toggle Bar
        Item {
            id: headerBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 42
            z: 20

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: LyricTuningState.testMode ? "#22c55e" : Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.isCollapsed ? "Bảng Chỉnh" : "Bộ Chỉnh Lyric Sóng"
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                color: collapseHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: root.isCollapsed ? "+" : "−"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                HoverHandler { id: collapseHover }
                TapHandler {
                    onTapped: root.isCollapsed = !root.isCollapsed
                }
            }
        }

        // Scrollable Body
        Flickable {
            id: scrollBody
            visible: !root.isCollapsed
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerBar.bottom
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: contentCol.implicitHeight + 24
            clip: true

            Column {
                id: contentCol
                width: parent.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                // Quick Action Bar
                Row {
                    width: parent.width
                    spacing: 8

                    // Test Mode Toggle
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 32
                        radius: 8
                        color: LyricTuningState.testMode ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: LyricTuningState.testMode ? "Test Mode: ON" : "Test Mode: OFF"
                            color: LyricTuningState.testMode ? "#ffffff" : "#cccccc"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        HoverHandler { id: testBtnHover }
                        TapHandler {
                            onTapped: {
                                LyricTuningState.testMode = !LyricTuningState.testMode;
                                if (LyricTuningState.testMode) LyricTuningState.demoTime = 0.0;
                            }
                        }
                    }

                    // Reset Defaults
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 32
                        radius: 8
                        color: resetHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Về Mặc Định"
                            color: "#cccccc"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        HoverHandler { id: resetHover }
                        TapHandler {
                            onTapped: LyricTuningState.resetDefaults()
                        }
                    }
                }

                // =============================================================
                // PHẦN 1: CHỈNH CẢ CÂU (SENTENCE LEVEL)
                // =============================================================
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "📌 1. CHỈNH CẢ CÂU (SENTENCE LEVEL)"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                CustomSlider {
                    title: "Tọa Độ Câu Khi Hát (sentenceActiveY)"
                    valueText: (LyricTuningState.sentenceActiveY >= 0 ? "+" : "") + LyricTuningState.sentenceActiveY.toFixed(1) + " px"
                    minVal: -10.0
                    maxVal: 10.0
                    curVal: LyricTuningState.sentenceActiveY
                    onValChanged: function(v) { LyricTuningState.sentenceActiveY = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Tọa Độ Câu Khi Nghỉ (sentenceRestY)"
                    valueText: (LyricTuningState.sentenceRestY >= 0 ? "+" : "") + LyricTuningState.sentenceRestY.toFixed(1) + " px"
                    minVal: -10.0
                    maxVal: 10.0
                    curVal: LyricTuningState.sentenceRestY
                    onValChanged: function(v) { LyricTuningState.sentenceRestY = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Phóng To Câu Khi Hát (sentenceActiveScale)"
                    valueText: LyricTuningState.sentenceActiveScale.toFixed(2) + "x"
                    minVal: 0.90
                    maxVal: 1.10
                    curVal: LyricTuningState.sentenceActiveScale
                    onValChanged: function(v) { LyricTuningState.sentenceActiveScale = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Thời Gian Chuyển Câu (sentenceSmoothMs)"
                    valueText: LyricTuningState.sentenceSmoothMs + " ms"
                    minVal: 50
                    maxVal: 500
                    curVal: LyricTuningState.sentenceSmoothMs
                    onValChanged: function(v) { LyricTuningState.sentenceSmoothMs = Math.round(v); LyricTuningState.saveSettings(); }
                }

                // =============================================================
                // PHẦN 2: CHỈNH TỪNG TỪ (WORD-BY-WORD RIPPLE)
                // =============================================================
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🌊 2. CHỈNH TỪNG TỪ (WORD WAVE)"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                CustomSlider {
                    title: "Đỉnh Nhấc Của Từ (liftY)"
                    valueText: LyricTuningState.peakLiftY.toFixed(1) + " px"
                    minVal: 0.0
                    maxVal: 8.0
                    curVal: LyricTuningState.peakLiftY
                    onValChanged: function(v) { LyricTuningState.peakLiftY = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Chờ Hát Của Từ (restY)"
                    valueText: "+" + LyricTuningState.restY.toFixed(1) + " px"
                    minVal: 0.0
                    maxVal: 8.0
                    curVal: LyricTuningState.restY
                    onValChanged: function(v) { LyricTuningState.restY = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Phóng To Từ Khi Hát (scale)"
                    valueText: LyricTuningState.peakScale.toFixed(3) + "x"
                    minVal: 1.00
                    maxVal: 1.12
                    curVal: LyricTuningState.peakScale
                    onValChanged: function(v) { LyricTuningState.peakScale = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Độ Nhọn Đỉnh Sóng (exponent)"
                    valueText: LyricTuningState.curveExponent.toFixed(2)
                    minVal: 0.5
                    maxVal: 3.0
                    curVal: LyricTuningState.curveExponent
                    onValChanged: function(v) { LyricTuningState.curveExponent = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Khoảng Cách Từ (spacing)"
                    valueText: LyricTuningState.wordSpacing + " px"
                    minVal: 2
                    maxVal: 20
                    curVal: LyricTuningState.wordSpacing
                    onValChanged: function(v) { LyricTuningState.wordSpacing = Math.round(v); LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Đón Đầu Sóng Trước (leadTime)"
                    valueText: LyricTuningState.leadTime.toFixed(2) + " s"
                    minVal: 0.04
                    maxVal: 0.35
                    curVal: LyricTuningState.leadTime
                    onValChanged: function(v) { LyricTuningState.leadTime = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Độ Đàn Hồi Lò Xo (wordSmoothMs)"
                    valueText: LyricTuningState.wordSmoothMs + " ms"
                    minVal: 0
                    maxVal: 300
                    curVal: LyricTuningState.wordSmoothMs
                    onValChanged: function(v) { LyricTuningState.wordSmoothMs = Math.round(v); LyricTuningState.saveSettings(); }
                }

                // Toggle: Chuẩn hóa nhịp từ câu ngắn / dài
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        color: LyricTuningState.autoScaleWithDur ? Theme.accent : Qt.rgba(1, 1, 1, 0.1)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: LyricTuningState.autoScaleWithDur ? "✓" : ""
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                        TapHandler {
                            onTapped: {
                                LyricTuningState.autoScaleWithDur = !LyricTuningState.autoScaleWithDur;
                                LyricTuningState.saveSettings();
                            }
                        }
                    }
                    Text {
                        text: "Đồng bộ nhịp từ (chống câu ngắn bay cao, câu dài yếu)"
                        color: "#cccccc"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // =============================================================
                // PHẦN 3: PHÁT QUANG (GLOW)
                // =============================================================
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✨ 3. HÀO QUANG PHÁT SÁNG (GLOW)"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                CustomSlider {
                    title: "Độ Nhòe Vầng Sáng (glowBlur)"
                    valueText: LyricTuningState.glowBlur.toFixed(2)
                    minVal: 0.10
                    maxVal: 1.00
                    curVal: LyricTuningState.glowBlur
                    onValChanged: function(v) { LyricTuningState.glowBlur = v; LyricTuningState.saveSettings(); }
                }

                CustomSlider {
                    title: "Độ Sáng Hào Quang (glowOpacity)"
                    valueText: LyricTuningState.glowOpacity.toFixed(2)
                    minVal: 0.00
                    maxVal: 1.00
                    curVal: LyricTuningState.glowOpacity
                    onValChanged: function(v) { LyricTuningState.glowOpacity = v; LyricTuningState.saveSettings(); }
                }

                // =============================================================
                // PHẦN 4: TEST CÂU MẪU & EXPORT
                // =============================================================
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🧪 4. TEST CÂU MẪU & XUẤT THÔNG SỐ"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                // Toggle Câu Ngắn vs Câu Dài
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: 6
                        color: !LyricTuningState.useShortDemo ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Câu Dài (Wake up...)"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        TapHandler {
                            onTapped: {
                                LyricTuningState.useShortDemo = false;
                                LyricTuningState.demoTime = 0.0;
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: 6
                        color: LyricTuningState.useShortDemo ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Câu Ngắn (And, oh,)"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        TapHandler {
                            onTapped: {
                                LyricTuningState.useShortDemo = true;
                                LyricTuningState.demoTime = 0.0;
                            }
                        }
                    }
                }

                // Demo Timeline Slider
                CustomSlider {
                    title: "Tua Thời Gian Demo (" + (LyricTuningState.isPlayingDemo ? "Đang chạy" : "Tạm dừng") + ")"
                    valueText: LyricTuningState.demoTime.toFixed(2) + "s / " + LyricTuningState.demoMaxDuration.toFixed(1) + "s"
                    minVal: 0.0
                    maxVal: LyricTuningState.demoMaxDuration
                    curVal: LyricTuningState.demoTime
                    onValChanged: function(v) {
                        LyricTuningState.demoTime = v;
                    }
                }

                // Export Output Code Block
                Rectangle {
                    width: parent.width
                    height: 110
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    TextEdit {
                        id: exportBox
                        anchors.fill: parent
                        anchors.margins: 6
                        readOnly: true
                        selectByMouse: true
                        text: "liftY: " + LyricTuningState.peakLiftY.toFixed(1) + ", restY: " + LyricTuningState.restY.toFixed(1) +
                              ", scale: " + LyricTuningState.peakScale.toFixed(2) + ", glowBlur: " + LyricTuningState.glowBlur.toFixed(2) +
                              ", glowOpacity: " + LyricTuningState.glowOpacity.toFixed(2) + ", spacing: " + LyricTuningState.wordSpacing +
                              ", exponent: " + LyricTuningState.curveExponent.toFixed(1) + "\nsentenceActiveY: " + LyricTuningState.sentenceActiveY.toFixed(1) +
                              ", sentenceRestY: " + LyricTuningState.sentenceRestY.toFixed(1) + ", sentenceScale: " + LyricTuningState.sentenceActiveScale.toFixed(2)
                        font.family: "monospace"
                        font.pixelSize: 10
                        color: "#a3e635"
                    }
                }

                Text {
                    text: "💡 Tinh chỉnh xong, chỉ cần copy các số trên gửi tôi!"
                    color: "#71717a"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // Component CustomSlider
    component CustomSlider: Column {
        id: sRoot
        width: parent.width
        spacing: 3

        property string title: ""
        property string valueText: ""
        property real minVal: 0.0
        property real maxVal: 1.0
        property real curVal: 0.0
        signal valChanged(real newVal)

        Row {
            width: parent.width
            Text {
                width: parent.width - 80
                text: sRoot.title
                color: "#b0b4c0"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: 80
                horizontalAlignment: Text.AlignRight
                text: sRoot.valueText
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        Rectangle {
            width: parent.width
            height: 18
            radius: 9
            color: Qt.rgba(1, 1, 1, 0.07)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(18, Math.min(parent.width, ((sRoot.curVal - sRoot.minVal) / Math.max(0.001, (sRoot.maxVal - sRoot.minVal))) * parent.width))
                radius: 9
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function updatePos(mouse) {
                    var frac = Math.max(0.0, Math.min(1.0, mouse.x / width));
                    var calculated = sRoot.minVal + frac * (sRoot.maxVal - sRoot.minVal);
                    sRoot.valChanged(calculated);
                }
                onPressed: function(mouse) { updatePos(mouse); }
                onPositionChanged: function(mouse) { if (pressed) updatePos(mouse); }
            }
        }
    }
}
