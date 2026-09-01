import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "io.waypoint.bar"
    ipcTarget: "io.waypoint.bar"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var occurrences: []
    property var holidays: []
    property var holidaySyncStatus: ({ state: "local-only", lastError: "" })
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property date today: new Date()
    property date selectedDate: new Date()
    property int viewYear: selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()

    readonly property var barIdentity: hostWidget || root
    readonly property var weeks: Model.monthWeeks(viewYear, viewMonth, occurrences, holidays)
    readonly property var selectedTasks: Model.occurrencesForDate(occurrences, selectedDate)
    readonly property var selectedHolidays: Model.holidaysForDate(holidays, selectedDate)
    readonly property real yearDone: Model.yearProgress(today)
    readonly property int yearDonePercent: Math.round(yearDone * 100)
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property int cellWidth: Style.space(52)
    readonly property int cellHeight: Style.space(34)
    readonly property int cellSpacing: Style.space(2)
    readonly property int weekColumnWidth: Style.space(32)
    readonly property int gutterWidth: Style.space(14)
    readonly property color optionalHolidayColor: "#8ba9ff"

    function holidayColor(kind) {
        if (kind === "legal")
            return Color.urgent;
        if (kind === "optional")
            return optionalHolidayColor;
        return Color.accent;
    }

    function holidayKindLabel(kind, scope) {
        let category = "DATA COMEMORATIVA";
        if (kind === "legal")
            category = "FERIADO";
        else if (kind === "optional")
            category = "PONTO FACULTATIVO";

        let coverage = "";
        if (scope === "national")
            coverage = "NACIONAL";
        else if (scope === "state")
            coverage = "ESTADUAL";
        else if (scope === "municipal")
            coverage = "MUNICIPAL";
        return coverage === "" ? category : category + " " + coverage;
    }


    function open() {
        today = new Date();
        selectedDate = today;
        viewYear = selectedDate.getFullYear();
        viewMonth = selectedDate.getMonth();
        if (hostWidget)
            hostWidget.refreshRange(viewYear, viewMonth);
        controller.show();
    }

    function close() {
        controller.hide();
    }

    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    function moveMonth(delta) {
        const next = new Date(viewYear, viewMonth + delta, 1);
        viewYear = next.getFullYear();
        viewMonth = next.getMonth();
        if (hostWidget)
            hostWidget.refreshRange(viewYear, viewMonth);
    }

    function selectDay(date) {
        selectedDate = date;
        if (date.getMonth() !== viewMonth || date.getFullYear() !== viewYear) {
            viewMonth = date.getMonth();
            viewYear = date.getFullYear();
            if (hostWidget)
                hostWidget.refreshRange(viewYear, viewMonth);
        }
        Qt.callLater(() => quickAdd.forceActiveFocus());
    }

    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: true
        focusTarget: keyCatcher
        contentWidth: popup.fittedContentWidth(Style.space(560))
        contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function (dx, dy) {
                if (dx !== 0)
                    root.moveMonth(dx);
            }
            onActivateRequested: quickAdd.forceActiveFocus()
            onCloseRequested: root.close()

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: contentColumn.width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: contentColumn
                    width: Math.max(panelFlick.width, calendarGridColumn.width)
                    spacing: Style.space(8)

                    Item {
                        width: parent.width
                        height: heroRow.height

                        Row {
                            id: heroRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(22)

                            Text {
                                anchors.baseline: heroDate.baseline
                                text: "󰃭"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 48
                            }

                            Text {
                                id: heroDate
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(root.selectedDate, "MMMM d")
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 52
                                font.bold: true
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: yearBlock.y + yearBlock.height

                        Item {
                            id: yearBlock
                            y: Style.space(6)
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: calendarGridColumn.width
                            height: Math.max(yearLabel.implicitHeight, Style.space(10))

                            Text {
                                id: yearLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.today.getFullYear()
                                color: Qt.darker(root.foreground, 1.5)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                font.letterSpacing: 1
                            }

                            Text {
                                id: yearPercent
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.yearDonePercent + "%"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }

                            Rectangle {
                                anchors.left: yearLabel.right
                                anchors.right: yearPercent.left
                                anchors.leftMargin: Style.space(12)
                                anchors.rightMargin: Style.space(12)
                                anchors.verticalCenter: parent.verticalCenter
                                height: Style.space(6)
                                radius: Style.cornerRadius > 0 ? height / 2 : 0
                                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                                Rectangle {
                                    width: Math.round(parent.width * root.yearDone)
                                    height: parent.height
                                    radius: parent.radius
                                    color: Style.selectedStateColor(root.foreground, Color.accent)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: calendarGridColumn.y + calendarGridColumn.height

                        WheelHandler {
                            onWheel: function (event) {
                                if (event.angleDelta.y === 0)
                                    return;
                                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1);
                            }
                        }

                        Column {
                            id: calendarGridColumn
                            y: Style.space(18)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(3)

                            Row {
                                id: headerRow
                                spacing: root.cellSpacing

                                Text {
                                    width: root.weekColumnWidth
                                    height: Style.space(16)
                                    text: "W"
                                    color: Qt.darker(root.foreground, 1.9)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    font.letterSpacing: 1
                                }

                                Item {
                                    width: root.gutterWidth
                                    height: Style.space(16)
                                }

                                Repeater {
                                    model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                                    Text {
                                        required property string modelData
                                        width: root.cellWidth
                                        height: Style.space(16)
                                        text: modelData
                                        color: Qt.darker(root.foreground, 1.5)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }
                            }

                            Repeater {
                                model: root.weeks

                                Row {
                                    required property var modelData
                                    spacing: root.cellSpacing

                                    Text {
                                        width: root.weekColumnWidth
                                        height: root.cellHeight
                                        text: modelData.week
                                        color: Qt.darker(root.foreground, 1.9)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                    }

                                    Item {
                                        width: root.gutterWidth
                                        height: root.cellHeight
                                    }

                                    Repeater {
                                        model: modelData.days

                                        Rectangle {
                                            required property var modelData
                                            width: root.cellWidth
                                            height: root.cellHeight
                                            radius: Style.cornerRadius
                                            color: dayMouse.containsMouse || Model.dateKey(root.selectedDate) === modelData.key
                                                ? Style.hoverFillFor(root.foreground, Color.accent)
                                                : "transparent"
                                            border.width: modelData.today ? Style.spacing.hairline : 0
                                            border.color: Style.normalBorderFor(root.foreground, Color.accent)

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.verticalCenterOffset: -2
                                                text: modelData.day
                                                color: modelData.inMonth
                                                    ? (modelData.holidayCount > 0
                                                       ? root.holidayColor(modelData.holidayKind)
                                                       : modelData.weekend ? Qt.darker(root.foreground, 1.45)
                                                                           : root.foreground)
                                                    : Qt.darker(root.foreground, 2.2)
                                                font.family: root.fontFamily
                                                font.pixelSize: Style.font.body
                                                font.bold: modelData.today
                                            }
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: Style.space(4)
                                                visible: modelData.holidayCount > 0
                                                width: modelData.holidayCount > 1 ? Style.space(10) : Style.space(6)
                                                height: Style.spacing.hairline * 2
                                                radius: height / 2
                                                color: root.holidayColor(modelData.holidayKind)
                                            }


                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: Style.space(3)
                                                spacing: Style.space(2)

                                                Repeater {
                                                    model: Math.min(modelData.pending, 3)

                                                    Rectangle {
                                                        required property int index
                                                        width: Style.space(3)
                                                        height: width
                                                        radius: width / 2
                                                        color: index < modelData.overdue ? Color.urgent : Color.accent
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: dayMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectDay(modelData.date)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            x: calendarGridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
                            y: calendarGridColumn.y + headerRow.height + calendarGridColumn.spacing
                            width: Style.spacing.hairline
                            height: calendarGridColumn.height - headerRow.height - calendarGridColumn.spacing
                            color: root.foreground
                            opacity: 0.1
                        }
                    }

                    Item {
                        width: parent.width
                        height: monthNavigation.height

                        Item {
                            id: monthNavigation
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: calendarGridColumn.width
                            height: monthLabel.implicitHeight + Style.space(10)

                            Text {
                                id: monthLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(130)
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy").toUpperCase()
                                color: Qt.darker(root.foreground, 1.4)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.letterSpacing: 1
                            }

                            ToolButton {
                                anchors.left: parent.left
                                anchors.leftMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                onClicked: root.moveMonth(-1)
                            }

                            ToolButton {
                                anchors.right: parent.right
                                anchors.rightMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                onClicked: root.moveMonth(1)
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.space(42)
                        radius: Style.cornerRadius
                        color: Style.hoverFillFor(root.foreground, Color.accent)

                        TextField {
                            id: quickAdd
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            placeholderText: "New task on " + Qt.formatDate(root.selectedDate, "MMM d") + "…"
                            color: root.foreground
                            placeholderTextColor: Qt.darker(root.foreground, 1.8)
                            font.family: root.fontFamily
                            background: Item {}
                            onAccepted: {
                                const title = text.trim();
                                if (title === "" || !root.hostWidget)
                                    return;
                                root.hostWidget.addTask(title, root.selectedDate);
                                text = "";
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(3)
                        visible: root.selectedHolidays.length > 0

                        Repeater {
                            model: root.selectedHolidays

                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: holidayDetails.implicitHeight + Style.space(14)
                                radius: Style.cornerRadius
                                color: Style.hoverFillFor(root.foreground,
                                                         root.holidayColor(modelData.kind))

                                Column {
                                    id: holidayDetails
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(2)

                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        color: root.holidayColor(modelData.kind)
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.holidayKindLabel(modelData.kind, modelData.scope)
                                        color: root.holidayColor(modelData.kind)
                                        opacity: 0.72
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                    }


                                    Text {
                                        width: parent.width
                                        visible: String(modelData.description || "") !== ""
                                        text: modelData.description || ""
                                        color: Qt.darker(root.foreground, 1.5)
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(2)

                        Repeater {
                            model: root.selectedTasks

                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: Style.space(46)
                                radius: Style.cornerRadius
                                color: taskMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(8)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.completed ? "󰄲" : "󰄱"
                                        color: modelData.completed ? Color.accent : root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Style.space(40)
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: modelData.completed ? Qt.darker(root.foreground, 1.8) : root.foreground
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.body
                                            font.strikeout: modelData.completed
                                        }
                                        Text {
                                            width: parent.width
                                            text: {
                                                const time = String(modelData.scheduledTime || "");
                                                const recurrence = String(modelData.recurrenceLabel || "");
                                                return recurrence === "" ? time : time + " · " + recurrence;
                                            }
                                            color: Color.accent
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: taskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.hostWidget)
                                        root.hostWidget.setOccurrenceCompleted(
                                            modelData.taskId, modelData.occurrenceDate,
                                            !modelData.completed)
                                }
                            }
                        }

                        Text {
                            visible: root.selectedTasks.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.loadError !== "" ? root.loadError : "No tasks for this day"
                            color: root.loadError !== "" ? Color.urgent : Qt.darker(root.foreground, 1.9)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }
                    }

                    RowLayout {
                        width: parent.width

                        Rectangle {
                            Layout.preferredWidth: Style.space(6)
                            Layout.preferredHeight: Style.space(6)
                            radius: width / 2
                            color: root.syncStatus.state === "ready" ? Color.accent
                                  : root.syncStatus.state === "error" ? Color.urgent
                                  : Qt.darker(root.foreground, 1.8)
                        }

                        Text {
                            text: root.syncStatus.state === "ready" ? "Synced"
                                : root.syncStatus.state === "syncing" ? "Syncing…"
                                : root.syncStatus.state === "error" ? "Sync error"
                                : "Local only"
                            color: Qt.darker(root.foreground, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        PanelActionButton {
                            iconText: "󰒓"
                            tooltipText: "Waypoint settings"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onClicked: if (root.hostWidget)
                                root.hostWidget.openSettings()
                        }
                    }
                }
            }
        }
    }
}
