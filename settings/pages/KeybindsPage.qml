import QtQuick
import "../components"

PageScroll {
    id: keybindsPage
    pageKey: "keybinds"
    title: "Keybinds"
    description: "Every shortcut, read from keybinds.conf and named by the comment above it."
    onVisibleChanged: if (visible) { backend.refreshKeybinds(); filterField.text = Ui.keybindFilter }

    readonly property var groups: {
        var q = Ui.keybindFilter.trim().toLowerCase(), out = []
        var all = backend.keybinds
        for (var g = 0; g < all.length; g++) {
            var titleHit = all[g].title.toLowerCase().indexOf(q) >= 0
            var binds = all[g].binds.filter(function(b) {
                return q === "" || titleHit || (b.keys + " " + b.action).toLowerCase().indexOf(q) >= 0
            })
            if (binds.length) out.push({ title: all[g].title, binds: binds })
        }
        return out
    }

    Row {
        width: parent.width
        spacing: 10
        Field {
            id: filterField
            width: parent.width - editButton.width - 10
            icon: ""
            placeholder: "Filter: a key like Super + B, or what it does"
            onTextChanged: Ui.keybindFilter = text
        }
        PillButton {
            id: editButton
            label: "Edit file"
            icon: ""
            anchors.verticalCenter: parent.verticalCenter
            onClicked: backend.openKeybindsFile()
        }
    }

    Note {
        visible: keybindsPage.groups.length === 0
        topPadding: 20
        horizontalAlignment: Text.AlignHCenter
        text: "No shortcut matches."
    }

    Repeater {
        model: keybindsPage.groups
        Card {
            id: group
            required property var modelData
            spacing: 6
            padding: 16
            Text { text: group.modelData.title; color: backend.palette.text; font.pixelSize: 15; bottomPadding: 4 }
            Repeater {
                model: group.modelData.binds
                Item {
                    id: bindRow
                    required property var modelData
                    width: parent.width
                    height: 30
                    Row {
                        id: keycaps
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: bindRow.modelData.keys.split(" + ")
                            Rectangle {
                                required property var modelData
                                width: Math.max(26, capText.implicitWidth + 14); height: 24; radius: 6
                                color: backend.palette.surface3
                                Text { id: capText; anchors.centerIn: parent; text: parent.modelData; color: backend.palette.text; font.pixelSize: 12 }
                            }
                        }
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 250
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: bindRow.modelData.action
                        color: backend.palette.subtext
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
