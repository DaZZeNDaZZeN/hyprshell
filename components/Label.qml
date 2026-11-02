import QtQuick
import qs.config

Text {
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fsM
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
}
