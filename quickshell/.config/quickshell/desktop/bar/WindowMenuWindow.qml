import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

// Actions on the active window, from a long press or right click on its title in the bar (or on the app
// button that replaces the title on a narrow bar): touch has no Super+Q, Super+Shift+F or Super+V.
MenuLayer {
    id: root
    property point origin: Qt.point(0, 0)
    onDismissRequested: dismiss()
    function popup(item, x, y) {
        if (!Compositor.activeWindow)
            return;
        // lastIpcObject (floating) is only filled by a refresh; the entries follow when it arrives.
        Compositor.refreshToplevels();
        origin = item.mapToItem(item.QsWindow.window.contentItem, x, y);
        visible = true;
        Qt.callLater(() => menu.forceActiveFocus());
    }
    function dismiss() {
        visible = false;
    }
    function entries() {
        const window = Compositor.activeWindow;
        if (!window)
            return [];
        return [
            {
                kind: "heading",
                text: window.title || window.appId || ""
            },
            {
                text: I18n.tr("windowMenu.fullscreen"),
                action: () => Compositor.toggleFullscreen()
            },
            {
                text: I18n.tr("windowMenu.floating"),
                checked: window.isFloating === true,
                action: () => Compositor.toggleFloating()
            },
            {
                text: I18n.tr("windowMenu.movePrevious"),
                action: () => Compositor.stepWindowWorkspace(-1)
            },
            {
                text: I18n.tr("windowMenu.moveNext"),
                action: () => Compositor.stepWindowWorkspace(1)
            },
            {
                kind: "separator"
            },
            {
                text: I18n.tr("windowMenu.close"),
                destructive: true,
                action: () => Compositor.closeWindow(window.id)
            }
        ];
    }
    PopupMenu {
        id: menu
        x: root.clampX(root.origin.x, width)
        y: root.clampY(root.origin.y, height)
        entries: root.visible ? root.entries() : []
        onTriggered: root.dismiss()
        onDismissed: root.dismiss()
    }
}
