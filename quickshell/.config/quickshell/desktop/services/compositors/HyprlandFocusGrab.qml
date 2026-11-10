import QtQuick
import Quickshell.Hyprland

Item {
    id: root
    property var targetWindow: null
    signal cleared

    HyprlandFocusGrab {
        active: targetWindow?.visible ?? false
        windows: targetWindow ? [targetWindow] : []
        onCleared: root.cleared()
    }
}
