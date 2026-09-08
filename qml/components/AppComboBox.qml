pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    property string colorRole: ""

    function colorAt(index) {
        if (colorRole === "" || index < 0 || !model)
            return "";
        const item = model[index];
        return item && item[colorRole] ? String(item[colorRole]) : "";
    }


    implicitHeight: WaypointTheme.controlHeight
    leftPadding: 10
    rightPadding: 28
    topPadding: 6
    bottomPadding: 6
    hoverEnabled: true

    contentItem: Row {
        spacing: 7

        Rectangle {
            id: selectedColorDot
            anchors.verticalCenter: parent.verticalCenter
            visible: control.colorAt(control.currentIndex) !== ""
            width: 8
            height: 8
            radius: 4
            color: control.colorAt(control.currentIndex)
        }

        Text {
            width: parent.width - (selectedColorDot.visible ? 15 : 0)
            text: control.displayText
            color: control.enabled ? WaypointTheme.foreground : WaypointTheme.disabledText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySize
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    indicator: Text {
        x: control.width - width - 10
        y: control.topPadding
        height: control.availableHeight
        text: "⌄"
        color: control.enabled ? WaypointTheme.subduedText : WaypointTheme.disabledText
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.subtitleSize
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.down || control.popup.visible ? WaypointTheme.controlSelectedFill
             : control.hovered ? WaypointTheme.controlHoverFill
             : WaypointTheme.controlFill
        border.width: 1
        border.color: control.activeFocus || control.popup.visible ? WaypointTheme.activeBorder
                    : control.hovered ? WaypointTheme.controlHoverBorder
                    : WaypointTheme.controlBorder
    }

    delegate: ItemDelegate {
        id: option
        required property int index
        required property var model
        width: ListView.view ? ListView.view.width : control.width
        height: WaypointTheme.controlHeight
        highlighted: control.highlightedIndex === option.index

        contentItem: Row {
            spacing: 7

            Rectangle {
                id: optionColorDot
                anchors.verticalCenter: parent.verticalCenter
                visible: control.colorRole !== ""
                         && option.model[control.colorRole] !== ""
                width: 8
                height: 8
                radius: 4
                color: option.model[control.colorRole] || "transparent"
            }

            Text {
                width: parent.width - (optionColorDot.visible ? 15 : 0)
                text: control.textRole ? option.model[control.textRole] : option.model.modelData
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
        background: Rectangle {
            color: option.highlighted ? WaypointTheme.controlSelectedFill : "transparent"
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            color: WaypointTheme.background
            radius: WaypointTheme.radius
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }
    }
}
