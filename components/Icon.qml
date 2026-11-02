import QtQuick
import qs.config

// Nerd-font glyph icon.
Text {
    property color tint: Theme.text
    color: tint
    font.family: Theme.iconFont
    font.pixelSize: 16
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
}
