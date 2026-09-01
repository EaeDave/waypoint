import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

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
        optionalCheck.checked = controller.includeOptionalDates;
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
            return WaypointTheme.success;
        if (controller.syncState === "syncing")
            return WaypointTheme.accent;
        if (controller.syncState === "error")
            return WaypointTheme.urgent;
        return WaypointTheme.subduedText;
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
            width: Math.min(parent.width - 68, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Item {
                Layout.preferredHeight: 24
            }

            Text {
                text: "Configurações"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.displayLargeSize
                font.bold: true
            }

            Text {
                text: "Conecte este dispositivo ao seu servidor Waypoint self-hosted."
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusColumn.implicitHeight + 28
                radius: WaypointTheme.radius
                color: WaypointTheme.controlFill
                border.width: 1
                border.color: WaypointTheme.controlBorder

                ColumnLayout {
                    id: statusColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.stateColor()
                        }

                        Text {
                            text: root.stateLabel()
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.subtitleSize
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.controller.lastSuccessfulSync !== ""
                            text: "Última sincronização: " + Qt.formatDateTime(new Date(root.controller.lastSuccessfulSync), "dd/MM/yyyy HH:mm")
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.captionSize
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.controller.syncLastError !== ""
                        text: root.controller.syncLastError
                        color: WaypointTheme.urgent
                        wrapMode: Text.Wrap
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: syncColumn.implicitHeight + 28
                radius: WaypointTheme.radius
                color: WaypointTheme.surface
                border.width: 1
                border.color: WaypointTheme.divider

                ColumnLayout {
                    id: syncColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "SINCRONIZAÇÃO"
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.titleSize
                        font.bold: true
                    }

                    Text {
                        text: "Servidor"
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }

                    AppTextField {
                        id: serverField
                        Layout.fillWidth: true
                        placeholderText: "https://waypoint.exemplo.com"
                    }

                    Text {
                        text: "Informe a URL base ou o endpoint /v1/sync."
                        color: WaypointTheme.disabledText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.captionSize
                    }

                    Text {
                        text: "Token de acesso"
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }

                    AppTextField {
                        id: tokenField
                        Layout.fillWidth: true
                        placeholderText: root.controller.syncConfigured ? "Deixe vazio para manter o token atual" : "Cole o token configurado no servidor"
                        echoMode: TextInput.Password
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppButton {
                            text: "Salvar e sincronizar"
                            selected: true
                            enabled: serverField.text.trim() !== ""
                            onClicked: {
                                const saved = root.controller.saveSyncConfiguration(serverField.text, tokenField.text);
                                root.feedbackError = !saved;
                                root.feedbackMessage = saved ? "Configuração salva. Verificando a sincronização…" : root.controller.errorMessage;
                                if (saved)
                                    tokenField.clear();
                            }
                        }

                        AppButton {
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

                        AppButton {
                            text: "Usar somente local"
                            destructive: true
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
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: holidayColumn.implicitHeight + 28
                radius: WaypointTheme.radius
                color: WaypointTheme.surface
                border.width: 1
                border.color: WaypointTheme.divider

                ColumnLayout {
                    id: holidayColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "FERIADOS BRASILEIROS"
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.titleSize
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Os eventos ficam no cache local e continuam visíveis sem conexão."
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppComboBox {
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

                        AppComboBox {
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
                        rowSpacing: 8

                        AppCheckBox {
                            id: nationalCheck
                            text: "Feriados nacionais"
                        }
                        AppCheckBox {
                            id: stateCheck
                            text: "Feriados estaduais"
                            enabled: stateField.currentValue !== ""
                        }
                        AppCheckBox {
                            id: municipalCheck
                            text: "Feriados municipais"
                            enabled: cityField.currentIndex >= 0
                        }
                        AppCheckBox {
                            id: optionalCheck
                            text: "Pontos facultativos"
                        }
                        AppCheckBox {
                            id: commemorativeCheck
                            text: "Datas comemorativas"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppButton {
                            text: "Salvar feriados"
                            selected: true
                            onClicked: {
                                const cityCode = cityField.currentIndex >= 0 ? cityField.currentValue : "";
                                const saved = root.controller.saveHolidayPreferences(
                                    stateField.currentValue,
                                    cityCode,
                                    nationalCheck.checked,
                                    stateCheck.checked,
                                    municipalCheck.checked,
                                    commemorativeCheck.checked,
                                    optionalCheck.checked);
                                root.feedbackError = !saved;
                                root.feedbackMessage = saved ? "Preferências de feriados salvas." : root.controller.errorMessage;
                            }
                        }

                        AppButton {
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
                                  root.controller.holidaySyncState === "partial" ? "Cobertura parcial" :
                                  root.controller.holidaySyncState === "ready" ? "Atualizado" :
                                  root.controller.holidaySyncState === "syncing" ? "Atualizando…" : "Somente local"
                            color: root.controller.holidaySyncState === "offline" ? WaypointTheme.warning :
                                   root.controller.holidaySyncState === "partial" ? WaypointTheme.warning :
                                   root.controller.holidaySyncState === "ready" ? WaypointTheme.success : WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.controller.holidaySyncLastError !== ""
                        text: root.controller.holidaySyncLastError
                        color: WaypointTheme.urgent
                        wrapMode: Text.Wrap
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.feedbackMessage !== ""
                text: root.feedbackMessage
                color: root.feedbackError ? WaypointTheme.urgent : WaypointTheme.success
                wrapMode: Text.Wrap
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
            }

            Text {
                Layout.fillWidth: true
                text: "A connection string do PostgreSQL permanece somente no servidor. Este dispositivo armazena apenas o endpoint e o token necessários para falar com a API."
                color: WaypointTheme.disabledText
                wrapMode: Text.Wrap
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
            }

            Item {
                Layout.preferredHeight: 24
            }
        }
    }
}
