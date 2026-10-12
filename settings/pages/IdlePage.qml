import QtQuick
import "../components"

PageScroll {
    pageKey: "idle"
    title: "Idle"
    description: "What happens when you step away. Times count minutes without touching the mouse or keyboard."

    SettingRow {
        title: "Lock and suspend when idle"
        hint: "Same as the eye icon in the bar. Off keeps the PC awake"
        SettingSwitch { key: "idle_enabled" }
    }
    Column {
        width: parent.width
        spacing: 10
        opacity: backend.settings.idle_enabled ? 1 : 0.45
        SettingRow { title: "Lock the screen after"; SettingSlider { key: "idle_lock_min"; from: 1; to: 120; suffix: " min" } }
        SettingRow { title: "Suspend the PC after"; SettingSlider { key: "idle_suspend_min"; from: 5; to: 240; step: 5; suffix: " min" } }
    }
}
