import QtQuick

MobileButton {
    id: root

    required property var controller
    readonly property bool pendingOnly: controller.taskVisibility === "pending"

    implicitWidth: pendingOnly ? 112 : 76
    implicitHeight: 36
    leftPadding: 10
    rightPadding: 10
    text: pendingOnly ? "PENDENTES" : "TODAS"
    accent: pendingOnly
    Accessible.name: pendingOnly
        ? "Exibindo somente tarefas pendentes. Toque para mostrar todas."
        : "Exibindo todas as tarefas. Toque para mostrar somente pendentes."
    onClicked: controller.setTaskVisibility(pendingOnly ? "all" : "pending")
}
