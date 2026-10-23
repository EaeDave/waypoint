pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../data/Labels.js" as Labels

Item {
    id: root

    required property var controller

    CompletionActions {
        id: completionFlow
        controller: root.controller
    }

    readonly property bool compact: width < WaypointTheme.calendarSplitBreakpoint
    readonly property int pageMargin: compact ? 20 : 32
    readonly property int pageTopMargin: compact ? 20 : 28
    readonly property date now: new Date()
    readonly property int elapsedDays: Math.floor((now - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property int daysInYear: new Date(now.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365
    readonly property date selectedDateValue: {
        const parts = controller.selectedDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function holidayColor(kind) {
        if (kind === "legal")
            return WaypointTheme.urgent;
        if (kind === "optional")
            return WaypointTheme.accent;
        return WaypointTheme.warning;
    }

    function holidayKindLabel(kind, scope) {
        let category = "Data comemorativa";
        if (kind === "legal")
            category = "Feriado";
        else if (kind === "optional")
            category = "Ponto facultativo";

        let coverage = "";
        if (scope === "national")
            coverage = "nacional";
        else if (scope === "state")
            coverage = "estadual";
        else if (scope === "municipal")
            coverage = "municipal";
        return coverage === "" ? category : category + " " + coverage;
    }

    ScrollView {
        id: page
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            x: root.pageMargin
            y: root.pageTopMargin
            width: Math.max(0, page.availableWidth - root.pageMargin * 2)
            height: root.compact ? implicitHeight : Math.max(0, page.availableHeight - root.pageTopMargin - root.pageMargin)
            columns: root.compact ? 1 : 3
            columnSpacing: root.compact ? 0 : 32
            rowSpacing: root.compact ? 24 : 0

            Item {
                id: calendarPane
                Layout.fillWidth: true
                Layout.fillHeight: !root.compact
                Layout.preferredHeight: calendarColumn.implicitHeight
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                ColumnLayout {
                    id: calendarColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: Labels.sentenceCase(root.controller.calendar.monthLabel)
                                color: WaypointTheme.foreground
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: root.compact ? WaypointTheme.displaySize : WaypointTheme.displayLargeSize
                                font.weight: WaypointTheme.weightSemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "Ano " + root.now.getFullYear() + " · "
                                      + Math.round(root.elapsedDays * 100 / root.daysInYear) + "% concluído"
                                color: WaypointTheme.subduedText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.bodySmallSize
                                font.features: WaypointTheme.tabularNumbers
                            }
                        }

                        AppButton {
                            Layout.rightMargin: 4
                            text: "Hoje"
                            Accessible.name: "Ir para o mês atual"
                            onClicked: root.controller.calendar.showCurrentMonth()
                        }

                        AppButton {
                            square: true
                            flat: true
                            Accessible.name: "Mês anterior"
                            ToolTip.visible: hovered
                            ToolTip.text: Accessible.name
                            onClicked: root.controller.calendar.showPreviousMonth()
                            contentItem: Item {
                                AppIcon {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    name: "chevron-left"
                                    color: WaypointTheme.subduedText
                                }
                            }
                        }

                        AppButton {
                            square: true
                            flat: true
                            Accessible.name: "Próximo mês"
                            ToolTip.visible: hovered
                            ToolTip.text: Accessible.name
                            onClicked: root.controller.calendar.showNextMonth()
                            contentItem: Item {
                                AppIcon {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    name: "chevron-right"
                                    color: WaypointTheme.subduedText
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        Layout.preferredHeight: 4
                        radius: 2
                        color: WaypointTheme.controlFill

                        Rectangle {
                            width: parent.width * root.elapsedDays / root.daysInYear
                            height: parent.height
                            radius: 2
                            color: WaypointTheme.accent
                        }
                    }

                    CalendarListFilter {
                        id: listFilter
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.bottomMargin: 12
                        controller: root.controller
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: calendarGrid.implicitHeight + 28
                        radius: WaypointTheme.radiusLarge
                        color: WaypointTheme.surface
                        border.width: 1
                        border.color: WaypointTheme.controlBorder

                        CalendarGrid {
                            id: calendarGrid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            calendarModel: root.controller.calendar
                            selectedDateKey: root.controller.selectedDateKey
                            onDaySelected: selectedDateKey => root.controller.selectedDateKey = selectedDateKey
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: root.compact
                Layout.fillHeight: !root.compact
                Layout.preferredWidth: root.compact ? 0 : 1
                Layout.preferredHeight: root.compact ? 1 : 0
                color: WaypointTheme.divider
            }

            Item {
                id: taskPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.compact ? 360 : 0
                Layout.preferredHeight: root.compact ? 360 : 0
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: Labels.sentenceCase(Qt.locale("pt_BR").toString(root.selectedDateValue, "dddd, d 'de' MMMM"))
                                color: WaypointTheme.foreground
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.headingSize
                                font.weight: WaypointTheme.weightSemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    const pending = root.controller.selectedDateTasks.pendingCount;
                                    const skipped = root.controller.selectedDateTasks.skippedCount;
                                    const pendingLabel = pending + " pendente" + (pending === 1 ? "" : "s");
                                    return skipped === 0 ? pendingLabel
                                         : pendingLabel + " · " + skipped + " não feita" + (skipped === 1 ? "" : "s");
                                }
                                color: WaypointTheme.subduedText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.bodySmallSize
                                font.features: WaypointTheme.tabularNumbers
                            }
                        }

                        TaskVisibilityChip {
                            controller: root.controller
                        }
                    }

                    Repeater {
                        model: root.controller.selectedDateHolidays

                        Rectangle {
                            id: holidayCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            Layout.preferredHeight: holidayContent.implicitHeight + 24
                            radius: WaypointTheme.radiusLarge
                            color: WaypointTheme.surface
                            border.width: 1
                            border.color: WaypointTheme.controlBorder

                            RowLayout {
                                id: holidayContent
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 6
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: root.holidayColor(holidayCard.modelData.kind)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: holidayCard.modelData.name
                                        color: WaypointTheme.foreground
                                        font.family: WaypointTheme.fontFamily
                                        font.pixelSize: WaypointTheme.bodySize
                                        font.weight: WaypointTheme.weightMedium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: root.holidayKindLabel(holidayCard.modelData.kind,
                                                                    holidayCard.modelData.scope)
                                        color: root.holidayColor(holidayCard.modelData.kind)
                                        font.family: WaypointTheme.fontFamily
                                        font.pixelSize: WaypointTheme.captionSize
                                        font.weight: WaypointTheme.weightMedium
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        visible: holidayCard.modelData.description !== ""
                                        text: holidayCard.modelData.description
                                        color: WaypointTheme.subduedText
                                        font.family: WaypointTheme.fontFamily
                                        font.pixelSize: WaypointTheme.bodySmallSize
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    QuickTaskComposer {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        controller: root.controller
                        scheduledDateKey: root.controller.selectedDateKey
                        placeholderText: "Adicionar tarefa neste dia"
                    }

                    ScrollView {
                        id: selectedDateScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 16
                        contentWidth: availableWidth
                        clip: true

                        ColumnLayout {
                            width: selectedDateScroll.availableWidth
                            spacing: 20

                            Rectangle {
                                visible: selectedTasks.count > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: selectedTaskColumn.implicitHeight + 8
                                radius: WaypointTheme.radiusLarge
                                color: WaypointTheme.surface
                                border.width: 1
                                border.color: WaypointTheme.controlBorder

                                ColumnLayout {
                                    id: selectedTaskColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    spacing: 0

                                    Repeater {
                                        id: selectedTasks
                                        model: root.controller.selectedDateTasks

                                        delegate: TaskRow {
                                            required property int index
                                            Layout.fillWidth: true
                                            showDivider: index > 0
                                            controller: root.controller
                                            completionActions: completionFlow
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                visible: selectedTasks.count === 0
                                text: root.controller.calendarListFilterActive
                                    ? "Nenhuma tarefa " + (root.controller.taskVisibility === "pending" ? "pendente " : "")
                                        + "neste dia nas listas selecionadas: " + listFilter.selectionDescription + "."
                                    : root.controller.taskVisibility === "pending"
                                        ? "Nenhuma tarefa pendente neste dia."
                                        : "Clique acima para planejar este dia."
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                color: WaypointTheme.disabledText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.bodySize
                            }

                            AppButton {
                                Layout.alignment: Qt.AlignHCenter
                                visible: selectedTasks.count === 0 && root.controller.calendarListFilterActive
                                text: "Mostrar todas as listas"
                                onClicked: root.controller.clearCalendarListFilter()
                            }

                            RegistrationActivity {
                                Layout.fillWidth: true
                                groups: root.controller.selectedRegistrationActivity
                                dateKey: root.controller.selectedDateKey
                                completionActions: completionFlow
                            }

                            HabitSection {
                                Layout.fillWidth: true
                                controller: root.controller
                                habits: root.controller.selectedDateHabits
                                dateKey: root.controller.selectedDateKey
                            }

                            Item { Layout.preferredHeight: 12 }
                        }
                    }
                }
            }
        }
    }
}
