import QtQuick
import Quickshell

Item {
    id: root
    readonly property string name: "unknown"
    readonly property var capabilities: ({
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
    readonly property string focusedMonitorName: Quickshell.screens[0]?.name ?? ""
    readonly property int focusedWorkspaceId: -1
    readonly property var activeWindow: null
    readonly property var windows: []
    readonly property var workspaceSlots: ({})
    readonly property bool overviewActive: false

    signal configReloaded
    signal monitorsChanged
    signal screencastChanged(bool active)

    function activeWorkspaceId(screenName) {
        return -1;
    }

    function focusMonitor(name) {
    }

    function focusWorkspace(id, monitorName) {
    }

    function focusWindow(idOrAddress) {
        return false;
    }

    function closeWindow(idOrAddress) {
    }

    function toggleFullscreen() {
    }

    function toggleFloating() {
    }

    function moveWindowToWorkspace(target) {
    }

    function stepWindowWorkspace(direction) {
    }

    function moveWindowInDirection(direction) {
    }

    function toggleOverview() {
    }

    function logout() {
    }

    function isWorkspaceFullscreen(screenName) {
        return false;
    }

    function resetSubmap() {
    }

    function dispatch(command) {
    }

    function refreshToplevels() {
    }

    function refreshMonitors() {
    }
}
