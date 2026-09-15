pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property var controller
    property string selectedListId: ""
    property string editingListId: ""
    property string selectedColor: "#979FEC"
    property var pendingDelete: ({})
    signal listSelected(string listId)

    readonly property var listPalette: [
        "#979FEC", "#9EC49F", "#E9C98D", "#B37580",
        "#80B9C7", "#C79BCB", "#D59A6F", "#A8A8A8"
    ]

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

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
        selectedColor = listPalette[0];
        listName.text = "";
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
        open();
        editList(list);
    }

    function editList(list) {
        editingListId = String(list.id || "");
        selectedColor = String(list.color || listPalette[0]);
        listName.text = String(list.name || "");
        Qt.callLater(() => {
            listName.forceActiveFocus();
            listName.selectAll();
        });
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
        if (!controller.saveTaskCategory(editingListId, name, selectedColor))
            return;
        const listId = savedListId(name);
        if (listId !== "")
            listSelected(listId);
        close();
    }

    function selectList(listId) {
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

    Overlay.modal: Rectangle { color: MobileTheme.scrim }
    background: Rectangle { color: MobileTheme.background }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            color: MobileTheme.background

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: MobileTheme.divider
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: MobileTheme.pageMargin
                anchors.rightMargin: MobileTheme.pageMargin
                spacing: 8

                MobileButton {
                    Layout.preferredWidth: 44
                    text: "‹"
                    quiet: true
                    Accessible.name: "Fechar listas"
                    onClicked: root.close()
                }

                Text {
                    Layout.fillWidth: true
                    text: "Listas"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.titleSize
                    font.bold: true
                }

                MobileButton {
                    Layout.preferredWidth: 96
                    text: root.editingListId === "" ? "CRIAR" : "SALVAR"
                    accent: true
                    enabled: listName.text.trim().length > 0
                    onClicked: root.saveList()
                }
            }
        }

        ScrollView {
            id: listScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: Math.max(0, listScroll.availableWidth - MobileTheme.pageMargin * 2)
                x: MobileTheme.pageMargin
                spacing: 10

                Item { Layout.preferredHeight: 4 }

                Text {
                    text: root.editingListId === "" ? "NOVA LISTA" : "EDITAR LISTA"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                MobileField {
                    id: listName
                    Layout.fillWidth: true
                    placeholderText: "Nome da lista"
                    Accessible.id: "list-name"
                    onAccepted: root.saveList()
                    onTextChanged: {
                        const codePoints = Array.from(text);
                        if (codePoints.length > 80)
                            text = codePoints.slice(0, 80).join("");
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.listPalette

                        Button {
                            id: colorButton
                            required property string modelData
                            width: 42
                            height: 42
                            Accessible.name: "Cor " + colorButton.modelData
                            onClicked: root.selectedColor = colorButton.modelData
                            background: Rectangle {
                                radius: MobileTheme.radius
                                color: colorButton.modelData
                                border.width: root.selectedColor === colorButton.modelData ? 3 : 1
                                border.color: root.selectedColor === colorButton.modelData
                                              ? MobileTheme.foreground : MobileTheme.border
                            }
                            contentItem: Item {}
                        }
                    }
                }

                MobileButton {
                    visible: root.editingListId !== ""
                    Layout.fillWidth: true
                    text: "CANCELAR EDIÇÃO"
                    quiet: true
                    onClicked: root.resetEditor()
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.controller.syncConfigured && !root.controller.categorySyncAvailable
                    text: "Este servidor ainda não sincroniza listas. Elas permanecem somente neste aparelho."
                    color: MobileTheme.warning
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: MobileTheme.divider
                }

                Text {
                    text: "SUAS LISTAS"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: MobileTheme.touchHeight + 8
                    color: MobileTheme.surface
                    radius: MobileTheme.radius

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 30
                            radius: 3
                            color: MobileTheme.subdued
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Entrada · " + root.taskCount("")
                            color: MobileTheme.foreground
                            font.family: MobileTheme.fontFamily
                            font.pixelSize: MobileTheme.bodySize
                        }

                        MobileButton {
                            Layout.preferredWidth: 106
                            text: root.selectedListId === "" ? "SELECIONADA" : "USAR"
                            accent: root.selectedListId === ""
                            quiet: root.selectedListId !== ""
                            onClicked: root.selectList("")
                        }
                    }
                }

                Repeater {
                    model: root.controller.taskCategories

                    Rectangle {
                        id: listRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: listActions.implicitHeight + 12
                        color: MobileTheme.surface
                        radius: MobileTheme.radius

                        RowLayout {
                            id: listActions
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 34
                                radius: 3
                                color: listRow.modelData.color
                            }

                            Text {
                                Layout.fillWidth: true
                                text: listRow.modelData.name + " · " + root.taskCount(listRow.modelData.id)
                                color: MobileTheme.foreground
                                font.family: MobileTheme.fontFamily
                                font.pixelSize: MobileTheme.bodySize
                                elide: Text.ElideRight
                            }

                            MobileButton {
                                Layout.preferredWidth: 70
                                text: root.selectedListId === listRow.modelData.id ? "ATIVA" : "USAR"
                                accent: root.selectedListId === listRow.modelData.id
                                quiet: root.selectedListId !== listRow.modelData.id
                                onClicked: root.selectList(listRow.modelData.id)
                            }

                            MobileButton {
                                Layout.preferredWidth: 96
                                text: "EDITAR"
                                quiet: true
                                Accessible.name: "Editar lista " + listRow.modelData.name
                                onClicked: root.editList(listRow.modelData)
                            }

                            MobileButton {
                                Layout.preferredWidth: 52
                                text: "×"
                                quiet: true
                                destructive: true
                                Accessible.name: "Excluir lista " + listRow.modelData.name
                                onClicked: root.requestDelete(listRow.modelData)
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 18 }
            }
        }
    }

    Dialog {
        id: deleteConfirmation
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(380, parent ? parent.width - 32 : 380)
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
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.bodySize
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true

                MobileButton {
                    Layout.fillWidth: true
                    text: "CANCELAR"
                    quiet: true
                    onClicked: deleteConfirmation.close()
                }

                MobileButton {
                    Layout.fillWidth: true
                    text: "EXCLUIR"
                    destructive: true
                    onClicked: root.deletePendingList()
                }
            }
        }
    }
}
