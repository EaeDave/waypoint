import QtQuick

Item {
    id: root

    property string name: "today"
    property color color: MobileTheme.foreground
    property real strokeWidth: Math.max(1.5, Math.min(width, height) * 0.09)

    implicitWidth: 20
    implicitHeight: 20

    onNameChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onStrokeWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            const size = Math.min(width, height);
            const x = (width - size) / 2;
            const y = (height - size) / 2;

            context.clearRect(0, 0, width, height);
            context.strokeStyle = root.color;
            context.fillStyle = root.color;
            context.lineWidth = root.strokeWidth;
            context.lineCap = "round";
            context.lineJoin = "round";

            if (root.name === "clock") {
                context.beginPath();
                context.arc(x + size * 0.5, y + size * 0.5, size * 0.34, 0, Math.PI * 2);
                context.moveTo(x + size * 0.5, y + size * 0.5);
                context.lineTo(x + size * 0.5, y + size * 0.29);
                context.moveTo(x + size * 0.5, y + size * 0.5);
                context.lineTo(x + size * 0.66, y + size * 0.59);
                context.stroke();
                return;
            }

            if (root.name === "calendar") {
                context.strokeRect(x + size * 0.16, y + size * 0.23, size * 0.68, size * 0.61);
                context.beginPath();
                context.moveTo(x + size * 0.16, y + size * 0.41);
                context.lineTo(x + size * 0.84, y + size * 0.41);
                context.moveTo(x + size * 0.33, y + size * 0.14);
                context.lineTo(x + size * 0.33, y + size * 0.31);
                context.moveTo(x + size * 0.67, y + size * 0.14);
                context.lineTo(x + size * 0.67, y + size * 0.31);
                context.stroke();
                return;
            }

            if (root.name === "habits") {
                context.beginPath();
                context.arc(x + size * 0.5, y + size * 0.5, size * 0.32, -Math.PI * 0.35, Math.PI * 1.15);
                context.stroke();
                context.beginPath();
                context.moveTo(x + size * 0.73, y + size * 0.26);
                context.lineTo(x + size * 0.82, y + size * 0.2);
                context.lineTo(x + size * 0.8, y + size * 0.32);
                context.stroke();
                return;
            }
            if (root.name === "undo") {
                context.beginPath();
                context.arc(x + size * 0.52, y + size * 0.52, size * 0.29, Math.PI * 1.16, Math.PI * 2.95);
                context.stroke();
                context.beginPath();
                context.moveTo(x + size * 0.25, y + size * 0.38);
                context.lineTo(x + size * 0.25, y + size * 0.2);
                context.moveTo(x + size * 0.25, y + size * 0.38);
                context.lineTo(x + size * 0.43, y + size * 0.38);
                context.stroke();
                return;
            }

            if (root.name === "settings") {
                context.beginPath();
                context.arc(x + size * 0.5, y + size * 0.5, size * 0.18, 0, Math.PI * 2);
                context.stroke();
                context.beginPath();
                for (let index = 0; index < 8; ++index) {
                    const angle = index * Math.PI / 4;
                    context.moveTo(x + size * (0.5 + Math.cos(angle) * 0.29), y + size * (0.5 + Math.sin(angle) * 0.29));
                    context.lineTo(x + size * (0.5 + Math.cos(angle) * 0.4), y + size * (0.5 + Math.sin(angle) * 0.4));
                }
                context.stroke();
                return;
            }

            context.beginPath();
            context.arc(x + size * 0.5, y + size * 0.5, size * 0.34, 0, Math.PI * 2);
            context.stroke();
            context.beginPath();
            context.moveTo(x + size * 0.3, y + size * 0.51);
            context.lineTo(x + size * 0.45, y + size * 0.65);
            context.lineTo(x + size * 0.72, y + size * 0.34);
            context.stroke();
        }
    }
}
