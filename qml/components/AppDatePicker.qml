pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string dateKey: ""
    property bool embedded: false
    readonly property bool acceptableInput: validDate(dateKey)
    readonly property string displayText: acceptableInput
        ? dateKey.slice(8, 10) + "/" + dateKey.slice(5, 7) + "/" + dateKey.slice(0, 4) : ""
    property int shownMonth: new Date().getMonth()
    property int shownYear: new Date().getFullYear()
    property string originalDate: ""
    property bool committing: false

    signal selectionAccepted(string selectedDate)

    implicitWidth: embedded ? 360 : 180
    implicitHeight: embedded ? calendarContent.implicitHeight : WaypointTheme.controlHeight

    function focusInput() {
        typedDate.forceActiveFocus();
        typedDate.selectAll();
    }

    function validDate(key) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(key))
            return false;
        const year = Number(key.slice(0, 4));
        const month = Number(key.slice(5, 7));
        const day = Number(key.slice(8, 10));
        const date = new Date(2000, month - 1, day, 12);
        date.setFullYear(year);
        return year > 0 && date.getFullYear() === year
            && date.getMonth() === month - 1 && date.getDate() === day;
    }

    function selectDate(date) {
        dateKey = Qt.formatDate(date, "yyyy-MM-dd");
    }

    function moveMonth(delta) {
        const date = new Date(2000, shownMonth, 1, 12);
        date.setFullYear(shownYear);
        date.setMonth(shownMonth + delta);
        if (date.getFullYear() < 1 || date.getFullYear() > 9999)
            return;
        shownMonth = date.getMonth();
        shownYear = date.getFullYear();
    }

    function applySelection() {
        if (!acceptableInput)
            return;
        if (!embedded) {
            committing = true;
            picker.close();
        }
        selectionAccepted(dateKey);
    }

    onDateKeyChanged: {
        if (validDate(dateKey)) {
            typedDate.text = dateKey.slice(8, 10) + "/" + dateKey.slice(5, 7) + "/" + dateKey.slice(0, 4);
            shownMonth = Number(dateKey.slice(5, 7)) - 1;
            shownYear = Number(dateKey.slice(0, 4));
        }
    }

    AppButton {
        anchors.fill: parent
        visible: !root.embedded
        text: root.acceptableInput ? root.displayText : "Selecionar data"
        onClicked: {
            root.originalDate = root.dateKey;
            root.committing = false;
            picker.open();
        }
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(420, parent.width - 24)
        padding: WaypointTheme.popupPadding
        contentHeight: calendarContent.implicitHeight
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            if (!root.committing)
                root.dateKey = root.originalDate;
        }
        Overlay.modal: Rectangle { color: WaypointTheme.scrim }
        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }
    }

    ColumnLayout {
        id: calendarContent
        parent: root.embedded ? root : picker.contentItem
        width: parent.width
        spacing: WaypointTheme.controlGap

        RowLayout {
            Layout.fillWidth: true
            AppButton {
                text: "‹"
                Accessible.name: "Mês anterior"
                onClicked: root.moveMonth(-1)
            }
            AppComboBox {
                Layout.fillWidth: true
                model: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
                currentIndex: root.shownMonth
                Accessible.name: "Mês"
                onActivated: root.shownMonth = currentIndex
            }
            AppSpinBox {
                from: 1
                to: 9999
                value: root.shownYear
                editable: true
                Accessible.name: "Ano"
                textFromValue: function(value, locale) { return String(value); }
                valueFromText: function(text, locale) { return Number(text); }
                onValueModified: root.shownYear = value
            }
            AppButton {
                text: "›"
                Accessible.name: "Próximo mês"
                onClicked: root.moveMonth(1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale("pt_BR")
            delegate: Text {
                required property string shortName
                text: shortName
                horizontalAlignment: Text.AlignHCenter
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
            }
        }
        MonthGrid {
            id: calendar
            Layout.fillWidth: true
            Layout.preferredHeight: 222
            month: root.shownMonth
            year: root.shownYear
            locale: Qt.locale("pt_BR")
            delegate: AppButton {
                required property var model
                text: String(model.day)
                selected: Qt.formatDate(model.date, "yyyy-MM-dd") === root.dateKey
                opacity: model.month === root.shownMonth ? 1 : 0.4
                Accessible.name: Qt.locale("pt_BR").toString(model.date, "dd 'de' MMMM 'de' yyyy")
                onClicked: root.selectDate(model.date)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            AppTextField {
                id: typedDate
                Layout.fillWidth: true
                placeholderText: "dd/MM/aaaa"
                Accessible.name: "Data, dia mês e ano"
                inputMethodHints: Qt.ImhDate
                onTextEdited: {
                    const parts = text.split("/");
                    root.dateKey = parts.length === 3
                        ? parts[2] + "-" + parts[1] + "-" + parts[0] : "";
                }
                onAccepted: root.applySelection()
            }
            AppButton {
                text: "Hoje"
                onClicked: root.selectDate(new Date())
            }
        }
        Text {
            visible: typedDate.text !== "" && !root.acceptableInput
            text: "Informe uma data válida: dd/MM/aaaa."
            color: WaypointTheme.urgent
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySmallSize
        }
        RowLayout {
            visible: !root.embedded
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            AppButton {
                text: "Cancelar"
                onClicked: picker.close()
            }
            AppButton {
                text: "Concluir"
                selected: true
                enabled: root.acceptableInput
                onClicked: root.applySelection()
            }
        }
    }
}
