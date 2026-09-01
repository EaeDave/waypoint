import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "views"
import "components"

ApplicationWindow {
    id: root

    required property var waypointController

    width: 1120
    height: 720
    minimumWidth: 600
    minimumHeight: 520
    visible: true
    title: "Waypoint"
    color: WaypointTheme.background
    font.family: WaypointTheme.fontFamily
    font.pixelSize: WaypointTheme.bodySize

    palette.window: WaypointTheme.background
    palette.windowText: WaypointTheme.foreground
    palette.base: WaypointTheme.background
    palette.alternateBase: WaypointTheme.controlFill
    palette.text: WaypointTheme.foreground
    palette.button: WaypointTheme.controlFill
    palette.buttonText: WaypointTheme.foreground
    palette.highlight: WaypointTheme.controlSelectedFill
    palette.highlightedText: WaypointTheme.foreground
    palette.mid: WaypointTheme.controlBorder

    property int activePage: 0

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 64
            Layout.fillHeight: true
            color: WaypointTheme.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: WaypointTheme.panelPadding
                anchors.bottomMargin: WaypointTheme.panelPadding
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: WaypointTheme.radius
                    color: WaypointTheme.accent
                    border.width: 1
                    border.color: WaypointTheme.activeBorder

                    Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: WaypointTheme.background
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.headingSize
                        font.bold: true
                    }
                }

                Item {
                    Layout.preferredHeight: 12
                }

                ToolButton {
                    id: todayButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    checked: root.activePage === 0
                    onClicked: root.activePage = 0
                    ToolTip.visible: hovered
                    ToolTip.text: "Hoje"
                    contentItem: AppIcon {
                        name: "tasks"
                        color: todayButton.checked ? WaypointTheme.foreground : WaypointTheme.subduedText
                    }
                    background: Rectangle {
                        radius: WaypointTheme.radius
                        color: todayButton.checked ? WaypointTheme.controlSelectedFill
                             : todayButton.hovered ? WaypointTheme.controlHoverFill
                             : "transparent"
                        border.width: 1
                        border.color: todayButton.checked ? WaypointTheme.activeBorder
                                    : todayButton.hovered ? WaypointTheme.controlHoverBorder
                                    : "transparent"
                    }
                }

                ToolButton {
                    id: monthButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    checked: root.activePage === 1
                    onClicked: root.activePage = 1
                    ToolTip.visible: hovered
                    ToolTip.text: "Calendário"
                    contentItem: AppIcon {
                        name: "calendar"
                        color: monthButton.checked ? WaypointTheme.foreground : WaypointTheme.subduedText
                    }
                    background: Rectangle {
                        radius: WaypointTheme.radius
                        color: monthButton.checked ? WaypointTheme.controlSelectedFill
                             : monthButton.hovered ? WaypointTheme.controlHoverFill
                             : "transparent"
                        border.width: 1
                        border.color: monthButton.checked ? WaypointTheme.activeBorder
                                    : monthButton.hovered ? WaypointTheme.controlHoverBorder
                                    : "transparent"
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                ToolButton {
                    id: settingsButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    checked: root.activePage === 2
                    text: "⋯"
                    onClicked: root.activePage = 2
                    ToolTip.visible: hovered
                    ToolTip.text: "Configurações"
                    contentItem: Text {
                        text: settingsButton.text
                        color: settingsButton.checked ? WaypointTheme.foreground : WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.titleSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: WaypointTheme.radius
                        color: settingsButton.checked ? WaypointTheme.controlSelectedFill
                             : settingsButton.hovered ? WaypointTheme.controlHoverFill
                             : "transparent"
                        border.width: 1
                        border.color: settingsButton.checked ? WaypointTheme.activeBorder
                                    : settingsButton.hovered ? WaypointTheme.controlHoverBorder
                                    : "transparent"
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 4
                    color: root.waypointController.online ? WaypointTheme.success : WaypointTheme.urgent
                    ToolTip.visible: statusPointer.containsMouse
                    ToolTip.text: root.waypointController.online ? "Daemon conectado" : root.waypointController.errorMessage

                    MouseArea {
                        id: statusPointer
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: WaypointTheme.divider
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activePage

            TodayView {
                controller: root.waypointController
            }

            MonthView {
                controller: root.waypointController
            }

            SettingsView {
                controller: root.waypointController
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+1"
        onActivated: root.activePage = 0
    }

    Shortcut {
        sequence: "Ctrl+2"
        onActivated: root.activePage = 1
    }

    Shortcut {
        sequence: "Ctrl+3"
        onActivated: root.activePage = 2
    }

    Component.onCompleted: root.waypointController.start()
}
