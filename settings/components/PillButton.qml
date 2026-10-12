import QtQuick

Rectangle {
    id: pill
    property string label: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked()
    implicitWidth: content.implicitWidth + 32
    implicitHeight: 36
    radius: height / 2
    color: primary ? (pillArea.containsMouse ? Qt.lighter(backend.palette.surface3, 1.2) : backend.palette.surface3)
                   : (pillArea.containsMouse ? backend.palette.surface2 : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: pill.icon !== "" && Ui.hasIcons
            glyph: pill.icon
            font.pixelSize: 12
            color: pill.danger ? Ui.danger : backend.palette.text
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: pill.label
            color: pill.danger ? Ui.danger : backend.palette.text
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: pillArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
