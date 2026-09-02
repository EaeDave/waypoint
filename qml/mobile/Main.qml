pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "views"

ApplicationWindow {
    id: root

    required property var controller
    property int currentPage: 0

    visible: true
    width: 420
    height: 860
    minimumWidth: 320
    minimumHeight: 560
    title: "Waypoint"
    color: MobileTheme.background
    palette.window: MobileTheme.background
    palette.windowText: MobileTheme.foreground
    palette.base: MobileTheme.surfaceRaised
    palette.alternateBase: MobileTheme.surfacePressed
    palette.text: MobileTheme.foreground
    palette.button: MobileTheme.surfaceRaised
    palette.buttonText: MobileTheme.foreground
    palette.highlight: MobileTheme.accent
    palette.highlightedText: MobileTheme.background
    palette.placeholderText: MobileTheme.disabled
    palette.mid: MobileTheme.border
    palette.dark: MobileTheme.background
    palette.light: MobileTheme.surfacePressed

    Component.onCompleted: root.controller.start()

    StackLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: navigation.top
        currentIndex: root.currentPage

        TodayPage {
            controller: root.controller
        }
        CalendarPage {
            controller: root.controller
        }
        HabitsPage {
            controller: root.controller
        }
        SettingsPage {
            controller: root.controller
        }
    }

    Rectangle {
        id: errorBanner
        visible: root.controller.errorMessage !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: navigation.top
        anchors.margins: 12
        implicitHeight: errorText.implicitHeight + 22
        radius: MobileTheme.radius
        color: "#321923"
        border.width: 1
        border.color: MobileTheme.urgent
        z: 20

        Text {
            id: errorText
            anchors.fill: parent
            anchors.margins: 11
            text: root.controller.errorMessage
            Accessible.id: "application-error"
            Accessible.name: text
            color: MobileTheme.foreground
            font.family: MobileTheme.fontFamily
            font.pixelSize: MobileTheme.captionSize
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle {
        id: navigation
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 64 + root.SafeArea.margins.bottom
        color: MobileTheme.background
        z: 10

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: MobileTheme.divider
        }

        Row {
            id: navigationRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8 + root.SafeArea.margins.left
            anchors.rightMargin: 8 + root.SafeArea.margins.right
            anchors.bottomMargin: root.SafeArea.margins.bottom
            spacing: 2

            Repeater {
                model: [
                    {
                        id: "today",
                        icon: "today",
                        label: "HOJE"
                    },
                    {
                        id: "calendar",
                        icon: "calendar",
                        label: "MÊS"
                    },
                    {
                        id: "habits",
                        icon: "habits",
                        label: "HÁBITOS"
                    },
                    {
                        id: "settings",
                        icon: "settings",
                        label: "AJUSTES"
                    }
                ]

                delegate: Button {
                    id: navButton
                    required property int index
                    required property var modelData
                    width: (navigationRow.width - navigationRow.spacing * 3) / 4
                    height: navigationRow.height
                    Accessible.id: "navigation-" + navButton.modelData.id
                    Accessible.name: navButton.modelData.label
                    onClicked: root.currentPage = navButton.index

                    background: Item {
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 28
                            height: 2
                            color: root.currentPage === navButton.index ? MobileTheme.accent : "transparent"
                        }
                    }

                    contentItem: Column {
                        topPadding: 10
                        spacing: 4

                        MobileIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20
                            height: 20
                            name: navButton.modelData.icon
                            color: root.currentPage === navButton.index ? MobileTheme.activeBorder : MobileTheme.subdued
                        }

                        Text {
                            width: parent.width
                            text: navButton.modelData.label
                            color: root.currentPage === navButton.index ? MobileTheme.foreground : MobileTheme.subdued
                            font.family: MobileTheme.fontFamily
                            font.pixelSize: 9
                            font.bold: root.currentPage === navButton.index
                            font.letterSpacing: 0.7
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.controller.ready && root.controller.errorMessage === ""
        color: MobileTheme.background
        z: 30

        Column {
            anchors.centerIn: parent
            spacing: 12

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.parent.visible
            }

            Text {
                text: "Preparando seu waypoint…"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.bodySize
            }
        }
    }
}
