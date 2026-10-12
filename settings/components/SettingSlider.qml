import QtQuick

// Slider bound to one backend setting. Writes when you let go.
// Click the number to type a value instead.
Item {
    id: slider
    property string key: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    property real value: 0
    readonly property real ratio: to > from ? (value - from) / (to - from) : 0
    anchors.fill: parent

    function sync() {
        var v = backend.settings[key]
        if (v !== undefined && !sliderArea.pressed)
            value = v
    }
    function clamp(v) {
        v = Math.round((v - from) / step) * step + from
        return Math.max(from, Math.min(to, Number(v.toFixed(Math.max(decimals, 2)))))
    }
    function setFromX(x) {
        value = clamp(from + Math.max(0, Math.min(1, x / track.width)) * (to - from))
    }
    function commit() {
        if (!backend.setValue(key, value)) sync()
    }
    Component.onCompleted: {
        sync()
        for (var p = parent; p; p = p.parent)
            if (p.isSettingRow === true) { p.key = key; break }
    }
    Connections {
        target: backend
        function onSettingsChanged() { slider.sync() }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: valueBox.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: backend.palette.surface3
        Rectangle {
            width: track.width * slider.ratio
            height: parent.height
            radius: 3
            color: backend.palette.accent
        }
        Rectangle {
            x: track.width * slider.ratio - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: sliderArea.pressed ? 20 : 16; height: width; radius: width / 2
            color: backend.palette.text
            Behavior on width { NumberAnimation { duration: 80 } }
        }
    }
    MouseArea {
        id: sliderArea
        x: track.x - 8
        width: track.width + 16
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => slider.setFromX(mouse.x - 8)
        onPositionChanged: (mouse) => { if (pressed) slider.setFromX(mouse.x - 8) }
        onReleased: slider.commit()
    }

    Rectangle {
        id: valueBox
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 64; height: 28; radius: 8
        color: input.activeFocus ? backend.palette.surface2 : (valueArea.containsMouse ? backend.palette.surface2 : "transparent")
        Text {
            anchors.fill: parent; anchors.rightMargin: 8
            visible: !input.activeFocus
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: slider.value.toFixed(slider.decimals) + slider.suffix
            color: backend.palette.subtext
            font.pixelSize: 13
        }
        MouseArea {
            id: valueArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            visible: !input.activeFocus
            onClicked: { input.text = slider.value.toFixed(slider.decimals); input.forceActiveFocus(); input.selectAll() }
        }
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
            visible: activeFocus
            horizontalAlignment: TextInput.AlignRight
            verticalAlignment: TextInput.AlignVCenter
            color: backend.palette.text
            selectionColor: backend.palette.accent
            selectedTextColor: backend.palette.accentText
            font.pixelSize: 13
            selectByMouse: true
            validator: DoubleValidator {}
            onAccepted: {
                var v = parseFloat(text.replace(",", "."))
                if (!isNaN(v)) { slider.value = slider.clamp(v); slider.commit() }
                focus = false
            }
            Keys.onEscapePressed: focus = false
            onActiveFocusChanged: if (!activeFocus) slider.sync()
        }
    }
}
