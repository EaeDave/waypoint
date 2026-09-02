import QtQuick
import QtQuick.Controls

ComboBox {
    id: root

    implicitHeight: MobileTheme.touchHeight
    leftPadding: 14
    rightPadding: 42

    contentItem: Text {
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        text: root.displayText
        color: root.enabled ? MobileTheme.foreground : MobileTheme.disabled
        font.family: MobileTheme.fontFamily
        font.pixelSize: MobileTheme.bodySize
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        width: 16
        height: 16
        x: root.width - width - 14
        y: (root.height - height) / 2

        Canvas {
            id: indicatorCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.strokeStyle = root.enabled ? MobileTheme.subdued : MobileTheme.disabled;
                context.lineWidth = 1.7;
                context.lineCap = "round";
                context.lineJoin = "round";
                context.beginPath();
                context.moveTo(width * 0.22, height * 0.38);
                context.lineTo(width * 0.5, height * 0.66);
                context.lineTo(width * 0.78, height * 0.38);
                context.stroke();
            }
        }
    }

    background: Rectangle {
        radius: MobileTheme.radius
        color: root.down ? MobileTheme.surfacePressed : MobileTheme.surfaceRaised
        border.width: 1
        border.color: root.activeFocus ? MobileTheme.activeBorder : MobileTheme.border
    }
}
