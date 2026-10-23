pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property var controller
    property string selectedListId: ""
    property bool allowSelection: true
    property string editingListId: ""
    property string editingColor: "#979FEC"
    property var pendingDelete: ({})
    signal listSelected(string listId)

    readonly property var paletteOptions: [
        { name: "Azul", color: "#979FEC" },
        { name: "Verde", color: "#9EC49F" },
        { name: "Âmbar", color: "#E9C98D" },
        { name: "Vermelho", color: "#B37580" },
        { name: "Ciano", color: "#80B9C7" },
        { name: "Violeta", color: "#C79BCB" },
        { name: "Laranja", color: "#D59A6F" },
        { name: "Cinza", color: "#A8A8A8" }
    ]
    readonly property var colorOptions: {
        const options = paletteOptions.slice();
        if (editingColor !== "" && colorIndex(editingColor) < 0)
            options.unshift({ name: "Cor atual", color: editingColor });
        return options;
    }

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(720, parent ? parent.width - 32 : 720)
    height: Math.min(620, parent ? parent.height - 32 : 620)
    padding: WaypointTheme.popupPadding
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function colorIndex(color) {
        for (let index = 0; index < paletteOptions.length; ++index) {
            if (paletteOptions[index].color === color)
                return index;
        }
        return -1;
    }

    function taskCount(listId) {
        let count = 0;
        for (const task of controller.allTasks) {
            if (String(task.categoryId || "") === listId)
                ++count;
        }
        return count;
    }

    function resetEditor() {
        editingListId = "";
        editingColor = paletteOptions[0].color;
        listName.clear();
        colorField.currentIndex = 0;
    }

    function openManager() {
        resetEditor();
        open();
    }

    function openForCreate() {
        resetEditor();
        open();
        Qt.callLater(() => listName.forceActiveFocus());
    }

    function openForEdit(list) {
        editingListId = String(list.id || "");
        editingColor = String(list.color || paletteOptions[0].color);
        listName.text = String(list.name || "");
        const index = colorIndex(editingColor);
        colorField.currentIndex = index < 0 ? 0 : index;
        open();
        Qt.callLater(() => {
            listName.forceActiveFocus();
            listName.selectAll();
        });
    }

    function selectList(listId) {
        listSelected(listId);
        close();
    }

    function savedListId(name) {
        if (editingListId !== "")
            return editingListId;
        const normalized = name.trim().toLocaleLowerCase();
        for (const list of controller.taskCategories) {
            if (String(list.name || "").trim().toLocaleLowerCase() === normalized)
                return String(list.id || "");
        }
        return "";
    }

    function saveList() {
        const name = listName.text.trim();
        if (name === "")
            return;
        if (!controller.saveTaskCategory(editingListId, name, colorField.currentValue))
            return;
        const listId = savedListId(name);
        if (allowSelection && listId !== "")
            listSelected(listId);
        close();
    }

    function requestDelete(list) {
        pendingDelete = list;
        deleteConfirmation.open();
    }

    function deletePendingList() {
        const listId = String(pendingDelete.id || "");
        if (listId === "" || !controller.deleteTaskCategory(listId))
            return;
        if (selectedListId === listId)
            listSelected("");
        pendingDelete = ({});
        deleteConfirmation.close();
        resetEditor();
    }

    Overlay.modal: Rectangle {
        color: WaypointTheme.scrim
    }

    background: Rectangle {
        radius: WaypointTheme.radiusLarge
        color: WaypointTheme.popupFill
        border.width: 1
        border.color: WaypointTheme.controlBorder
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Listas"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.headingSize
                    font.weight: WaypointTheme.weightSemiBold
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Uma tarefa pertence a uma lista. A cor identifica a lista no calendário."
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                    wrapMode: Text.Wrap
                }
            }

            AppButton {
                Layout.alignment: Qt.AlignTop
                square: true
                flat: true
                Accessible.name: "Fechar"
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
                onClicked: root.close()
                contentItem: Item {
                    AppIcon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        name: "close"
                        color: WaypointTheme.subduedText
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.controller.syncConfigured && !root.controller.categorySyncAvailable
            text: "Este servidor ainda não sincroniza listas. Elas permanecem somente neste dispositivo."
            color: WaypointTheme.warning
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySmallSize
            wrapMode: Text.Wrap
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            Rectangle {
                width: parent.width
                implicitHeight: listColumn.implicitHeight
                color: WaypointTheme.surface
                radius: WaypointTheme.radiusLarge
                border.width: 1
                border.color: WaypointTheme.controlBorder

                ColumnLayout {
                    id: listColumn
                    width: parent.width
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WaypointTheme.controlHeight + 12
                        Layout.leftMargin: 14
                        Layout.rightMargin: 8
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10
                            radius: 5
                            color: WaypointTheme.subduedText
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Entrada"
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySize
                        }

                        Text {
                            text: root.taskCount("")
                            color: WaypointTheme.disabledText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                            font.features: WaypointTheme.tabularNumbers
                        }

                        AppButton {
                            visible: root.allowSelection
                            flat: root.selectedListId !== ""
                            text: root.selectedListId === "" ? "Selecionada" : "Usar"
                            selected: root.selectedListId === ""
                            onClicked: root.selectList("")
                        }
                    }

                    Repeater {
                        model: root.controller.taskCategories

                        ColumnLayout {
                            id: listRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                Layout.preferredHeight: 1
                                color: WaypointTheme.divider
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: WaypointTheme.controlHeight + 12
                                Layout.leftMargin: 14
                                Layout.rightMargin: 8
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    radius: 5
                                    color: listRow.modelData.color
                                }

                                Text {
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    text: listRow.modelData.name
                                    color: WaypointTheme.foreground
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.bodySize
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.taskCount(listRow.modelData.id)
                                    color: WaypointTheme.disabledText
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.bodySmallSize
                                    font.features: WaypointTheme.tabularNumbers
                                }

                                AppButton {
                                    visible: root.allowSelection
                                    flat: root.selectedListId !== listRow.modelData.id
                                    text: root.selectedListId === listRow.modelData.id ? "Selecionada" : "Usar"
                                    selected: root.selectedListId === listRow.modelData.id
                                    onClicked: root.selectList(listRow.modelData.id)
                                }

                                AppButton {
                                    square: true
                                    flat: true
                                    Accessible.name: "Editar lista " + listRow.modelData.name
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Editar"
                                    onClicked: root.openForEdit(listRow.modelData)
                                    contentItem: Item {
                                        AppIcon {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            name: "edit"
                                            color: WaypointTheme.subduedText
                                        }
                                    }
                                }

                                AppButton {
                                    square: true
                                    flat: true
                                    Accessible.name: "Excluir lista " + listRow.modelData.name
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Excluir"
                                    onClicked: root.requestDelete(listRow.modelData)
                                    contentItem: Item {
                                        AppIcon {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            name: "trash"
                                            color: WaypointTheme.subduedText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: root.editingListId === "" ? "Nova lista" : "Editar lista"
            color: WaypointTheme.disabledText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.captionSize
            font.weight: WaypointTheme.weightMedium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppTextField {
                    id: listName
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    placeholderText: root.editingListId === "" ? "Nome da nova lista" : "Nome da lista"
                    onAccepted: root.saveList()
                    onTextChanged: {
                        const codePoints = Array.from(text);
                        if (codePoints.length > 80)
                            text = codePoints.slice(0, 80).join("");
                    }
                }

                AppComboBox {
                    id: colorField
                    Layout.preferredWidth: 150
                    model: root.colorOptions
                    textRole: "name"
                    valueRole: "color"
                    colorRole: "color"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                AppButton {
                    visible: root.editingListId !== ""
                    flat: true
                    text: "Cancelar"
                    onClicked: root.resetEditor()
                }

                AppButton {
                    text: root.editingListId === "" ? "Criar lista" : "Salvar alterações"
                    highlighted: true
                    enabled: listName.text.trim() !== ""
                    onClicked: root.saveList()
                }
            }
        }
    }

    Dialog {
        id: deleteConfirmation
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent ? parent.width - 32 : 400)
        padding: WaypointTheme.popupPadding
        modal: true
        standardButtons: Dialog.NoButton
        Overlay.modal: Rectangle { color: WaypointTheme.scrim }
        background: Rectangle {
            radius: WaypointTheme.radiusLarge
            color: WaypointTheme.popupFill
            border.width: 1
            border.color: WaypointTheme.controlBorder
        }
        header: null

        contentItem: ColumnLayout {
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "Excluir lista"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.headingSize
                font.weight: WaypointTheme.weightSemiBold
            }

            Text {
                Layout.fillWidth: true
                text: "Excluir “" + String(root.pendingDelete.name || "") + "”?\n"
                      + root.taskCount(String(root.pendingDelete.id || ""))
                      + " tarefa(s) serão movidas para Entrada. Nenhuma tarefa será excluída."
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                AppButton {
                    flat: true
                    text: "Cancelar"
                    onClicked: deleteConfirmation.close()
                }

                AppButton {
                    text: "Excluir lista"
                    destructive: true
                    onClicked: root.deletePendingList()
                }
            }
        }
    }
}
