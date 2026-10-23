pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Segmented "Pendentes | Todas" switch for the shared task visibility preference.
Rectangle {
    id: root

    required property var controller
    readonly property bool pendingOnly: controller.taskVisibility === "pending"

    implicitWidth: segments.implicitWidth + 6
    implicitHeight: 32
    radius: WaypointTheme.radius
    color: "transparent"
    border.width: 1
    border.color: WaypointTheme.controlBorder

    RowLayout {
        id: segments
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: [
                { value: "pending", label: "Pendentes",
                  description: "Exibir somente tarefas pendentes" },
                { value: "all", label: "Todas", description: "Exibir todas as tarefas" }
            ]

            AppButton {
                required property var modelData
                implicitHeight: 26
                leftPadding: 10
                rightPadding: 10
                flat: true
                text: modelData.label
                selected: (modelData.value === "pending") === root.pendingOnly
                Accessible.name: modelData.description
                onClicked: root.controller.setTaskVisibility(modelData.value)
            }
        }
    }
}
