import QtQuick
import QtQuick.Layouts
import "../components"

PageScroll {
    pageKey: "home"
    title: "Hi, " + backend.userName
    description: "Quick switches for everyday things. Everything else is in the sidebar, or press Ctrl + F to search."

    // Current wallpaper
    Rectangle {
        width: parent.width
        height: Math.round(width * 0.32)
        radius: 16
        clip: true
        color: backend.palette.surface
        Image {
            anchors.fill: parent
            source: backend.currentWallpaperImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1200
        }
        Rectangle {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 14
            width: wallRow.implicitWidth + 12; height: 48; radius: 24
            color: backend.palette.window
            Row {
                id: wallRow
                anchors.centerIn: parent
                spacing: 6
                PillButton { label: "Change wallpaper"; icon: ""; primary: true; onClicked: Ui.page = "wallpapers" }
                PillButton { label: "Presets"; icon: ""; onClicked: Ui.page = "presets" }
            }
        }
    }

    SectionTitle { text: "Quick switches" }
    GridLayout {
        width: parent.width
        columns: width > 640 ? 3 : 2
        columnSpacing: 10
        rowSpacing: 10
        QuickToggle { Layout.fillWidth: true; key: "notif_popups"; invert: true; icon: ""
                      label: "Do not disturb"; hintOn: "Pop-ups are hidden"; hintOff: "Pop-ups are shown" }
        QuickToggle { Layout.fillWidth: true; key: "idle_enabled"; invert: true; icon: ""
                      label: "Stay awake"; hintOn: "No lock or suspend"; hintOff: "Locks when idle" }
        QuickToggle { Layout.fillWidth: true; key: "night_light"; icon: ""; visible: backend.nightLightAvailable
                      label: "Night light"; hintOn: "Warmer colours"; hintOff: "Off" }
        QuickToggle { Layout.fillWidth: true; key: "animations_enabled"; icon: ""
                      label: "Animations"; hintOn: "On"; hintOff: "Off: snappiest" }
        QuickToggle { Layout.fillWidth: true; key: "blur_enabled"; icon: ""
                      label: "Blur"; hintOn: "Behind see-through windows"; hintOff: "Off" }
        QuickToggle { Layout.fillWidth: true; key: "border_spin"; icon: ""
                      label: "Rotating border"; hintOn: "Spinning"; hintOff: "Still" }
    }

    SectionTitle { text: "Shortcuts in this window" }
    Card {
        Repeater {
            model: [
                { keys: "Ctrl + F", what: "Search every setting and keybind" },
                { keys: "Ctrl + Z", what: "Undo the last change" },
                { keys: "Esc", what: "Clear the search, or close the window" },
                { keys: "Ctrl + Shift + Esc", what: "Task manager (works anywhere)" }
            ]
            Row {
                required property var modelData
                spacing: 16
                Rectangle {
                    width: 140; height: 26; radius: 6
                    color: backend.palette.surface3
                    Text { anchors.centerIn: parent; text: parent.parent.modelData.keys; color: backend.palette.text; font.pixelSize: 12 }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.what; color: backend.palette.subtext; font.pixelSize: 13 }
            }
        }
        Row {
            spacing: 6
            PillButton { label: "Task manager"; icon: "\uf0ae"; primary: true; onClicked: backend.openTaskManager() }
            PillButton { label: "Open the config folder"; icon: ""; onClicked: backend.openConfigFolder() }
        }
    }
}
