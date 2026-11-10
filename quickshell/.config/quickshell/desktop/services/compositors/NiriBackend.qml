import QtQuick
import Quickshell
import Quickshell.Niri._Ipc
import "../.."
import "../../bar/WorkspaceModel.js" as WorkspaceModel

Item {
    id: root
    readonly property string name: "niri"
    readonly property var capabilities: ({
            windowFullscreen: true,
            windowFloat: true,
            windowMoveWorkspace: true,
            windowClose: true,
            nativeOverview: true,
            customSpecialWorkspaces: false,
            cursorZoom: false,
            sendShortcut: false,
            displayReconfigure: false,
            touchGesturesPlugin: false
        })
    property int windowsRevision: 0
    property int workspacesRevision: 0
    readonly property string focusedMonitorName: {
        const _rev = root.windowsRevision + root.workspacesRevision;
        const win = Niri.focusedWindow;
        if (win && win.output)
            return win.output;
        const focusedWs = Niri.workspaces.values.find(w => w.focused || (w.active && w.output));
        if (focusedWs && focusedWs.output)
            return focusedWs.output;
        return Quickshell.screens[0]?.name ?? "";
    }
    readonly property int focusedWorkspaceId: {
        const _rev = root.workspacesRevision;
        const focusedWs = Niri.workspaces.values.find(w => w.focused);
        return focusedWs?.id ?? -1;
    }
    readonly property var activeWindow: {
        const _rev = root.windowsRevision;
        return Niri.focusedWindow ? normalizeWindow(Niri.focusedWindow) : null;
    }
    readonly property var windows: {
        const _rev = root.windowsRevision;
        const list = [];
        for (const win of Niri.windows.values) {
            list.push(normalizeWindow(win));
        }
        return list;
    }
    readonly property var workspaceSlots: {
        const _rev = root.workspacesRevision;
        return WorkspaceModel.fromNiri(Niri.workspaces.values, Niri.outputs.values.length > 0 ? Niri.outputs.values : Quickshell.screens.map(s => ({
                    name: s.name
                })), Config.minimumWorkspaces);
    }
    readonly property bool overviewActive: Niri.overviewActive

    signal configReloaded
    signal monitorsChanged
    signal screencastChanged(bool active)

    function normalizeWindow(niriWindow) {
        if (!niriWindow)
            return null;
        return {
            id: niriWindow.id,
            raw: niriWindow,
            title: niriWindow.title ?? "",
            appId: niriWindow.appId ?? "",
            workspaceId: niriWindow.workspaceId ?? -1,
            workspaceName: "",
            monitorName: niriWindow.output ?? "",
            isFloating: niriWindow.isFloating === true,
            isActivated: niriWindow.focused === true,
            isUrgent: false,
            activate: () => root.focusWindow(niriWindow.id),
            close: () => root.closeWindow(niriWindow.id)
        };
    }

    function activeWorkspaceId(screenName) {
        const ws = Niri.workspaces.values.find(w => w.output === screenName && w.active);
        return ws?.id ?? -1;
    }

    function focusMonitor(screenName) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-monitor", screenName]);
    }

    function focusWorkspace(idOrIdx, monitorName) {
        if (monitorName && monitorName !== focusedMonitorName)
            focusMonitor(monitorName);
        const ws = Niri.workspaces.values.find(w => w.id === idOrIdx || w.idx === idOrIdx);
        const ref = ws ? String(ws.idx) : String(idOrIdx);
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", ref]);
    }

    function focusWindow(id) {
        if (!id)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]);
        return true;
    }

    function closeWindow(id) {
        if (id)
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(id)]);
        else
            Quickshell.execDetached(["niri", "msg", "action", "close-window"]);
    }

    function toggleFullscreen() {
        Quickshell.execDetached(["niri", "msg", "action", "fullscreen-window"]);
    }

    function toggleFloating() {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-window-floating"]);
    }

    function moveWindowToWorkspace(target) {
        Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", String(target)]);
    }

    function stepWindowWorkspace(direction) {
        if (direction > 0)
            Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace-down"]);
        else
            Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace-up"]);
    }

    function moveWindowInDirection(direction) {
        if (direction === "left")
            Quickshell.execDetached(["niri", "msg", "action", "move-column-left"]);
        else if (direction === "right")
            Quickshell.execDetached(["niri", "msg", "action", "move-column-right"]);
        else if (direction === "up")
            Quickshell.execDetached(["niri", "msg", "action", "move-window-up"]);
        else if (direction === "down")
            Quickshell.execDetached(["niri", "msg", "action", "move-window-down"]);
    }

    function toggleOverview() {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
    }

    function logout() {
        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
    }

    function isWorkspaceFullscreen(screenName) {
        return false;
    }

    function resetSubmap() {
    }

    function dispatch(command) {
    }

    function refreshToplevels() {
        Niri.refreshWindows();
    }

    function refreshMonitors() {
        Niri.refreshOutputs();
        Niri.refreshWorkspaces();
    }

    Connections {
        target: Niri
        ignoreUnknownSignals: true
        function onWindowsUpdated() {
            root.windowsRevision++;
        }
        function onWorkspacesUpdated() {
            root.workspacesRevision++;
        }
        function onFocusedWindowChanged() {
            root.windowsRevision++;
        }
        function onOutputsUpdated() {
            root.workspacesRevision++;
            root.monitorsChanged();
        }
        function onRawEvent(event) {
            if (event.type === "ConfigLoaded")
                root.configReloaded();
            else if (event.type === "OutputsChanged")
                root.monitorsChanged();
            else if (event.type === "CastsChanged" || event.type === "CastStartedOrChanged" || event.type === "CastStopped")
                root.screencastChanged(event.type !== "CastStopped");
        }
    }
}
