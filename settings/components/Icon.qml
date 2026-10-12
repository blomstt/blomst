import QtQuick

// A Font Awesome glyph. Shows nothing if the font is not installed.
Text {
    property string glyph: ""
    text: Ui.hasIcons ? glyph : ""
    font.family: Ui.iconFamily
    font.pixelSize: 14
    color: backend.palette.subtext
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
