pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    required property var controller
    readonly property var lists: {
        const result = [{ id: "", name: "Entrada", color: MobileTheme.accent }];
        for (const category of controller.taskCategories)
            result.push(category);
        return result;
    }
    readonly property string summary: {
        if (!controller.calendarListFilterActive)
            return "Todas";
        const ids = controller.calendarListIds;
        if (ids.length !== 1)
            return String(ids.length);
        for (const list of lists) {
            if (list.id === ids[0])
                return list.name;
        }
        return "Lista indisponível";
    }
    readonly property string emptyMessage: controller.calendarListIds.length === 0
        ? "Nenhuma lista selecionada. Mostre todas para ver tarefas."
        : "Nenhuma tarefa" + (controller.taskVisibility === "pending" ? " pendente" : "")
          + " neste dia nas listas selecionadas (" + summary + ").";
    spacing: 4

    function toggleList(listId) {
        const ids = controller.calendarListFilterActive
            ? Array.from(controller.calendarListIds) : lists.map(list => list.id);
        const index = ids.indexOf(listId);
        if (index < 0)
            ids.push(listId);
        else
            ids.splice(index, 1);
        controller.setCalendarListFilter(ids);
    }

    MobileButton {
        objectName: "calendarListFilterButton"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: 42
        text: root.controller.calendarListFilterActive && root.controller.calendarListIds.length === 1
            ? root.summary : "Listas: " + root.summary
        accent: root.controller.calendarListFilterActive
        Accessible.id: "calendar-list-filter"
        Accessible.name: text + ". Filtrar listas do calendário"
        onClicked: listPopup.open()
    }

    MobileButton {
        objectName: "calendarListFilterReset"
        visible: root.controller.calendarListFilterActive
        Layout.preferredWidth: 44
        Layout.preferredHeight: 42
        text: "×"
        quiet: true
        Accessible.name: "Mostrar todas as listas do calendário"
        onClicked: root.controller.clearCalendarListFilter()
    }

    Popup {
        id: listPopup
        objectName: "calendarListFilterPopup"
        readonly property real safeTop: parent ? parent.SafeArea.margins.top : 0
        readonly property real safeBottom: parent ? parent.SafeArea.margins.bottom : 0
        readonly property real safeLeft: parent ? parent.SafeArea.margins.left : 0
        readonly property real safeRight: parent ? parent.SafeArea.margins.right : 0
        parent: Overlay.overlay
        width: parent ? Math.min(440, parent.width - safeLeft - safeRight - 24) : 0
        height: parent ? Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                                  460, parent.height - safeTop - safeBottom - 24) : 0
        x: parent ? safeLeft + (parent.width - safeLeft - safeRight - width) / 2 : 0
        y: parent ? safeTop + (parent.height - safeTop - safeBottom - height) / 2 : 0
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: MobileTheme.scrim }
        background: Rectangle {
            color: MobileTheme.background
            radius: MobileTheme.radius
            border.color: MobileTheme.border
        }

        contentItem: ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Listas do calendário"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.subtitleSize
                    font.bold: true
                    elide: Text.ElideRight
                }
                MobileButton {
                    text: "×"
                    Layout.preferredWidth: 44
                    quiet: true
                    Accessible.name: "Fechar filtro de listas"
                    onClicked: listPopup.close()
                }
            }

            MobileButton {
                objectName: "calendarListFilterShowAll"
                Layout.fillWidth: true
                text: "Mostrar todas"
                Accessible.name: "Mostrar todas as listas, inclusive novas listas"
                onClicked: root.controller.clearCalendarListFilter()
            }

            ScrollView {
                id: listScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: listColumn.implicitHeight
                Layout.minimumHeight: 0
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    id: listColumn
                    width: listScroll.availableWidth
                    spacing: 4

                    Repeater {
                        model: root.lists
                        delegate: RowLayout {
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
                            MobileCheck {
                                id: listCheck
                                objectName: "calendarListCheck-" + listRow.modelData.id
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredHeight: 48
                                text: listRow.modelData.name
                                checked: !root.controller.calendarListFilterActive
                                    || root.controller.calendarListIds.indexOf(listRow.modelData.id) >= 0
                                Accessible.name: "Mostrar lista " + text
                                onClicked: root.toggleList(listRow.modelData.id)
                                contentItem: Text {
                                    leftPadding: listCheck.indicator.width + listCheck.spacing
                                    text: listCheck.text
                                    color: MobileTheme.foreground
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                            MobileButton {
                                objectName: "calendarListOnly-" + listRow.modelData.id
                                text: "Somente"
                                quiet: true
                                Accessible.name: "Mostrar somente a lista " + listRow.modelData.name
                                onClicked: root.controller.setCalendarListFilter([listRow.modelData.id])
                            }
                        }
                    }
                }
            }
        }
    }
}
