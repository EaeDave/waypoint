pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    readonly property var lists: {
        const values = [{ id: "", name: "Entrada", color: String(WaypointTheme.subduedText) }];
        for (const category of controller.taskCategories) {
            if (category.id !== "")
                values.push(category);
        }
        return values;
    }
    readonly property string selectionDescription: {
        if (!controller.calendarListFilterActive)
            return "Todas";
        const names = [];
        for (const id of controller.calendarListIds)
            names.push(listName(id));
        return names.length === 0 ? "nenhuma lista selecionada" : names.join(", ");
    }
    readonly property string label: !controller.calendarListFilterActive ? "Listas: Todas"
        : controller.calendarListIds.length === 1 ? "Listas: " + listName(controller.calendarListIds[0])
        : "Listas: " + controller.calendarListIds.length

    implicitWidth: controls.implicitWidth
    implicitHeight: controls.implicitHeight

    function listName(id) {
        for (const list of lists) {
            if (list.id === id)
                return list.name;
        }
        return "Lista indisponível";
    }

    function toggleList(id) {
        const selected = [];
        if (controller.calendarListFilterActive) {
            for (const selectedId of controller.calendarListIds)
                selected.push(selectedId);
        } else {
            for (const list of lists)
                selected.push(list.id);
        }
        const index = selected.indexOf(id);
        if (index < 0)
            selected.push(id);
        else
            selected.splice(index, 1);
        controller.setCalendarListFilter(selected);
    }

    RowLayout {
        id: controls
        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.min(root.width, implicitWidth)
        spacing: 4

        AppButton {
            id: trigger
            objectName: "calendarListFilterTrigger"
            Layout.maximumWidth: Math.max(72, root.width - (reset.visible ? reset.width + controls.spacing : 0))
            implicitHeight: 28
            text: root.label
            selected: root.controller.calendarListFilterActive
            Accessible.name: root.label + ". Filtrar listas do calendário"
            ToolTip.visible: hovered
            ToolTip.text: root.selectionDescription
            onClicked: picker.open()
        }

        AppButton {
            id: reset
            objectName: "calendarListFilterReset"
            visible: root.controller.calendarListFilterActive
            implicitHeight: 28
            square: true
            text: "×"
            Accessible.name: "Mostrar todas as listas do calendário"
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            onClicked: root.controller.clearCalendarListFilter()
        }
    }

    Popup {
        id: picker
        objectName: "calendarListFilterPopup"
        parent: Overlay.overlay
        width: Math.min(380, parent.width - 24)
        height: Math.min(contentColumn.implicitHeight + padding * 2, parent.height - 24, 440)
        padding: WaypointTheme.popupPadding
        modal: true
        dim: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            const position = trigger.mapToItem(parent, 0, trigger.height + 6);
            x = Math.max(12, Math.min(position.x, parent.width - width - 12));
            y = Math.max(12, Math.min(position.y, parent.height - height - 12));
        }
        onOpened: showAll.forceActiveFocus()
        onClosed: trigger.forceActiveFocus()

        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ScrollView {
            id: scroll
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: contentColumn
                width: scroll.availableWidth
                spacing: 8

                AppButton {
                    id: showAll
                    objectName: "calendarListFilterShowAll"
                    Layout.fillWidth: true
                    text: "Mostrar todas"
                    selected: !root.controller.calendarListFilterActive
                    onClicked: root.controller.clearCalendarListFilter()
                }

                Repeater {
                    model: root.lists

                    RowLayout {
                        id: listRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: listRow.modelData.color
                        }

                        AppCheckBox {
                            Layout.fillWidth: true
                            text: listRow.modelData.name
                            checked: !root.controller.calendarListFilterActive
                                || root.controller.calendarListIds.indexOf(listRow.modelData.id) >= 0
                            Accessible.name: "Mostrar lista " + listRow.modelData.name
                            contentItem: Text {
                                leftPadding: 26
                                text: listRow.modelData.name
                                color: WaypointTheme.foreground
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.bodySmallSize
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            onClicked: root.toggleList(listRow.modelData.id)
                        }

                        AppButton {
                            text: "Somente"
                            Accessible.name: "Mostrar somente " + listRow.modelData.name
                            onClicked: root.controller.setCalendarListFilter([listRow.modelData.id])
                        }
                    }
                }
            }
        }
    }
}
