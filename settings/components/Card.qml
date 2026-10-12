import QtQuick

// A rounded panel that grows with what is inside it.
Rectangle {
    id: card
    default property alias content: inner.data
    property int padding: 18
    property alias spacing: inner.spacing
    width: parent ? parent.width : 600
    height: inner.implicitHeight + 2 * padding
    radius: 14
    color: backend.palette.surface
    Column {
        id: inner
        x: card.padding; y: card.padding
        width: card.width - 2 * card.padding
        spacing: 12
    }
}
