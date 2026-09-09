import QtQuick

Canvas {
    id: canvas
    anchors.fill: parent
    opacity: 0.55

    property var particles: []
    property int numParticles: 35

    Component.onCompleted: {
        for (var i = 0; i < numParticles; i++) {
            particles.push({
                x: Math.random() * width,
                y: Math.random() * height,
                radius: 2 + Math.random() * 4,
                vx: (Math.random() - 0.5) * 0.4,
                vy: -0.2 - Math.random() * 0.5,
                alpha: 0.15 + Math.random() * 0.45,
                hue: Math.random() > 0.5 ? 270 : 210
            });
        }
    }

    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            for (var i = 0; i < canvas.particles.length; i++) {
                var p = canvas.particles[i];
                p.x += p.vx;
                p.y += p.vy;

                if (p.y < -10) {
                    p.y = canvas.height + 10;
                    p.x = Math.random() * canvas.width;
                }
                if (p.x < -10) p.x = canvas.width + 10;
                if (p.x > canvas.width + 10) p.x = -10;
            }
            canvas.requestPaint();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        for (var i = 0; i < particles.length; i++) {
            var p = particles[i];
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
            ctx.fillStyle = "hsla(" + p.hue + ", 85%, 75%, " + p.alpha + ")";
            ctx.shadowBlur = 12;
            ctx.shadowColor = "hsla(" + p.hue + ", 85%, 75%, 0.8)";
            ctx.fill();
        }
    }
}
