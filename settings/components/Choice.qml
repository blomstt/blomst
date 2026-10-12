import QtQuick

// A row of pills where one is selected. Not tied to the backend by itself.
Row {
    id: choice
    property var options: []
    property var current
    signal chosen(var value)
    spacing: 4
    Repeater {
        model: choice.options
        Rectangle {
            id: opt
            required property var modelData
            readonly property bool active: String(choice.current) === String(modelData.value)
            width: optText.implicitWidth + 24
            height: 32
            radius: 16
            color: active ? backend.palette.accent
                          : (optArea.containsMouse ? backend.palette.surface3 : backend.palette.surface2)
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                id: optText
                anchors.centerIn: parent
                text: opt.modelData.label
                color: opt.active ? backend.palette.accentText : backend.palette.text
                font.pixelSize: 13
            }
            MouseArea {
                id: optArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: choice.chosen(opt.modelData.value)
            }
        }
    }
}
