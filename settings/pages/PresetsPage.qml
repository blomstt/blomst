import QtQuick
import QtQuick.Layouts
import "../components"

PageScroll {
    pageKey: "presets"
    title: "Presets"
    description: "A preset remembers the current wallpaper and every Appearance and Animations setting, so you can switch looks in one click."

    Card {
        RowLayout {
            width: parent.width
            spacing: 10
            Field {
                id: nameField
                Layout.preferredWidth: 180
                placeholder: "Name"
                onAccepted: saveButton.clicked()
            }
            Field {
                id: descField
                Layout.fillWidth: true
                placeholder: "Description (optional)"
                onAccepted: saveButton.clicked()
            }
            PillButton {
                id: saveButton
                label: "Save current look"
                icon: ""
                primary: true
                onClicked: {
                    if (backend.savePreset(nameField.text, descField.text)) {
                        nameField.text = ""
                        descField.text = ""
                    } else nameField.invalid = true
                }
            }
        }
        Connections { target: nameField.input; function onTextChanged() { nameField.invalid = false } }
    }

    Note {
        visible: backend.presets.length === 0
        topPadding: 30
        horizontalAlignment: Text.AlignHCenter
        text: "No presets yet. Set things up how you like, give it a name, and save."
    }

    Flow {
        id: presetFlow
        width: parent.width
        spacing: 14
        readonly property real cardWidth: Math.floor((width - spacing) / 2)

        Repeater {
            model: backend.presets
            Rectangle {
                id: card
                required property var modelData
                width: presetFlow.cardWidth
                height: cardColumn.implicitHeight
                radius: 14
                color: backend.palette.surface
                clip: true
                Column {
                    id: cardColumn
                    width: parent.width
                    Item {
                        width: parent.width
                        height: 60
                        Rectangle {
                            id: avatar
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 18
                            color: backend.palette.surface3
                            Text {
                                anchors.centerIn: parent
                                text: card.modelData.name.charAt(0).toUpperCase()
                                color: backend.palette.text
                                font.pixelSize: 15
                            }
                        }
                        Column {
                            anchors.left: avatar.right; anchors.leftMargin: 12
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            Text { width: parent.width; elide: Text.ElideRight; text: card.modelData.name; color: backend.palette.text; font.pixelSize: 15 }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: card.modelData.description !== "" ? card.modelData.description : "Saved preset"
                                color: backend.palette.subtext; font.pixelSize: 12
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.round(width * 0.44)
                        color: backend.palette.surface2
                        Image {
                            anchors.fill: parent
                            source: card.modelData.image
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 600
                            clip: true
                        }
                    }
                    Item {
                        width: parent.width
                        height: 56
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            PillButton {
                                id: removeButton
                                property bool armed: false
                                label: armed ? "Really remove?" : "Remove"
                                danger: armed
                                onClicked: {
                                    if (armed) backend.removePreset(card.modelData.name)
                                    else { armed = true; disarm.restart() }
                                }
                                Timer { id: disarm; interval: 3000; onTriggered: removeButton.armed = false }
                            }
                            PillButton { label: "Apply"; primary: true; onClicked: backend.applyPreset(card.modelData.name) }
                        }
                    }
                }
            }
        }
    }
}
