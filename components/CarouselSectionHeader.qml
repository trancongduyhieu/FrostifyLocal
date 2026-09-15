import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: root
    Layout.fillWidth: true

    property string title: ""
    property int titlePixelSize: 22
    property color titleColor: "#ffffff"
    property var targetFlickable: null
    property real stepSize: 480
    property int animationDuration: 280

    Text {
        Layout.fillWidth: true
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: root.titlePixelSize
        font.bold: true
        color: root.titleColor
    }

    NumberAnimation {
        id: scrollAnim
        target: root.targetFlickable
        property: "contentX"
        duration: root.animationDuration
        easing.type: Easing.OutCubic
    }

    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

    // Prev Button (<)
    NavArrowButton {
        direction: "left"
        accentColor: root.accentColor
        btnSize: 32
        iconSize: 14
        canScroll: root.targetFlickable ? (root.targetFlickable.contentX > 10) : false
        visible: root.targetFlickable ? (root.targetFlickable.contentWidth > root.targetFlickable.width) : false
        onClicked: {
            if (!root.targetFlickable) return;
            var targetX = Math.max(0, root.targetFlickable.contentX - root.stepSize);
            scrollAnim.stop();
            scrollAnim.target = root.targetFlickable;
            scrollAnim.to = targetX;
            scrollAnim.restart();
        }
    }

    // Next Button (>)
    NavArrowButton {
        direction: "right"
        accentColor: root.accentColor
        btnSize: 32
        iconSize: 14
        canScroll: root.targetFlickable ? (root.targetFlickable.contentX < (root.targetFlickable.contentWidth - root.targetFlickable.width - 10)) : false
        visible: root.targetFlickable ? (root.targetFlickable.contentWidth > root.targetFlickable.width) : false
        onClicked: {
            if (!root.targetFlickable) return;
            var maxX = Math.max(0, root.targetFlickable.contentWidth - root.targetFlickable.width);
            var targetX = Math.min(maxX, root.targetFlickable.contentX + root.stepSize);
            scrollAnim.stop();
            scrollAnim.target = root.targetFlickable;
            scrollAnim.to = targetX;
            scrollAnim.restart();
        }
    }
}
