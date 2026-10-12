import QtQuick

Rectangle {
    id: nav
    property string label: ""
    property string key: ""
    property string icon: ""
    readonly property bool active: Ui.page === key && Ui.query === ""
    width: parent ? parent.width : 200
    height: 38
    radius: 12
    color: active ? backend.palette.surface2 : (navArea.containsMouse ? backend.palette.surface : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
        visible: nav.active
        width: 4; height: 16; radius: 2
        anchors.left: parent.left; anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        color: backend.palette.accent
    }
    Icon {
        id: navIcon
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: Ui.hasIcons ? 18 : 0
        glyph: nav.icon
        font.pixelSize: 13
        color: nav.active ? backend.palette.accent : backend.palette.subtext
    }
    Text {
        anchors.left: navIcon.right; anchors.leftMargin: Ui.hasIcons ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: nav.label
        color: nav.active ? backend.palette.text : backend.palette.subtext
        font.pixelSize: 14
    }
    MouseArea {
        id: navArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Ui.query = ""; Ui.page = nav.key }
    }
}
