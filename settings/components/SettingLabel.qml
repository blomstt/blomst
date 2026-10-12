import QtQuick

// Shows a setting's current value on the right of a row (for settings picked elsewhere on the page).
Item {
    id: label
    property string key: ""
    property alias text: valueText.text
    property alias fontFamily: valueText.font.family
    anchors.fill: parent
    Component.onCompleted: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingRow === true) { p.key = key; break }
    }
    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: String(backend.settings[label.key])
        color: backend.palette.text
        font.pixelSize: 15
    }
}
