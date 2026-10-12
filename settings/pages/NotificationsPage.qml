import QtQuick
import "../components"

PageScroll {
    pageKey: "notifications"
    title: "Notifications"
    description: "Pop-ups in the top right, and the notification center under the calendar (Super + H)."

    SectionTitle { text: "Pop-ups" }
    SettingRow {
        title: "Show pop-ups"
        hint: "Off is do not disturb: notifications still land in the notification center"
        SettingSwitch { key: "notif_popups" }
    }
    SettingRow {
        title: "Pop-ups stay for"
        opacity: backend.settings.notif_popups ? 1 : 0.45
        SettingSlider { key: "notif_popup_seconds"; from: 3; to: 30; suffix: " s" }
    }

    SectionTitle { text: "Notification center" }
    SettingRow { title: "Show with Super + H"; SettingSwitch { key: "notif_in_stack" } }
    SettingRow {
        title: "Hide pop-ups while it's open"
        hint: "They would cover the widgets otherwise"
        SettingSwitch { key: "notif_hide_with_stack" }
    }
    SettingRow {
        title: "Keep the last"
        hint: "Notifications in the history"
        SettingSlider { key: "notif_history_limit"; from: 10; to: 200; step: 10 }
    }
    SettingRow {
        title: "Clear history"
        hint: "Removes everything from the notification center"
        resettable: false
        PillButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "Clear"
            icon: ""
            onClicked: backend.clearNotifications()
        }
    }
}
