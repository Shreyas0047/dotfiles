pragma Singleton
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    readonly property string name: {
        if (Quickshell.env("NIRI_SOCKET"))
            return "niri";
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return "hyprland";
        return "unknown";
    }
    readonly property bool isHyprland: name === "hyprland"
    readonly property bool isNiri: name === "niri"
    readonly property var backend: backendLoader.item
    readonly property var defaultCapabilities: ({
            windowFullscreen: false,
            windowFloat: false,
            windowMoveWorkspace: false,
            windowClose: false,
            nativeOverview: false,
            customSpecialWorkspaces: false,
            cursorZoom: false,
            sendShortcut: false,
            displayReconfigure: false,
            touchGesturesPlugin: false
        })
    readonly property var capabilities: backend?.capabilities ?? defaultCapabilities
    readonly property string focusedMonitorName: backend?.focusedMonitorName ?? (Quickshell.screens[0]?.name ?? "")
    readonly property int focusedWorkspaceId: backend?.focusedWorkspaceId ?? -1
    readonly property var activeWindow: backend?.activeWindow ?? null
    readonly property var windows: backend?.windows ?? []
    readonly property var workspaceSlots: backend?.workspaceSlots ?? ({})
    readonly property bool overviewActive: backend?.overviewActive ?? false

    signal configReloaded
    signal monitorsChanged
    signal screencastChanged(bool active)

    function hasCapability(cap) {
        return capabilities?.[cap] === true;
    }

    function activeWorkspaceId(screenName) {
        return backend?.activeWorkspaceId(screenName) ?? -1;
    }

    function focusMonitor(screenName) {
        backend?.focusMonitor(screenName);
    }

    function focusWorkspace(id, monitorName) {
        backend?.focusWorkspace(id, monitorName);
    }

    function focusWindow(idOrAddress) {
        return backend?.focusWindow(idOrAddress) ?? false;
    }

    function closeWindow(idOrAddress) {
        backend?.closeWindow(idOrAddress);
    }

    function toggleFullscreen() {
        backend?.toggleFullscreen();
    }

    function toggleFloating() {
        backend?.toggleFloating();
    }

    function moveWindowToWorkspace(target) {
        backend?.moveWindowToWorkspace(target);
    }

    function stepWindowWorkspace(direction) {
        backend?.stepWindowWorkspace(direction);
    }

    function moveWindowInDirection(direction) {
        backend?.moveWindowInDirection(direction);
    }

    function toggleOverview() {
        backend?.toggleOverview();
    }

    function logout() {
        backend?.logout();
    }

    function isWorkspaceFullscreen(screenName) {
        return backend?.isWorkspaceFullscreen(screenName) ?? false;
    }

    function resetSubmap() {
        backend?.resetSubmap();
    }

    function dispatch(command) {
        backend?.dispatch(command);
    }

    function refreshToplevels() {
        backend?.refreshToplevels();
    }

    function refreshMonitors() {
        backend?.refreshMonitors();
    }

    Loader {
        id: backendLoader
        source: {
            if (root.isHyprland)
                return "compositors/HyprlandBackend.qml";
            return "compositors/NullBackend.qml";
        }
    }

    Connections {
        target: backendLoader.item
        ignoreUnknownSignals: true
        function onConfigReloaded() {
            root.configReloaded();
        }
        function onMonitorsChanged() {
            root.monitorsChanged();
        }
        function onScreencastChanged(active) {
            root.screencastChanged(active);
        }
    }
}
