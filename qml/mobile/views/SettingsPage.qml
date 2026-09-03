pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    property string feedback: ""
    property bool feedbackError: false
    readonly property var brazilianStates: [
        {
            code: "",
            name: "Nenhum estado"
        },
        {
            code: "AC",
            name: "Acre"
        },
        {
            code: "AL",
            name: "Alagoas"
        },
        {
            code: "AP",
            name: "Amapá"
        },
        {
            code: "AM",
            name: "Amazonas"
        },
        {
            code: "BA",
            name: "Bahia"
        },
        {
            code: "CE",
            name: "Ceará"
        },
        {
            code: "DF",
            name: "Distrito Federal"
        },
        {
            code: "ES",
            name: "Espírito Santo"
        },
        {
            code: "GO",
            name: "Goiás"
        },
        {
            code: "MA",
            name: "Maranhão"
        },
        {
            code: "MT",
            name: "Mato Grosso"
        },
        {
            code: "MS",
            name: "Mato Grosso do Sul"
        },
        {
            code: "MG",
            name: "Minas Gerais"
        },
        {
            code: "PA",
            name: "Pará"
        },
        {
            code: "PB",
            name: "Paraíba"
        },
        {
            code: "PR",
            name: "Paraná"
        },
        {
            code: "PE",
            name: "Pernambuco"
        },
        {
            code: "PI",
            name: "Piauí"
        },
        {
            code: "RJ",
            name: "Rio de Janeiro"
        },
        {
            code: "RN",
            name: "Rio Grande do Norte"
        },
        {
            code: "RS",
            name: "Rio Grande do Sul"
        },
        {
            code: "RO",
            name: "Rondônia"
        },
        {
            code: "RR",
            name: "Roraima"
        },
        {
            code: "SC",
            name: "Santa Catarina"
        },
        {
            code: "SP",
            name: "São Paulo"
        },
        {
            code: "SE",
            name: "Sergipe"
        },
        {
            code: "TO",
            name: "Tocantins"
        }
    ]

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
            return MobileTheme.success;
        if (controller.syncState === "syncing")
            return MobileTheme.accent;
        if (controller.syncState === "error")
            return MobileTheme.urgent;
        return MobileTheme.subdued;
    }

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
        const preferences = controller.holidayPreferences || {};
        const stateCode = preferences.stateCode || "";
        stateField.currentIndex = stateIndex(stateCode);
        nationalCheck.checked = preferences.includeNational !== false;
        stateCheck.checked = preferences.includeState !== false;
        municipalCheck.checked = preferences.includeMunicipal !== false;
        commemorativeCheck.checked = preferences.includeCommemorative === true;
        optionalCheck.checked = preferences.includeOptional === true;
        if (stateCode !== "")
            controller.loadMunicipalities(stateCode);
        cityField.currentIndex = cityIndex(preferences.cityCode || "");
    }

    function loadConfiguration() {
        if (!endpointField.activeFocus)
            endpointField.text = controller.syncEndpoint;
        loadHolidayConfiguration();
    }

    Component.onCompleted: loadConfiguration()

    Connections {
        target: root.controller

        function onSyncConfigurationChanged() {
            root.loadConfiguration();
        }

        function onHolidayPreferencesChanged() {
            root.loadHolidayConfiguration();
        }

        function onMunicipalitiesChanged() {
            const preferences = root.controller.holidayPreferences || {};
            cityField.currentIndex = root.cityIndex(preferences.cityCode || "");
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: Math.max(0, parent.width - MobileTheme.pageMargin * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Item {
                Layout.preferredHeight: 18
            }

            Text {
                text: "Configurações"
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.displaySize
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "LOCAL-FIRST  ·  SINCRONIZA QUANDO DISPONÍVEL"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                font.letterSpacing: 0.7
                wrapMode: Text.Wrap
            }

            SectionCard {
                Layout.fillWidth: true
                contentSpacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: root.stateColor()
                    }

                    Text {
                        text: root.stateLabel().toUpperCase()
                        Accessible.id: "sync-status"
                        Accessible.name: root.stateLabel()
                        color: root.stateColor()
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.controller.lastSuccessfulSync !== ""
                        text: root.controller.lastSuccessfulSync === "" ? "" : Qt.formatDateTime(new Date(root.controller.lastSuccessfulSync), "dd/MM HH:mm")
                        color: MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.controller.syncLastError !== ""
                    text: root.controller.syncLastError
                    Accessible.id: "sync-error"
                    Accessible.name: text
                    color: MobileTheme.urgent
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    wrapMode: Text.Wrap
                }
            }

            Text {
                text: "SERVIDOR SELF-HOSTED"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                font.bold: true
                font.letterSpacing: 1
            }

            MobileField {
                id: endpointField
                Layout.fillWidth: true
                placeholderText: "https://waypoint.exemplo.com"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                Accessible.id: "sync-endpoint"
                Accessible.name: "Endpoint de sincronização"
            }

            MobileField {
                id: tokenField
                Layout.fillWidth: true
                placeholderText: root.controller.syncConfigured ? "Token salvo — deixe vazio para manter" : "Bearer token"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                Accessible.id: "sync-token"
                Accessible.name: "Bearer token de sincronização"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MobileButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    text: "SALVAR"
                    accent: true
                    Accessible.id: "save-sync-configuration"
                    onClicked: {
                        const succeeded = root.controller.saveSyncConfiguration(endpointField.text, tokenField.text);
                        root.feedbackError = !succeeded;
                        root.feedback = succeeded ? "Configuração salva neste aparelho." : "Não foi possível salvar.";
                        if (succeeded)
                            tokenField.text = "";
                    }
                }

                MobileButton {
                    Layout.preferredHeight: 44
                    text: "SINCRONIZAR"
                    enabled: root.controller.syncConfigured
                    Accessible.id: "sync-now"
                    onClicked: root.controller.syncNow()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Use HTTPS: o Bearer token dá acesso total à sua instância."
                color: MobileTheme.warning
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                wrapMode: Text.Wrap
            }

            Text {
                text: "FERIADOS DO BRASIL"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                font.bold: true
                font.letterSpacing: 1
                Layout.topMargin: 8
            }

            MobileComboBox {
                id: stateField
                Layout.fillWidth: true
                model: root.brazilianStates
                textRole: "name"
                valueRole: "code"
                Accessible.id: "holiday-state"
                Accessible.name: "Estado para feriados"
                onActivated: {
                    cityField.currentIndex = -1;
                    root.controller.loadMunicipalities(currentValue);
                }
            }

            MobileComboBox {
                id: cityField
                Layout.fillWidth: true
                enabled: stateField.currentValue !== ""
                model: root.controller.municipalities
                textRole: "name"
                valueRole: "code"
                displayText: currentIndex >= 0 ? currentText : "Selecione o município"
                Accessible.id: "holiday-city"
                Accessible.name: "Município para feriados"
            }

            SectionCard {
                Layout.fillWidth: true

                MobileCheck {
                    id: nationalCheck
                    Layout.fillWidth: true
                    text: "Feriados nacionais"
                }

                MobileCheck {
                    id: stateCheck
                    Layout.fillWidth: true
                    text: "Feriados estaduais"
                    enabled: stateField.currentValue !== ""
                }

                MobileCheck {
                    id: municipalCheck
                    Layout.fillWidth: true
                    text: "Feriados municipais"
                    enabled: cityField.currentIndex >= 0
                }

                MobileCheck {
                    id: commemorativeCheck
                    Layout.fillWidth: true
                    text: "Datas comemorativas"
                }

                MobileCheck {
                    id: optionalCheck
                    Layout.fillWidth: true
                    text: "Pontos facultativos"
                }
            }

            MobileButton {
                Layout.fillWidth: true
                text: "SALVAR FERIADOS"
                onClicked: {
                    const cityCode = cityField.currentIndex >= 0 ? cityField.currentValue : "";
                    const succeeded = root.controller.saveHolidayPreferences(stateField.currentValue, cityCode, nationalCheck.checked, stateCheck.checked, municipalCheck.checked, commemorativeCheck.checked, optionalCheck.checked);
                    root.feedbackError = !succeeded;
                    root.feedback = succeeded ? "Preferências de feriados salvas." : "Não foi possível salvar.";
                }
            }

            Text {
                text: "APLICATIVO"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                font.bold: true
                font.letterSpacing: 1
                Layout.topMargin: 8
            }

            SectionCard {
                Layout.fillWidth: true
                contentSpacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Waypoint v" + root.controller.currentVersion
                            color: MobileTheme.foreground
                            font.family: MobileTheme.fontFamily
                            font.pixelSize: MobileTheme.bodySize
                            font.bold: true
                        }

                        Text {
                            visible: root.controller.updateState === "available"
                                     || root.controller.updateState === "downloading"
                                     || root.controller.updateState === "waiting-for-android"
                            text: root.controller.updateState === "available"
                                  ? "Versão " + root.controller.latestVersion + " disponível"
                                  : root.controller.updateState === "downloading"
                                    ? "Baixando · " + Math.round(root.controller.updateProgress * 100) + "%"
                                    : "Instalação aguardando confirmação"
                            color: MobileTheme.subdued
                            font.family: MobileTheme.fontFamily
                            font.pixelSize: MobileTheme.captionSize
                        }
                    }

                    MobileButton {
                        visible: (root.controller.updateState === "available"
                                  && root.controller.canInstallUpdate)
                                 || root.controller.updateState === "waiting-for-android"
                        text: root.controller.updateState === "waiting-for-android"
                              ? "ABRIR INSTALADOR" : "ATUALIZAR"
                        accent: true
                        Accessible.id: "install-update"
                        onClicked: {
                            const started = root.controller.installUpdate();
                            root.feedbackError = !started;
                            root.feedback = started ? "" : root.controller.errorMessage;
                        }
                    }

                    MobileButton {
                        visible: root.controller.updateState !== "available"
                                 && root.controller.updateState !== "downloading"
                                 && root.controller.updateState !== "waiting-for-android"
                        text: root.controller.updateState === "checking" ? "VERIFICANDO…" : "VERIFICAR"
                        enabled: root.controller.updateState !== "checking"
                        Accessible.id: "check-update"
                        onClicked: root.controller.checkForUpdate()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.controller.updateError !== ""
                    text: root.controller.updateError
                    color: MobileTheme.urgent
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    wrapMode: Text.Wrap
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.feedback !== ""
                text: root.feedback
                color: root.feedbackError ? MobileTheme.urgent : MobileTheme.success
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: "Lembretes precisam das permissões de notificações e alarmes exatos do Android. Se negar, o sistema poderá atrasá-los."
                color: MobileTheme.disabled
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
                wrapMode: Text.Wrap
                Layout.bottomMargin: 24
            }
        }
    }
}
