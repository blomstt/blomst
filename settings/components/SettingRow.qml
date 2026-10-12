import QtQuick

// One row of a settings page: title and hint on the left, a control on the right.
// The control tells the row which setting it edits (key), which turns on the reset button.
Rectangle {
    id: row
    property string title: ""
    property string hint: ""
    property string section: ""
    property string key: ""
    property bool resettable: true
    readonly property bool isSettingRow: true
    property string pageKey: ""
    property var pageScroll: null
    default property alias control: controlSlot.data

    readonly property bool changedFromDefault: resettable && key !== "" && backend.defaults[key] !== undefined
                                               && backend.settings[key] !== undefined
                                               && String(backend.settings[key]) !== String(backend.defaults[key])

    width: parent ? parent.width : 600
    height: 64
    radius: 14
    color: backend.palette.surface
    border.width: 2
    border.color: "transparent"

    function flash() { flashAnim.restart() }
    SequentialAnimation {
        id: flashAnim
        ColorAnimation { target: row; property: "border.color"; to: backend.palette.accent; duration: 150 }
        PauseAnimation { duration: 900 }
        ColorAnimation { target: row; property: "border.color"; to: "transparent"; duration: 500 }
    }

    Component.onCompleted: {
        for (var p = parent; p; p = p.parent) {
            if (p.isPage === true) { pageKey = p.pageKey; pageScroll = p; break }
        }
        Ui.register(row)
    }
    Component.onDestruction: Ui.unregister(row)

    Column {
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.right: resetButton.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: row.title; color: backend.palette.text; font.pixelSize: 15 }
        Text { width: parent.width; elide: Text.ElideRight; text: row.hint; visible: row.hint !== ""; color: backend.palette.subtext; font.pixelSize: 12 }
    }

    // Back to default
    Rectangle {
        id: resetButton
        anchors.right: controlSlot.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: row.changedFromDefault ? 28 : 0
        height: 28; radius: 14
        visible: row.changedFromDefault
        color: resetArea.containsMouse ? backend.palette.surface3 : "transparent"
        Icon { anchors.centerIn: parent; glyph: ""; font.pixelSize: 11; visible: Ui.hasIcons }
        Text { anchors.centerIn: parent; text: "↺"; visible: !Ui.hasIcons; color: backend.palette.subtext }
        MouseArea {
            id: resetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.resetValue(row.key)
        }
        Rectangle {
            visible: resetArea.containsMouse
            anchors.bottom: parent.top; anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: tip.implicitWidth + 16; height: 24; radius: 8
            color: backend.palette.surface3
            Text { id: tip; anchors.centerIn: parent; text: "Reset to " + String(backend.defaults[row.key]); color: backend.palette.text; font.pixelSize: 11 }
        }
    }

    Item {
        id: controlSlot
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        height: 32
    }
}
