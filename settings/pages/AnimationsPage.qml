import QtQuick
import "../components"

PageScroll {
    pageKey: "animations"
    title: "Animations"
    description: "How windows, popups and workspaces move."

    SettingRow {
        title: "Animations"
        hint: "Turn off for the snappiest feel"
        SettingSwitch { key: "animations_enabled" }
    }
    Column {
        width: parent.width
        spacing: 10
        opacity: backend.settings.animations_enabled ? 1 : 0.45
        SettingRow {
            title: "Speed"
            hint: "How long windows, popups and fades take"
            SettingChoice {
                key: "anim_speed"
                options: [ { value: "fast", label: "Fast" }, { value: "normal", label: "Normal" }, { value: "slow", label: "Slow" } ]
            }
        }
        SettingRow {
            title: "Workspace switch"
            hint: "How the screen moves when you change workspace"
            SettingChoice {
                key: "ws_anim"
                options: [ { value: "vertical", label: "Up/down" }, { value: "horizontal", label: "Sideways" }, { value: "fade", label: "Fade" } ]
            }
        }
        SettingRow {
            title: "Rotating border"
            hint: "The gradient on the focused window slowly spins"
            SettingSwitch { key: "border_spin" }
        }
    }
}
