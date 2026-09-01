import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    property string feedbackMessage: ""
    property bool feedbackError: false

    function loadConfiguration() {
        if (!serverField.activeFocus)
            serverField.text = controller.syncEndpoint;
    }

    function stateLabel() {
        if (controller.syncState === "syncing")
            return "Sincronizando";
        if (controller.syncState === "ready")
            return "Conectado";
        if (controller.syncState === "error")
            return "Erro de sincronização";
        return "Somente local";
    }

    function stateColor() {
        if (controller.syncState === "ready")
            return "#81d39a";
        if (controller.syncState === "syncing")
            return "#a997ff";
        if (controller.syncState === "error")
            return "#ff7085";
        return "#777780";
    }

    Component.onCompleted: loadConfiguration()

    Connections {
        target: root.controller
        function onSyncConfigurationChanged() {
            root.loadConfiguration();
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: Math.min(parent.width - 96, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item {
                Layout.preferredHeight: 38
            }

            Text {
                text: "Configurações"
                color: "#f2f0f5"
                font.pixelSize: 30
                font.bold: true
            }

            Text {
                text: "Conecte este dispositivo ao seu servidor Waypoint self-hosted."
                color: "#92909a"
                font.pixelSize: 14
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusColumn.implicitHeight + 32
                radius: 12
                color: "#0d0d10"
                border.width: 1
                border.color: "#222228"

                ColumnLayout {
                    id: statusColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 9
                            Layout.preferredHeight: 9
                            radius: 5
                            color: root.stateColor()
                        }

                        Text {
                            text: root.stateLabel()
                            color: "#f2f0f5"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.controller.lastSuccessfulSync !== ""
                            text: "Última sincronização: " + Qt.formatDateTime(new Date(root.controller.lastSuccessfulSync), "dd/MM/yyyy HH:mm")
                            color: "#777780"
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.controller.syncLastError !== ""
                        text: root.controller.syncLastError
                        color: "#ff8395"
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Servidor"
                    color: "#d8d5de"
                    font.pixelSize: 13
                    font.bold: true
                }

                TextField {
                    id: serverField
                    Layout.fillWidth: true
                    placeholderText: "https://waypoint.exemplo.com"
                    color: "#f2f0f5"
                    placeholderTextColor: "#65636c"
                    selectByMouse: true
                    background: Rectangle {
                        implicitHeight: 46
                        radius: 8
                        color: "#111114"
                        border.width: serverField.activeFocus ? 1 : 0
                        border.color: "#a997ff"
                    }
                }

                Text {
                    text: "Informe a URL base ou o endpoint /v1/sync."
                    color: "#65636c"
                    font.pixelSize: 11
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Token de acesso"
                    color: "#d8d5de"
                    font.pixelSize: 13
                    font.bold: true
                }

                TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    placeholderText: root.controller.syncConfigured ? "Deixe vazio para manter o token atual" : "Cole o token configurado no servidor"
                    echoMode: TextInput.Password
                    color: "#f2f0f5"
                    placeholderTextColor: "#65636c"
                    selectByMouse: true
                    background: Rectangle {
                        implicitHeight: 46
                        radius: 8
                        color: "#111114"
                        border.width: tokenField.activeFocus ? 1 : 0
                        border.color: "#a997ff"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    text: "Salvar e sincronizar"
                    enabled: serverField.text.trim() !== ""
                    onClicked: {
                        const saved = root.controller.saveSyncConfiguration(serverField.text, tokenField.text);
                        root.feedbackError = !saved;
                        root.feedbackMessage = saved ? "Configuração salva. Verificando a sincronização…" : root.controller.errorMessage;
                        if (saved)
                            tokenField.clear();
                    }
                }

                Button {
                    text: "Sincronizar agora"
                    enabled: root.controller.syncConfigured && root.controller.syncState !== "syncing"
                    onClicked: {
                        const started = root.controller.syncNow();
                        root.feedbackError = !started;
                        root.feedbackMessage = started ? "Sincronização iniciada." : root.controller.errorMessage;
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "Usar somente local"
                    visible: root.controller.syncConfigured
                    onClicked: {
                        const disabled = root.controller.disableRemoteSync();
                        root.feedbackError = !disabled;
                        root.feedbackMessage = disabled ? "Sincronização remota desativada." : root.controller.errorMessage;
                        if (disabled) {
                            serverField.clear();
                            tokenField.clear();
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.feedbackMessage !== ""
                text: root.feedbackMessage
                color: root.feedbackError ? "#ff8395" : "#81d39a"
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }

            Text {
                Layout.fillWidth: true
                text: "A connection string do PostgreSQL permanece somente no servidor. Este dispositivo armazena apenas o endpoint e o token necessários para falar com a API."
                color: "#65636c"
                wrapMode: Text.Wrap
                font.pixelSize: 11
            }

            Item {
                Layout.preferredHeight: 38
            }
        }
    }
}
