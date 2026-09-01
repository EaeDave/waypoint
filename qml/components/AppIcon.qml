import QtQuick

Item {
    id: root

    property string name: "calendar"
    property color color: "#f6f4f8"
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

            if (root.name === "tasks") {
                context.beginPath();
                context.arc(x + size * 0.5, y + size * 0.5, size * 0.34, 0, Math.PI * 2);
                context.stroke();

                context.beginPath();
                context.moveTo(x + size * 0.31, y + size * 0.51);
                context.lineTo(x + size * 0.45, y + size * 0.64);
                context.lineTo(x + size * 0.7, y + size * 0.36);
                context.stroke();
                return;
            }

            context.beginPath();
            context.rect(x + size * 0.16, y + size * 0.23, size * 0.68, size * 0.61);
            context.stroke();

            context.beginPath();
            context.moveTo(x + size * 0.16, y + size * 0.41);
            context.lineTo(x + size * 0.84, y + size * 0.41);
            context.moveTo(x + size * 0.33, y + size * 0.14);
            context.lineTo(x + size * 0.33, y + size * 0.31);
            context.moveTo(x + size * 0.67, y + size * 0.14);
            context.lineTo(x + size * 0.67, y + size * 0.31);
            context.stroke();

            const dotSize = Math.max(1.5, size * 0.075);
            for (let row = 0; row < 2; ++row) {
                for (let column = 0; column < 3; ++column) {
                    context.beginPath();
                    context.arc(x + size * (0.31 + column * 0.19), y + size * (0.56 + row * 0.16), dotSize / 2, 0, Math.PI * 2);
                    context.fill();
                }
            }
        }
    }
}
