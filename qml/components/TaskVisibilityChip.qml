import QtQuick
import QtQuick.Controls

AppButton {
    id: root

    required property var controller
    readonly property bool pendingOnly: controller.taskVisibility === "pending"

    implicitWidth: pendingOnly ? 104 : 72
    implicitHeight: 28
    text: pendingOnly ? "PENDENTES" : "TODAS"
    selected: pendingOnly
    Accessible.name: pendingOnly
        ? "Exibindo somente tarefas pendentes. Clique para mostrar todas."
        : "Exibindo todas as tarefas. Clique para mostrar somente pendentes."
    ToolTip.visible: hovered
    ToolTip.text: Accessible.name
    onClicked: controller.setTaskVisibility(pendingOnly ? "all" : "pending")
}
