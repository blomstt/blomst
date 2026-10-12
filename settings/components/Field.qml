import QtQuick

Rectangle {
    id: field
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool invalid: false
    signal accepted()
    implicitWidth: 160
    implicitHeight: 40
    radius: 12
    color: backend.palette.surface2
    border.width: invalid || input.activeFocus ? 1 : 0
    border.color: invalid ? Ui.danger : backend.palette.surface3
    function focusInput() { input.forceActiveFocus(); input.selectAll() }
    Icon {
        id: fieldIcon
        visible: field.icon !== "" && Ui.hasIcons
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        glyph: field.icon
        font.pixelSize: 12
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: fieldIcon.visible ? 36 : 14; anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: backend.palette.text
        selectionColor: backend.palette.accent
        selectedTextColor: backend.palette.accentText
        font.pixelSize: 14
        clip: true
        selectByMouse: true
        onAccepted: field.accepted()
    }
    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === ""
        text: field.placeholder
        color: backend.palette.subtext
        font.pixelSize: 14
        elide: Text.ElideRight
    }
}
