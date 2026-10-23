import QtQuick

// Stroke icons drawn on a 24-unit grid so they scale with the item.
Item {
    id: root

    property string name: "calendar"
    property color color: WaypointTheme.foreground
    property real strokeWidth: Math.max(1.5, Math.min(width, height) * 0.085)

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
            const unit = size / 24;
            const originX = (width - size) / 2;
            const originY = (height - size) / 2;
            const px = value => originX + value * unit;
            const py = value => originY + value * unit;
            const path = points => {
                context.beginPath();
                context.moveTo(px(points[0]), py(points[1]));
                for (let index = 2; index < points.length; index += 2)
                    context.lineTo(px(points[index]), py(points[index + 1]));
                context.stroke();
            };
            const circle = (x, y, radius, fill) => {
                context.beginPath();
                context.arc(px(x), py(y), radius * unit, 0, Math.PI * 2);
                if (fill)
                    context.fill();
                else
                    context.stroke();
            };
            const roundRect = (x, y, w, h, r) => {
                context.beginPath();
                context.roundedRect(px(x), py(y), w * unit, h * unit, r * unit, r * unit);
                context.stroke();
            };

            context.clearRect(0, 0, width, height);
            context.strokeStyle = root.color;
            context.fillStyle = root.color;
            context.lineWidth = root.strokeWidth;
            context.lineCap = "round";
            context.lineJoin = "round";

            switch (root.name) {
            case "tasks":
                circle(12, 12, 8.5, false);
                path([8.2, 12.2, 10.9, 14.8, 15.8, 9.4]);
                return;
            case "list":
                for (let row = 0; row < 3; ++row) {
                    circle(5.5, 7 + row * 5, 1, true);
                    path([9.5, 7 + row * 5, 19, 7 + row * 5]);
                }
                return;
            case "check":
                path([5, 12.5, 10, 17.5, 19, 7]);
                return;
            case "chevron-down":
                path([6.5, 9.5, 12, 15, 17.5, 9.5]);
                return;
            case "chevron-right":
                path([9.5, 6.5, 15, 12, 9.5, 17.5]);
                return;
            case "chevron-left":
                path([14.5, 6.5, 9, 12, 14.5, 17.5]);
                return;
            case "plus":
                path([12, 5, 12, 19]);
                path([5, 12, 19, 12]);
                return;
            case "search":
                circle(10.5, 10.5, 6, false);
                path([15, 15, 19.5, 19.5]);
                return;
            case "clock":
                circle(12, 12, 8.5, false);
                path([12, 7.5, 12, 12, 15, 13.8]);
                return;
            case "bell":
                context.beginPath();
                context.moveTo(px(4.5), py(17));
                context.lineTo(px(6.5), py(14.5));
                context.lineTo(px(6.5), py(10.5));
                context.arc(px(12), py(10.5), 5.5 * unit, Math.PI, 0, false);
                context.lineTo(px(17.5), py(14.5));
                context.lineTo(px(19.5), py(17));
                context.closePath();
                context.stroke();
                path([10, 20, 14, 20]);
                return;
            case "close":
                path([7, 7, 17, 17]);
                path([17, 7, 7, 17]);
                return;
            case "more":
                for (let column = 0; column < 3; ++column)
                    circle(6 + column * 6, 12, 1.4, true);
                return;
            case "settings":
                for (let row = 0; row < 3; ++row) {
                    const knob = [15, 8, 13][row];
                    const rowY = 6.5 + row * 5.5;
                    path([4.5, rowY, knob - 2.2, rowY]);
                    path([knob + 2.2, rowY, 19.5, rowY]);
                    circle(knob, rowY, 2.2, false);
                }
                return;
            case "sidebar":
                roundRect(4, 5, 16, 14, 2.5);
                path([9.5, 5, 9.5, 19]);
                return;
            case "inbox":
                roundRect(4, 5, 16, 14, 2.5);
                path([4, 13, 8.5, 13, 10, 15.5, 14, 15.5, 15.5, 13, 20, 13]);
                return;
            case "edit":
                path([5, 19, 5.8, 15.2, 15.5, 5.5, 18.5, 8.5, 8.8, 18.2, 5, 19]);
                path([13.5, 7.5, 16.5, 10.5]);
                return;
            case "trash":
                path([4.5, 7, 19.5, 7]);
                path([9.5, 7, 9.5, 4.5, 14.5, 4.5, 14.5, 7]);
                path([6.5, 7, 7.5, 19.5, 16.5, 19.5, 17.5, 7]);
                path([10.2, 11, 10.2, 16]);
                path([13.8, 11, 13.8, 16]);
                return;
            default:
                roundRect(4, 5.5, 16, 14.5, 2.5);
                path([4, 10, 20, 10]);
                path([8.5, 3.5, 8.5, 7]);
                path([15.5, 3.5, 15.5, 7]);
                for (let row = 0; row < 2; ++row) {
                    for (let column = 0; column < 3; ++column)
                        circle(8 + column * 4, 13.5 + row * 3.5, 0.9, true);
                }
            }
        }
    }
}
