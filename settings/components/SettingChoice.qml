import QtQuick

// Choice bound to one backend setting.
Item {
    id: sc
    property string key: ""
    property var options: []
    anchors.fill: parent
    Component.onCompleted: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingRow === true) { p.key = key; break }
    }
    Choice {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        options: sc.options
        current: backend.settings[sc.key]
        onChosen: (value) => backend.setValue(sc.key, value)
    }
}
