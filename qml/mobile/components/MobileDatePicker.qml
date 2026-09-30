pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string selectedDate: ""
    property int month: new Date().getMonth()
    property int year: new Date().getFullYear()
    readonly property var portugueseLocale: Qt.locale("pt_BR")
    signal dateSelected(string dateKey)

    function show(dateKey) {
        selectedDate = dateKey;
        const parts = dateKey.split("-");
        const date = parts.length === 3 ? new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) : new Date();
        month = date.getMonth();
        year = date.getFullYear();
    }

    function moveMonth(delta) {
        const date = new Date(year, month + delta, 1);
        month = date.getMonth();
        year = date.getFullYear();
    }

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        MobileButton {
            text: "‹"
            Accessible.name: "Mês anterior"
            onClicked: root.moveMonth(-1)
        }
        Label {
            Layout.fillWidth: true
            text: root.portugueseLocale.toString(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: MobileTheme.foreground
            horizontalAlignment: Text.AlignHCenter
        }
        MobileButton {
            text: "›"
            Accessible.name: "Próximo mês"
            onClicked: root.moveMonth(1)
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: root.portugueseLocale
        delegate: Label {
            required property string shortName
            text: shortName
            color: MobileTheme.subdued
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    MonthGrid {
        Layout.fillWidth: true
        Layout.preferredHeight: 264
        month: root.month
        year: root.year
        locale: root.portugueseLocale
        delegate: MobileButton {
            required property var model
            readonly property string dateKey: Qt.formatDate(model.date, "yyyy-MM-dd")
            text: model.day
            leftPadding: 0
            rightPadding: 0
            opacity: model.month === root.month ? 1 : 0.45
            accent: dateKey === root.selectedDate
            Accessible.name: root.portugueseLocale.toString(model.date, "dddd, d 'de' MMMM 'de' yyyy")
            Accessible.id: "task-date-" + dateKey
            onClicked: {
                root.selectedDate = dateKey;
                root.dateSelected(dateKey);
            }
        }
    }
}
