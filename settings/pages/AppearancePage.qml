import QtQuick
import "../components"

PageScroll {
    pageKey: "appearance"
    title: "Appearance"
    description: "How windows look. Changes show up straight away."

    SectionTitle { text: "Windows" }
    SettingRow {
        title: "Window layout"
        hint: "How new windows share the screen"
        SettingChoice {
            key: "layout"
            options: [ { value: "dwindle", label: "Spiral" }, { value: "master", label: "Main + stack" } ]
        }
    }
    SettingRow { title: "Gaps between windows"; SettingSlider { key: "gaps_in"; from: 0; to: 20; suffix: " px" } }
    SettingRow { title: "Gaps at screen edges"; SettingSlider { key: "gaps_out"; from: 0; to: 40; suffix: " px" } }
    SettingRow { title: "Corner rounding"; SettingSlider { key: "rounding"; from: 0; to: 30; suffix: " px" } }
    SettingRow {
        title: "Border thickness"
        hint: "0 hides the border"
        SettingSlider { key: "border_size"; from: 0; to: 6; suffix: " px" }
    }
    SettingRow {
        title: "Unfocused window opacity"
        hint: "1 keeps every window solid"
        SettingSlider { key: "inactive_opacity"; from: 0.5; to: 1; step: 0.01; decimals: 2 }
    }

    SectionTitle { text: "Floating windows" }
    SettingRow {
        title: "Remember size"
        hint: "Floating windows reopen at the size you last gave them"
        SettingSwitch { key: "float_size" }
    }
    SettingRow {
        title: "Remember position"
        hint: "Floating windows reopen where you last put them"
        SettingSwitch { key: "float_position" }
    }

    SectionTitle { text: "Blur and shadow" }
    SettingRow {
        title: "Blur"
        hint: "Blurs whatever is behind see-through windows"
        SettingSwitch { key: "blur_enabled" }
    }
    SettingRow {
        title: "Blur strength"
        opacity: backend.settings.blur_enabled ? 1 : 0.45
        SettingSlider { key: "blur_size"; from: 1; to: 15 }
    }
    SettingRow {
        title: "Blur passes"
        hint: "More is smoother and costs a little more GPU"
        opacity: backend.settings.blur_enabled ? 1 : 0.45
        SettingSlider { key: "blur_passes"; from: 1; to: 5 }
    }
    SettingRow { title: "Shadows"; SettingSwitch { key: "shadow_enabled" } }

    SectionTitle { text: "Terminal" }
    SettingRow {
        title: "Terminal opacity"
        hint: "kitty only. Open terminals update too"
        SettingSlider { key: "terminal_opacity"; from: 0.3; to: 1; step: 0.01; decimals: 2 }
    }
}
