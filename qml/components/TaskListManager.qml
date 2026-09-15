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
        radius: WaypointTheme.radius
        color: WaypointTheme.background
        border.width: 1
        border.color: WaypointTheme.activeBorder
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "LISTAS"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.titleSize
                    font.bold: true
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

            Item { Layout.fillWidth: true }

            AppButton {
                text: "Fechar"
                onClicked: root.close()
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

            ColumnLayout {
                width: parent.width
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: WaypointTheme.controlHeight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: WaypointTheme.subduedText
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Entrada · " + root.taskCount("")
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySize
                    }

                    AppButton {
                        visible: root.allowSelection
                        text: root.selectedListId === "" ? "Selecionada" : "Usar"
                        selected: root.selectedListId === ""
                        onClicked: root.selectList("")
                    }
                }

                Repeater {
                    model: root.controller.taskCategories

                    RowLayout {
                        id: listRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: WaypointTheme.controlHeight
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 24
                            radius: 3
                            color: listRow.modelData.color
                        }

                        Text {
                            Layout.minimumWidth: 0
                            Layout.fillWidth: true
                            text: listRow.modelData.name + " · " + root.taskCount(listRow.modelData.id)
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySize
                            elide: Text.ElideRight
                        }

                        AppButton {
                            visible: root.allowSelection
                            text: root.selectedListId === listRow.modelData.id ? "Selecionada" : "Usar"
                            selected: root.selectedListId === listRow.modelData.id
                            onClicked: root.selectList(listRow.modelData.id)
                        }

                        AppButton {
                            text: "Editar"
                            onClicked: root.openForEdit(listRow.modelData)
                        }

                        AppButton {
                            text: "Excluir"
                            destructive: true
                            onClicked: root.requestDelete(listRow.modelData)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: WaypointTheme.divider
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
                    text: "Cancelar"
                    onClicked: root.resetEditor()
                }

                AppButton {
                    text: root.editingListId === "" ? "Criar lista" : "Salvar alterações"
                    selected: true
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
        modal: true
        title: "Excluir lista"
        standardButtons: Dialog.NoButton

        contentItem: ColumnLayout {
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "Excluir “" + String(root.pendingDelete.name || "") + "”?\n"
                      + root.taskCount(String(root.pendingDelete.id || ""))
                      + " tarefa(s) serão movidas para Entrada. Nenhuma tarefa será excluída."
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                AppButton {
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
