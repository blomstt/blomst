import QtQuick
import QtQuick.Layouts
import "../components"

PageScroll {
    id: appsPage
    pageKey: "apps"
    title: "Apps"
    description: "Which apps your shortcuts open, and where apps open."
    property string newScreen: "main"
    property int newWorkspace: 1
    property bool newFloating: false
    onVisibleChanged: if (visible) backend.refreshOpenApps()

    // Pick from installed apps or type any command
    component DefaultApp: Card {
        id: defaultApp
        property string key: ""
        property string label: ""
        property string hint: ""
        property var options: []
        Column {
            spacing: 2
            Text { text: defaultApp.label; color: backend.palette.text; font.pixelSize: 15 }
            Text { text: defaultApp.hint; color: backend.palette.subtext; font.pixelSize: 12 }
        }
        Flow {
            width: parent.width
            spacing: 6
            Choice {
                options: defaultApp.options
                current: backend.settings[defaultApp.key]
                onChosen: (value) => backend.setValue(defaultApp.key, value)
            }
        }
        RowLayout {
            width: parent.width
            spacing: 10
            Field {
                id: customField
                Layout.fillWidth: true
                placeholder: "Or type another command"
                onAccepted: setButton.clicked()
            }
            PillButton {
                id: setButton
                label: "Set"
                primary: true
                onClicked: {
                    if (customField.text.trim() !== "" && backend.setValue(defaultApp.key, customField.text.trim()))
                        customField.text = ""
                }
            }
        }
    }

    SectionTitle { text: "Default apps" }
    DefaultApp { key: "browser"; label: "Browser"; hint: "Opens with Super + B"; options: backend.browsers }
    DefaultApp { key: "terminal"; label: "Terminal"; hint: "Opens with Super + Enter"; options: backend.terminals }

    SectionTitle { text: "Where apps open" }
    Note { text: "Choose where an app opens, whether it opens floating instead of filling the screen, or both. Applies to windows opened from now on." }

    Card {
        Text { text: "Open right now (click to pick)"; color: backend.palette.subtext; font.pixelSize: 12 }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: backend.openApps
                PillButton {
                    required property var modelData
                    label: modelData
                    primary: true
                    onClicked: classField.text = modelData
                }
            }
            Text {
                visible: backend.openApps.length === 0
                text: "Nothing found. Type the app's window class below."
                color: backend.palette.subtext
                font.pixelSize: 13
            }
        }
        RowLayout {
            width: parent.width
            spacing: 10
            Field {
                id: classField
                Layout.fillWidth: true
                placeholder: "App (window class)"
                onAccepted: saveRule.clicked()
            }
            PillButton {
                id: saveRule
                label: "Save rule"
                primary: true
                onClicked: {
                    if (backend.addAppRule(classField.text, appsPage.newScreen, appsPage.newWorkspace, appsPage.newFloating))
                        classField.text = ""
                }
            }
        }
        Flow {
            width: parent.width
            spacing: 14
            Choice {
                options: [ { value: false, label: "Tiled" }, { value: true, label: "Floating" } ]
                current: appsPage.newFloating
                onChosen: (value) => appsPage.newFloating = value
            }
            Choice {
                options: [ { value: "any", label: "Any screen" }, { value: "main", label: "Main" }, { value: "second", label: "Second" } ]
                current: appsPage.newScreen
                onChosen: (value) => appsPage.newScreen = value
            }
            Choice {
                opacity: appsPage.newScreen === "any" ? 0.35 : 1
                options: [ { value: 1, label: "1" }, { value: 2, label: "2" }, { value: 3, label: "3" }, { value: 4, label: "4" }, { value: 5, label: "5" } ]
                current: appsPage.newWorkspace
                onChosen: (value) => appsPage.newWorkspace = value
            }
        }
        Text {
            visible: appsPage.newScreen === "any" && !appsPage.newFloating
            text: "Pick Floating, a screen, or both. Tiled on any screen is how apps already open."
            color: backend.palette.subtext
            font.pixelSize: 12
        }
    }

    Note {
        visible: backend.appRules.length === 0
        topPadding: 16
        horizontalAlignment: Text.AlignHCenter
        text: "No app rules yet."
    }

    Repeater {
        model: backend.appRules
        SettingRow {
            id: ruleRow
            required property var modelData
            title: modelData["class"]
            resettable: false
            hint: (modelData.floating ? "Floating" : "Tiled")
                  + (modelData.screen === "any" ? ", wherever you are"
                     : (modelData.screen === "second" ? ", second screen" : ", main screen") + ", workspace " + modelData.workspace)
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "Remove"
                icon: ""
                onClicked: backend.removeAppRule(ruleRow.modelData["class"])
            }
        }
    }
}
