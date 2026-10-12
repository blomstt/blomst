import QtQuick
import "../components"

PageScroll {
    id: displaysPage
    pageKey: "displays"
    title: "Displays"
    description: "Resolution, refresh rate and scale. A change is tried first: keep it within 15 seconds or it goes back by itself."
    onVisibleChanged: if (visible) backend.refreshMonitors()

    // Pills that wrap onto new lines
    component Chips: Flow {
        id: chips
        property var options: []
        property var current
        signal chosen(var value)
        width: parent ? parent.width : 400
        spacing: 6
        Repeater {
            model: chips.options
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool active: String(chips.current) === String(modelData.value)
                width: chipText.implicitWidth + 24; height: 32; radius: 16
                color: active ? backend.palette.accent : (chipArea.containsMouse ? backend.palette.surface3 : backend.palette.surface2)
                Text { id: chipText; anchors.centerIn: parent; text: chip.modelData.label; font.pixelSize: 13
                       color: chip.active ? backend.palette.accentText : backend.palette.text }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: chips.chosen(chip.modelData.value) }
            }
        }
    }

    Repeater {
        model: backend.monitors
        Card {
            id: monitorCard
            required property var modelData
            readonly property string currentRes: modelData.mode.split("@")[0]
            property string res: currentRes
            property string rate: ""
            property real scale: modelData.scale
            property bool allResolutions: false
            spacing: 10

            function ratesFor(r) {
                var out = []
                for (var i = 0; i < modelData.modes.length; i++) {
                    var m = modelData.modes[i].value.split("@")
                    if (m[0] === r) out.push({ value: modelData.modes[i].value, label: Math.round(parseFloat(m[1])) + " Hz" })
                }
                out.sort(function(a, b) { return parseFloat(b.value.split("@")[1]) - parseFloat(a.value.split("@")[1]) })
                return out
            }
            function resolutions() {
                var seen = {}, out = []
                for (var i = 0; i < modelData.modes.length; i++) {
                    var r = modelData.modes[i].value.split("@")[0]
                    if (!seen[r]) { seen[r] = true; out.push(r) }
                }
                out.sort(function(a, b) { var x = a.split("x"), y = b.split("x"); return y[0] * y[1] - x[0] * x[1] })
                // Tiny old modes are rarely wanted; keep them behind "Show all"
                if (!allResolutions)
                    out = out.filter(function(r) { return parseInt(r.split("x")[0]) >= 1280 || r === res })
                return out.map(function(r) { return { value: r, label: r.replace("x", " × ") } })
            }
            function closestRate(r) {
                var list = ratesFor(r)
                var want = parseFloat(modelData.mode.split("@")[1])
                var best = list.length ? list[0].value : ""
                for (var i = 0; i < list.length; i++)
                    if (Math.abs(parseFloat(list[i].value.split("@")[1]) - want) < Math.abs(parseFloat(best.split("@")[1]) - want))
                        best = list[i].value
                return best
            }
            function reset() { res = currentRes; rate = closestRate(currentRes); scale = modelData.scale }
            Component.onCompleted: reset()
            onModelDataChanged: reset()

            readonly property bool changed: rate !== closestRate(currentRes) || Math.abs(scale - modelData.scale) > 0.001

            Row {
                spacing: 12
                Icon { glyph: ""; font.pixelSize: 18; color: backend.palette.text; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    Text { text: monitorCard.modelData.name; color: backend.palette.text; font.pixelSize: 16 }
                    Text { text: monitorCard.modelData.description; color: backend.palette.subtext; font.pixelSize: 12 }
                }
            }
            Text { text: "Resolution"; color: backend.palette.subtext; font.pixelSize: 12; topPadding: 4 }
            Chips {
                options: monitorCard.resolutions()
                current: monitorCard.res
                onChosen: (value) => { monitorCard.res = value; monitorCard.rate = monitorCard.ratesFor(value)[0].value }
            }
            Text {
                text: monitorCard.allResolutions ? "Show fewer" : "Show all resolutions"
                color: backend.palette.accent
                font.pixelSize: 12
                font.underline: moreArea.containsMouse
                MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: monitorCard.allResolutions = !monitorCard.allResolutions }
            }
            Text { text: "Refresh rate"; color: backend.palette.subtext; font.pixelSize: 12; topPadding: 4 }
            Chips {
                options: monitorCard.ratesFor(monitorCard.res)
                current: monitorCard.rate
                onChosen: (value) => monitorCard.rate = value
            }
            Text { text: "Scale (makes everything bigger)"; color: backend.palette.subtext; font.pixelSize: 12; topPadding: 4 }
            Chips {
                options: monitorCard.modelData.scales.map(function(s) { return { value: s, label: Math.round(s * 100) + "%" } })
                current: monitorCard.scale
                onChosen: (value) => monitorCard.scale = value
            }
            Row {
                spacing: 6
                visible: monitorCard.changed
                PillButton {
                    label: "Try it"
                    icon: ""
                    primary: true
                    onClicked: backend.applyMonitor(monitorCard.modelData.name, monitorCard.rate, monitorCard.scale)
                }
                PillButton { label: "Cancel"; onClicked: monitorCard.reset() }
            }
        }
    }
    Note {
        visible: backend.monitors.length === 0
        text: "No displays found. Is Hyprland running?"
    }

    SectionTitle { text: "Night light" }
    Note { text: "Warmer colours in the evening are easier on the eyes." }
    SettingRow {
        visible: backend.nightLightAvailable
        title: "Night light"
        hint: "Stays on after a restart until you turn it off"
        SettingSwitch { key: "night_light" }
    }
    SettingRow {
        visible: backend.nightLightAvailable
        title: "Warmth"
        hint: "Lower is warmer. 6500 K is no change"
        opacity: backend.settings.night_light ? 1 : 0.45
        SettingSlider { key: "night_light_temp"; from: 2500; to: 6500; step: 100; suffix: " K" }
    }
    Card {
        visible: !backend.nightLightAvailable
        Text { text: "Night light needs hyprsunset"; color: backend.palette.text; font.pixelSize: 15 }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: "Install it with  sudo pacman -S hyprsunset  and reopen this window."
            color: backend.palette.subtext; font.pixelSize: 13
        }
    }
}
