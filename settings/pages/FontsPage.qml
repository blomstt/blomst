import QtQuick
import "../components"

PageScroll {
    pageKey: "fonts"
    title: "Fonts"
    description: "Every font is shown in itself. Click one to use it; Ctrl + Z or the reset button takes it back."

    // A grid of installed fonts, each previewed in its own face
    component FontPicker: Card {
        id: picker
        property string key: ""
        property bool monoOnly: false
        property string filter: ""
        readonly property var fonts: backend.fonts.filter(function(f) {
            return (!picker.monoOnly || f.mono) && f.family.toLowerCase().indexOf(picker.filter.trim().toLowerCase()) >= 0
        })
        Field {
            width: parent.width
            icon: ""
            placeholder: picker.monoOnly ? "Filter monospace fonts" : "Filter fonts"
            onTextChanged: picker.filter = text
        }
        Flow {
            id: grid
            width: parent.width
            spacing: 8
            readonly property real tileWidth: Math.floor((width - 2 * spacing) / 3)
            Repeater {
                model: picker.fonts
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: backend.settings[picker.key] === modelData.family
                    width: grid.tileWidth
                    height: 74
                    radius: 12
                    color: active ? backend.palette.accent : (tileArea.containsMouse ? backend.palette.surface3 : backend.palette.surface2)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: tile.modelData.family
                            font.family: tile.modelData.family
                            font.pixelSize: 16
                            color: tile.active ? backend.palette.accentText : backend.palette.text
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: "Aa Bb Gg 0123 {}" + (tile.modelData.mono ? "  · mono" : "")
                            font.family: tile.modelData.family
                            font.pixelSize: 12
                            color: tile.active ? backend.palette.accentText : backend.palette.subtext
                        }
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setValue(picker.key, tile.modelData.family)
                    }
                }
            }
        }
        Text {
            visible: picker.fonts.length === 0
            text: "No font matches."
            color: backend.palette.subtext
            font.pixelSize: 13
        }
    }

    SectionTitle { text: "Desktop" }
    SettingRow {
        title: "Desktop font"
        hint: "Bar, widgets, app launcher and menus, lock screen. This window shows it next time it opens"
        SettingLabel { key: "font_desktop"; fontFamily: String(backend.settings.font_desktop) }
    }
    Card {
        padding: 22
        spacing: 6
        Text {
            width: parent.width; elide: Text.ElideRight
            text: "The quick brown fox jumps over the lazy dog"
            font.family: String(backend.settings.font_desktop)
            font.pixelSize: 24
            color: backend.palette.text
        }
        Text {
            text: "ABCDEFGHIJKLM  abcdefghijklm  0123456789  .,:;!?(){}[]"
            font.family: String(backend.settings.font_desktop)
            font.pixelSize: 14
            color: backend.palette.subtext
        }
    }
    FontPicker { key: "font_desktop" }

    SectionTitle { text: "Terminal" }
    SettingRow {
        title: "Terminal font"
        hint: "kitty. Only monospace fonts line up in a terminal"
        SettingLabel { key: "font_terminal"; fontFamily: String(backend.settings.font_terminal) }
    }
    SettingRow {
        title: "Terminal font size"
        SettingSlider { key: "font_terminal_size"; from: 8; to: 20; step: 0.5; decimals: 1; suffix: " pt" }
    }
    FontPicker { key: "font_terminal"; monoOnly: true }
}
