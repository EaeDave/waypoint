import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    property string colorRole: ""

    function colorAt(index) {
        if (colorRole === "" || index < 0 || !model)
            return "";
        const item = model[index];
        return item && item[colorRole] ? String(item[colorRole]) : "";
    }


    implicitHeight: MobileTheme.touchHeight
    leftPadding: 14
    rightPadding: 42

    contentItem: Row {
        spacing: 7

        Rectangle {
            id: selectedColor
            anchors.verticalCenter: parent.verticalCenter
            visible: root.colorAt(root.currentIndex) !== ""
            width: 8
            height: 8
            radius: 4
            color: root.colorAt(root.currentIndex)
        }

        Text {
            width: parent.width - (selectedColor.visible ? 15 : 0)
            text: root.displayText
            color: root.enabled ? MobileTheme.foreground : MobileTheme.disabled
            font.family: MobileTheme.fontFamily
            font.pixelSize: MobileTheme.bodySize
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
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

    delegate: ItemDelegate {
        id: option
        required property int index
        required property var model
        width: ListView.view ? ListView.view.width : root.width
        height: MobileTheme.touchHeight
        highlighted: root.highlightedIndex === option.index

        contentItem: Row {
            spacing: 7

            Rectangle {
                id: optionColor
                anchors.verticalCenter: parent.verticalCenter
                visible: root.colorRole !== ""
                         && option.model[root.colorRole] !== ""
                width: 8
                height: 8
                radius: 4
                color: option.model[root.colorRole] || "transparent"
            }

            Text {
                width: parent.width - (optionColor.visible ? 15 : 0)
                text: root.textRole ? option.model[root.textRole] : option.model.modelData
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.bodySize
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        background: Rectangle {
            color: option.highlighted ? MobileTheme.surfaceSelected : "transparent"
        }
    }

    background: Rectangle {
        radius: MobileTheme.radius
        color: root.down ? MobileTheme.surfacePressed : MobileTheme.surfaceRaised
        border.width: 1
        border.color: root.activeFocus ? MobileTheme.activeBorder : MobileTheme.border
    }
}
