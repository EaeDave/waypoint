pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "EmojiCatalog.js" as EmojiCatalog

Item {
    id: root
    required property string fontFamily

    property bool opened: false
    property string emoji: ""
    property string activeCategory: "rostos"
    property string hoveredName: ""

    signal emojiSelected(string selectedEmoji)
    signal cancelled()

    visible: opened

    function visibleItems() {
        const category = searchInput.text === "" ? activeCategory : "";
        return EmojiCatalog.filtered(category, searchInput.text);
    }

    function openPicker(currentEmoji) {
        emoji = currentEmoji || "";
        activeCategory = "rostos";
        hoveredName = "";
        searchInput.text = "";
        emojiGrid.model = visibleItems();
        opened = true;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function closePicker() {
        opened = false;
        root.cancelled();
    }

    function chooseEmoji(selectedEmoji) {
        emoji = selectedEmoji;
        opened = false;
        root.emojiSelected(selectedEmoji);
    }

    Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePicker()
        }
    }

    BorderSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space(32), Style.space(500))
        height: Math.min(parent.height - Style.space(32), Style.space(600))
        padding: Style.space(18)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.localOrSurfaceSpec(
            "popups", "border", Color.popups.border,
            Color.popups.border, Style.normalBorderWidth)

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: card.contentLeftInset
            anchors.rightMargin: card.contentRightInset
            anchors.topMargin: card.contentTopInset
            anchors.bottomMargin: card.contentBottomInset
            spacing: Style.space(8)

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "ESCOLHER EMOJI"
                    color: Color.popups.text
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    text: "Sem emoji"
                    foreground: Color.popups.text
                    accent: Color.accent
                    bordered: true
                    onClicked: root.chooseEmoji("")
                }
            }

            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Buscar emoji…"
                foreground: Color.popups.text
                accent: Color.accent
                selectByMouse: true
                onTextChanged: emojiGrid.model = root.visibleItems()
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(38)
                contentWidth: categoryRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: categoryRow
                    spacing: Style.space(4)

                    Repeater {
                        model: EmojiCatalog.categories

                        Button {
                            required property var modelData
                            text: modelData.emoji
                            tooltipText: modelData.label
                            foreground: Color.popups.text
                            accent: Color.accent
                            selected: root.activeCategory === modelData.id && searchInput.text === ""
                            horizontalPadding: Style.space(8)
                            verticalPadding: Style.space(4)
                            onClicked: {
                                searchInput.text = "";
                                root.activeCategory = modelData.id;
                                emojiGrid.model = root.visibleItems();
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
                cellWidth: Style.space(46)
                cellHeight: Style.space(46)
                model: root.visibleItems()

                delegate: Rectangle {
                    id: emojiCell
                    required property var modelData
                    width: emojiGrid.cellWidth - Style.space(4)
                    height: emojiGrid.cellHeight - Style.space(4)
                    radius: Style.cornerRadius
                    color: tapHandler.pressed || emojiCell.modelData.emoji === root.emoji
                           ? Style.selectedStateColor(Color.popups.text, Color.accent)
                           : hoverHandler.hovered
                             ? Style.hoverFillFor(Color.popups.text, Color.accent)
                             : "transparent"
                    border.width: emojiCell.modelData.emoji === root.emoji ? Style.normalBorderWidth : 0
                    border.color: Color.popups.text

                    Text {
                        anchors.centerIn: parent
                        text: emojiCell.modelData.emoji
                        color: Color.popups.text
                        font.family: "Noto Color Emoji"
                        font.pixelSize: Style.font.display
                    }
                    HoverHandler {
                        id: hoverHandler
                        onHoveredChanged: {
                            if (hovered)
                                root.hoveredName = emojiCell.modelData.name;
                            else if (root.hoveredName === emojiCell.modelData.name)
                                root.hoveredName = "";
                        }
                    }
                    TapHandler {
                        id: tapHandler
                        onTapped: root.chooseEmoji(emojiCell.modelData.emoji)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: emojiGrid.count === 0 ? "Nenhum emoji encontrado" : root.hoveredName
                color: Color.popups.text
                opacity: 0.65
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
            }
        }
    }
}
