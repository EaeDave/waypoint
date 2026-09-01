import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "views"

ApplicationWindow {
    id: root

    required property var waypointController

    width: 1120
    height: 720
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: "Waypoint"
    color: "#070708"

    property int activePage: 0

    Rectangle {
        anchors.fill: parent
        color: "#070708"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 72
            Layout.fillHeight: true
            color: "#0c0c0e"
            border.width: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 20
                anchors.bottomMargin: 18
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 10
                    color: "#a997ff"

                    Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: "#0a090c"
                        font.pixelSize: 17
                        font.bold: true
                    }
                }

                Item {
                    Layout.preferredHeight: 18
                }

                ToolButton {
                    id: todayButton
                    Layout.alignment: Qt.AlignHCenter
                    text: "✓"
                    checked: root.activePage === 0
                    onClicked: root.activePage = 0
                    ToolTip.visible: hovered
                    ToolTip.text: "Hoje"
                    background: Rectangle {
                        radius: 8
                        color: todayButton.checked ? "#1b1922" : (todayButton.hovered ? "#151519" : "transparent")
                    }
                }

                ToolButton {
                    id: monthButton
                    Layout.alignment: Qt.AlignHCenter
                    text: "▦"
                    checked: root.activePage === 1
                    onClicked: root.activePage = 1
                    ToolTip.visible: hovered
                    ToolTip.text: "Calendário"
                    background: Rectangle {
                        radius: 8
                        color: monthButton.checked ? "#1b1922" : (monthButton.hovered ? "#151519" : "transparent")
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                ToolButton {
                    id: settingsButton
                    Layout.alignment: Qt.AlignHCenter
                    text: "⚙"
                    checked: root.activePage === 2
                    onClicked: root.activePage = 2
                    ToolTip.visible: hovered
                    ToolTip.text: "Configurações"
                    background: Rectangle {
                        radius: 8
                        color: settingsButton.checked ? "#1b1922" : (settingsButton.hovered ? "#151519" : "transparent")
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 4
                    color: root.waypointController.online ? "#81d39a" : "#ff7085"
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
            color: "#202026"
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
