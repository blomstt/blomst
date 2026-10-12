import QtQuick

// On/off switch bound to one backend setting. `invert` shows the opposite of the stored value.
Item {
    id: sw
    property string key: ""
    property bool invert: false
    readonly property bool checked: (backend.settings[key] === true) !== invert
    anchors.fill: parent
    Component.onCompleted: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingRow === true) { p.key = key; break }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 50; height: 28; radius: 14
        color: sw.checked ? backend.palette.accent : backend.palette.surface3
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            x: sw.checked ? parent.width - width - 4 : 4
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; radius: 10
            color: sw.checked ? backend.palette.accentText : backend.palette.text
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setValue(sw.key, !(backend.settings[sw.key] === true))
        }
    }
}
