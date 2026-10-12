import QtQuick
import QtQuick.Layouts
import "../components"

PageScroll {
    pageKey: "input"
    title: "Keyboard & mouse"
    description: "Typing and pointer settings. They apply as soon as you change them."

    SectionTitle { text: "Keyboard" }
    Card {
        id: layoutCard
        property string filter: ""
        readonly property var matches: {
            var q = filter.trim().toLowerCase(), out = []
            if (q === "") return out
            var all = backend.kbLayouts
            for (var i = 0; i < all.length && out.length < 8; i++)
                if (all[i].value.indexOf(q) === 0 || all[i].label.toLowerCase().indexOf(q) >= 0) out.push(all[i])
            return out
        }
        function nameOf(code) {
            var all = backend.kbLayouts
            for (var i = 0; i < all.length; i++) if (all[i].value === code) return all[i].label
            return code
        }
        function add(code) {
            var current = String(backend.settings.kb_layout || "").split(",").filter(function(c) { return c.trim() !== "" })
            if (current.indexOf(code) < 0) current.push(code)
            backend.setValue("kb_layout", current.join(","))
            layoutSearch.text = ""
        }
        function remove(code) {
            var current = String(backend.settings.kb_layout || "").split(",").filter(function(c) { return c.trim() !== "" && c !== code })
            if (current.length) backend.setValue("kb_layout", current.join(","))
        }

        Column {
            spacing: 2
            Text { text: "Keyboard layouts"; color: backend.palette.text; font.pixelSize: 15 }
            Text { text: "With more than one, the first is used at login"; color: backend.palette.subtext; font.pixelSize: 12 }
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: String(backend.settings.kb_layout || "").split(",").filter(function(c) { return c.trim() !== "" })
                Rectangle {
                    id: layoutChip
                    required property var modelData
                    width: chipRow.implicitWidth + 24; height: 32; radius: 16
                    color: backend.palette.surface3
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: layoutCard.nameOf(layoutChip.modelData); color: backend.palette.text; font.pixelSize: 13 }
                        Text {
                            visible: String(backend.settings.kb_layout).indexOf(",") >= 0
                            text: "✕"; color: removeArea.containsMouse ? Ui.danger : backend.palette.subtext; font.pixelSize: 12
                            MouseArea { id: removeArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor; onClicked: layoutCard.remove(layoutChip.modelData) }
                        }
                    }
                }
            }
        }
        Field {
            id: layoutSearch
            width: parent.width
            icon: ""
            placeholder: "Add a layout: type a language or country, e.g. Norwegian"
            onTextChanged: layoutCard.filter = text
            onAccepted: if (layoutCard.matches.length) layoutCard.add(layoutCard.matches[0].value)
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: layoutCard.matches.length > 0
            Repeater {
                model: layoutCard.matches
                PillButton {
                    required property var modelData
                    label: modelData.label + "  (" + modelData.value + ")"
                    primary: true
                    onClicked: layoutCard.add(modelData.value)
                }
            }
        }
    }
    SettingRow {
        title: "Switch layouts with"
        visible: String(backend.settings.kb_layout).indexOf(",") >= 0
        SettingChoice {
            key: "layout_switch"
            options: [ { value: "none", label: "Off" }, { value: "alt_shift", label: "Alt+Shift" },
                       { value: "caps", label: "Caps Lock" }, { value: "ctrl_space", label: "Ctrl+Space" } ]
        }
    }
    SettingRow {
        title: "Key repeat speed"
        hint: "Characters per second while a key is held"
        SettingSlider { key: "repeat_rate"; from: 10; to: 80 }
    }
    SettingRow {
        title: "Key repeat delay"
        hint: "How long to hold a key before it repeats"
        SettingSlider { key: "repeat_delay"; from: 150; to: 1000; step: 25; suffix: " ms" }
    }
    Field {
        width: parent.width
        icon: ""
        placeholder: "Try your keyboard settings here"
    }

    SectionTitle { text: "Mouse" }
    SettingRow {
        title: "Pointer speed"
        hint: "0 is the mouse's own speed"
        SettingSlider { key: "mouse_sensitivity"; from: -1; to: 1; step: 0.05; decimals: 2 }
    }
    SettingRow {
        title: "Acceleration"
        hint: "Flat moves the same distance however fast you move"
        SettingChoice { key: "accel_profile"; options: [ { value: "flat", label: "Flat" }, { value: "adaptive", label: "Adaptive" } ] }
    }
    SettingRow {
        title: "Natural scrolling"
        hint: "Content follows your fingers, like on a phone"
        SettingSwitch { key: "natural_scroll" }
    }
    SettingRow {
        title: "Focus"
        hint: "Which window gets your typing"
        SettingChoice { key: "follow_mouse"; options: [ { value: 1, label: "Under the mouse" }, { value: 0, label: "Clicked" } ] }
    }

    SectionTitle { text: "Touchpad" }
    SettingRow {
        title: "Natural scrolling"
        hint: "For laptops"
        section: "Touchpad"
        SettingSwitch { key: "touchpad_natural_scroll" }
    }
}
