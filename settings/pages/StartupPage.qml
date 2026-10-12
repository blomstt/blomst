import QtQuick
import QtQuick.Layouts
import "../components"

PageScroll {
    pageKey: "startup"
    title: "Startup"
    description: "Apps and commands that start when you log in. Adding one also starts it right away."

    Card {
        RowLayout {
            width: parent.width
            spacing: 10
            Field {
                id: commandField
                Layout.fillWidth: true
                icon: ""
                placeholder: "Command, for example discord or obsidian"
                onAccepted: addButton.clicked()
            }
            PillButton {
                id: addButton
                label: "Add"
                icon: "+"
                primary: true
                onClicked: {
                    if (backend.addAutostart(commandField.text)) commandField.text = ""
                    else commandField.invalid = commandField.text.trim() !== ""
                }
            }
        }
        Text {
            visible: commandField.invalid
            text: "Already on the list."
            color: Ui.danger
            font.pixelSize: 12
        }
        Connections { target: commandField.input; function onTextChanged() { commandField.invalid = false } }
    }

    Note {
        visible: backend.autostart.length === 0
        topPadding: 24
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing starts at login yet. The bar, wallpaper and idle services start on their own and are not listed."
    }

    Repeater {
        model: backend.autostart
        SettingRow {
            id: startRow
            required property var modelData
            title: modelData
            hint: "Starts at login"
            resettable: false
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "Remove"
                icon: ""
                onClicked: backend.removeAutostart(startRow.modelData)
            }
        }
    }
}
