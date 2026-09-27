pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var groups
    required property var completionActions
    property bool expanded: false
    visible: groups.length > 0
    spacing: 8

    MobileButton {
        Layout.fillWidth: true
        text: (root.expanded ? "−  " : "+  ") + "CONCLUSÕES REGISTRADAS"
        Accessible.name: "Conclusões registradas neste dia"
        Accessible.description: root.expanded ? "Recolher histórico" : "Expandir histórico"
        quiet: true
        onClicked: root.expanded = !root.expanded
    }

    Text {
        Layout.fillWidth: true
        visible: root.expanded
        text: "Registros de tarefas previstas para outros dias. O histórico permanece na data prevista."
        color: MobileTheme.subdued
        font.family: MobileTheme.fontFamily
        font.pixelSize: MobileTheme.bodySize
        wrapMode: Text.Wrap
    }

    Repeater {
        model: root.expanded ? root.groups : []
        delegate: ColumnLayout {
            id: group
            required property var modelData
            property bool expanded: false
            Layout.fillWidth: true
            spacing: 6

            Button {
                id: groupButton
                Layout.fillWidth: true
                implicitHeight: Math.max(MobileTheme.touchHeight, groupLabel.implicitHeight + 20)
                padding: 10
                Accessible.name: group.modelData.title + ", " + group.modelData.count + " conclusões"
                Accessible.description: group.modelData.dateSummary
                onClicked: group.expanded = !group.expanded
                background: Rectangle {
                    color: groupButton.down ? MobileTheme.surfacePressed : MobileTheme.surfaceRaised
                    border.color: MobileTheme.divider
                    radius: MobileTheme.radius
                }
                contentItem: ColumnLayout {
                    id: groupLabel
                    spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: (group.expanded ? "−  " : "+  ")
                              + (group.modelData.emoji ? group.modelData.emoji + "  " : "")
                              + group.modelData.title + " · " + group.modelData.count
                        color: MobileTheme.foreground
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.bodySize
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: group.modelData.dateSummary
                        color: MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                        wrapMode: Text.Wrap
                    }
                }
            }

            Repeater {
                model: group.expanded ? group.modelData.occurrences : []
                delegate: ColumnLayout {
                    id: occurrence
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: "PREVISTA PARA "
                              + Qt.formatDate(new Date(occurrence.modelData.occurrenceDate + "T00:00:00"),
                                              "dd/MM/yyyy")
                        color: MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: occurrence.modelData.completionLabel
                        color: occurrence.modelData.completionLate ? MobileTheme.warning : MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.bodySize
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        MobileButton {
                            Layout.fillWidth: true
                            text: "Alterar data"
                            quiet: true
                            onClicked: root.completionActions.edit(occurrence.modelData)
                        }
                        MobileButton {
                            Layout.fillWidth: true
                            text: "Desfazer"
                            quiet: true
                            onClicked: root.completionActions.toggle(occurrence.modelData)
                        }
                    }
                }
            }
        }
    }
}
