import QtQuick
import "../components"

PageScroll {
    pageKey: "bar"
    title: "Bar"
    description: "Choose what the side-bar shows. The bar reloads by itself after a change."

    SectionTitle { text: "Resource rings" }
    SettingRow { title: "CPU ring"; SettingSwitch { key: "show_cpu" } }
    SettingRow { title: "Temperature ring"; SettingSwitch { key: "show_temp" } }
    SettingRow { title: "Memory ring"; SettingSwitch { key: "show_mem" } }
    SettingRow { title: "Disk ring"; SettingSwitch { key: "show_disk" } }
    SectionTitle { text: "Media" }
    SettingRow {
        title: "Music"
        hint: "Song title, cover and seek bar in the middle of the bar"
        SettingSwitch { key: "show_music" }
    }
    SettingRow {
        title: "Audio visualizer"
        hint: "Moving bars under the music while sound is playing"
        SettingSwitch { key: "show_visualizer" }
    }
    SectionTitle { text: "Devices" }
    SettingRow {
        title: "Headset battery"
        hint: "Wireless headset charge, shown while the headset is on (needs headsetcontrol)"
        SettingSwitch { key: "show_headset" }
    }
}
