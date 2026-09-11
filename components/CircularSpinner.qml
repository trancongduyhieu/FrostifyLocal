import QtQuick

Item {
    id: root
    property real size: 18
    property real strokeWidth: 2.2
    property color color: "#000000"
    property bool running: true

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var center = width / 2;
            var radius = center - root.strokeWidth;
            if (radius <= 0) return;

            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.color;

            // 270 degree arc matching SimpMusic / Material 3 circular progress indicator
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, 1.5 * Math.PI, false);
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onColorChanged() { canvas.requestPaint(); }
            function onStrokeWidthChanged() { canvas.requestPaint(); }
        }
    }

    RotationAnimation {
        target: root
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
        running: root.running && root.visible
    }
}
