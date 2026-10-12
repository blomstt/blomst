import QtQuick

// A big on/off tile for the Home page.
Rectangle {
    id: tile
    property string key: ""
    property string label: ""
    property string hintOn: ""
    property string hintOff: ""
    property string icon: ""
    property bool invert: false
    readonly property bool on: (backend.settings[key] === true) !== invert
    height: 84
    radius: 16
    color: on ? backend.palette.accent : (tileArea.containsMouse ? backend.palette.surface2 : backend.palette.surface)
    Behavior on color { ColorAnimation { duration: 150 } }
    Icon {
        id: tileIcon
        x: 18; anchors.verticalCenter: parent.verticalCenter
        width: Ui.hasIcons ? 22 : 0
        glyph: tile.icon
        font.pixelSize: 18
        color: tile.on ? backend.palette.accentText : backend.palette.text
    }
    Column {
        anchors.left: tileIcon.right; anchors.leftMargin: Ui.hasIcons ? 14 : 0
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: tile.label; font.pixelSize: 15; color: tile.on ? backend.palette.accentText : backend.palette.text }
        Text { width: parent.width; elide: Text.ElideRight; text: tile.on ? tile.hintOn : tile.hintOff; font.pixelSize: 12
               color: tile.on ? backend.palette.accentText : backend.palette.subtext; opacity: tile.on ? 0.8 : 1 }
    }
    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: backend.setValue(tile.key, !(backend.settings[tile.key] === true))
    }
}
