import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    property string feedbackMessage: ""
    property bool feedbackError: false
    readonly property var brazilianStates: [
        { code: "", name: "Nenhum estado" },
        { code: "AC", name: "Acre" }, { code: "AL", name: "Alagoas" },
        { code: "AP", name: "Amapá" }, { code: "AM", name: "Amazonas" },
        { code: "BA", name: "Bahia" }, { code: "CE", name: "Ceará" },
        { code: "DF", name: "Distrito Federal" }, { code: "ES", name: "Espírito Santo" },
        { code: "GO", name: "Goiás" }, { code: "MA", name: "Maranhão" },
        { code: "MT", name: "Mato Grosso" }, { code: "MS", name: "Mato Grosso do Sul" },
        { code: "MG", name: "Minas Gerais" }, { code: "PA", name: "Pará" },
        { code: "PB", name: "Paraíba" }, { code: "PR", name: "Paraná" },
        { code: "PE", name: "Pernambuco" }, { code: "PI", name: "Piauí" },
        { code: "RJ", name: "Rio de Janeiro" }, { code: "RN", name: "Rio Grande do Norte" },
        { code: "RS", name: "Rio Grande do Sul" }, { code: "RO", name: "Rondônia" },
        { code: "RR", name: "Roraima" }, { code: "SC", name: "Santa Catarina" },
        { code: "SP", name: "São Paulo" }, { code: "SE", name: "Sergipe" },
        { code: "TO", name: "Tocantins" }
    ]

    function stateIndex(code) {
        for (let index = 0; index < brazilianStates.length; ++index) {
            if (brazilianStates[index].code === code)
                return index;
        }
        return 0;
    }

    function cityIndex(code) {
        for (let index = 0; index < cityField.count; ++index) {
            if (cityField.valueAt(index) === code)
                return index;
        }
        return -1;
    }

    function loadHolidayConfiguration() {
        stateField.currentIndex = stateIndex(controller.holidayStateCode);
        nationalCheck.checked = controller.includeNationalHolidays;
        stateCheck.checked = controller.includeStateHolidays;
        municipalCheck.checked = controller.includeMunicipalHolidays;
        commemorativeCheck.checked = controller.includeCommemorativeDates;
        if (controller.holidayStateCode !== "")
            controller.loadMunicipalities(controller.holidayStateCode);
        cityField.currentIndex = cityIndex(controller.holidayCityCode);
    }

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

    Component.onCompleted: {
        loadConfiguration();
        loadHolidayConfiguration();
    }

    Connections {
        target: root.controller
        function onSyncConfigurationChanged() {
            root.loadConfiguration();
        }
        function onHolidayConfigurationChanged() {
            root.loadHolidayConfiguration();
        }
        function onMunicipalitiesChanged() {
            cityField.currentIndex = root.cityIndex(root.controller.holidayCityCode);
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: holidayColumn.implicitHeight + 32
                radius: 12
                color: "#0d0d10"
                border.width: 1
                border.color: "#222228"

                ColumnLayout {
                    id: holidayColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Feriados brasileiros"
                        color: "#f2f0f5"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Os eventos ficam no cache local e continuam visíveis sem conexão."
                        color: "#777780"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ComboBox {
                            id: stateField
                            Layout.fillWidth: true
                            model: root.brazilianStates
                            textRole: "name"
                            valueRole: "code"
                            onActivated: {
                                cityField.currentIndex = -1;
                                if (currentValue !== "")
                                    root.controller.loadMunicipalities(currentValue);
                            }
                        }

                        ComboBox {
                            id: cityField
                            Layout.fillWidth: true
                            enabled: stateField.currentValue !== ""
                            model: root.controller.municipalities
                            textRole: "name"
                            valueRole: "code"
                            displayText: currentIndex >= 0 ? currentText : "Selecione o município"
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 24

                        CheckBox {
                            id: nationalCheck
                            text: "Feriados nacionais"
                            palette.windowText: "#d8d5de"
                        }
                        CheckBox {
                            id: stateCheck
                            text: "Feriados estaduais"
                            palette.windowText: enabled ? "#d8d5de" : "#65636c"
                            enabled: stateField.currentValue !== ""
                        }
                        CheckBox {
                            id: municipalCheck
                            text: "Feriados municipais"
                            palette.windowText: enabled ? "#d8d5de" : "#65636c"
                            enabled: cityField.currentIndex >= 0
                        }
                        CheckBox {
                            id: commemorativeCheck
                            text: "Datas comemorativas"
                            palette.windowText: "#d8d5de"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: "Salvar feriados"
                            onClicked: {
                                const cityCode = cityField.currentIndex >= 0 ? cityField.currentValue : "";
                                const saved = root.controller.saveHolidayPreferences(
                                    stateField.currentValue,
                                    cityCode,
                                    nationalCheck.checked,
                                    stateCheck.checked,
                                    municipalCheck.checked,
                                    commemorativeCheck.checked);
                                root.feedbackError = !saved;
                                root.feedbackMessage = saved ? "Preferências de feriados salvas." : root.controller.errorMessage;
                            }
                        }

                        Button {
                            text: "Atualizar feriados"
                            enabled: root.controller.syncConfigured && root.controller.holidaySyncState !== "syncing"
                            onClicked: {
                                const started = root.controller.refreshHolidays();
                                root.feedbackError = !started;
                                root.feedbackMessage = started ? "Atualização de feriados iniciada." : root.controller.errorMessage;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.controller.holidaySyncState === "offline" ? "Cache offline" :
                                  root.controller.holidaySyncState === "ready" ? "Atualizado" :
                                  root.controller.holidaySyncState === "syncing" ? "Atualizando…" : "Somente local"
                            color: root.controller.holidaySyncState === "offline" ? "#ffb86c" :
                                   root.controller.holidaySyncState === "ready" ? "#81d39a" : "#777780"
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.controller.holidaySyncLastError !== ""
                        text: root.controller.holidaySyncLastError
                        color: "#ff8395"
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
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
