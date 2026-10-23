pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data/EmojiCatalog.js" as EmojiCatalog

Item {
    id: root

    property string emoji: ""
    property string activeCategory: "rostos"
    property string originalEmoji: ""
    property bool committing: false

    signal selectionAccepted(string selectedEmoji)

    implicitWidth: 34
    implicitHeight: WaypointTheme.controlHeight

    function visibleItems() {
        const category = searchInput.text === "" ? activeCategory : "";
        return EmojiCatalog.filtered(category, searchInput.text);
    }

    function openPicker() {
        originalEmoji = emoji;
        committing = false;
        searchInput.text = "";
        activeCategory = "rostos";
        picker.open();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function chooseEmoji(selectedEmoji) {
        emoji = selectedEmoji;
        committing = true;
        picker.close();
        root.selectionAccepted(selectedEmoji);
    }

    AppButton {
        id: inlineButton
        anchors.fill: parent
        square: true
        text: root.emoji
        onClicked: root.openPicker()
        ToolTip.visible: hovered
        ToolTip.text: root.emoji === "" ? "Adicionar emoji" : "Alterar emoji"
        Accessible.name: ToolTip.text

        contentItem: Item {
            AppIcon {
                anchors.centerIn: parent
                width: 16
                height: 16
                visible: root.emoji === ""
                name: "plus"
                color: WaypointTheme.subduedText
            }
            Text {
                anchors.centerIn: parent
                visible: root.emoji !== ""
                text: root.emoji
                font.family: "Noto Color Emoji"
                font.pixelSize: 20
            }
        }
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(520, parent.width - 24)
        height: Math.min(560, parent.height - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            if (!root.committing)
                root.emoji = root.originalEmoji;
            root.committing = false;
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
            spacing: WaypointTheme.controlGap

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Escolher emoji"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.headingSize
                    font.weight: WaypointTheme.weightSemiBold
                }
                Item {
                    Layout.fillWidth: true
                }
                AppButton {
                    text: "Sem emoji"
                    flat: true
                    onClicked: root.chooseEmoji("")
                }
            }

            AppTextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Buscar emoji…"
                onTextChanged: emojiGrid.model = root.visibleItems()
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                contentWidth: categoryRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: categoryRow
                    spacing: 4

                    Repeater {
                        model: EmojiCatalog.categories

                        AppButton {
                            required property var modelData
                            square: true
                            flat: true
                            id: categoryButton
                            text: modelData.emoji
                            selected: root.activeCategory === modelData.id && searchInput.text === ""
                            onClicked: {
                                searchInput.text = "";
                                root.activeCategory = modelData.id;
                                emojiGrid.model = root.visibleItems();
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: modelData.label

                            contentItem: Text {
                                text: categoryButton.text
                                color: WaypointTheme.foreground
                                font.family: "Noto Color Emoji"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            GridView {
                id: emojiGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 48
                cellHeight: 48
                model: root.visibleItems()

                ScrollBar.vertical: ScrollBar {}

                delegate: Button {
                    id: emojiButton
                    required property var modelData
                    width: emojiGrid.cellWidth - 4
                    height: emojiGrid.cellHeight - 4
                    hoverEnabled: true
                    flat: true
                    onClicked: root.chooseEmoji(modelData.emoji)
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.name

                    contentItem: Text {
                        text: emojiButton.modelData.emoji
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: WaypointTheme.radius
                        color: emojiButton.modelData.emoji === root.emoji ? WaypointTheme.accentSoft
                             : emojiButton.down ? WaypointTheme.controlSelectedFill
                             : emojiButton.hovered ? WaypointTheme.controlHoverFill : "transparent"
                    }
                }
            }

            Text {
                visible: emojiGrid.count === 0
                Layout.alignment: Qt.AlignHCenter
                text: "Nenhum emoji encontrado"
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
            }
        }
    }
}
