import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../bar/WorkspaceModel.js" as WorkspaceModel

Item {
    id: root
    readonly property string name: "hyprland"
    readonly property var capabilities: ({
            windowFullscreen: true,
            windowFloat: true,
            windowMoveWorkspace: true,
            windowClose: true,
            nativeOverview: false,
            customSpecialWorkspaces: true,
            cursorZoom: true,
            sendShortcut: true,
            displayReconfigure: true,
            touchGesturesPlugin: true
        })
    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? -1
    readonly property var activeWindow: Hyprland.activeToplevel ? normalizeWindow(Hyprland.activeToplevel) : null
    readonly property var windows: {
        const list = [];
        for (const toplevel of Hyprland.toplevels.values) {
            if (!(toplevel.workspace?.name ?? "").startsWith("special:"))
                list.push(normalizeWindow(toplevel));
        }
        return list;
    }
    readonly property var workspaceSlots: WorkspaceModel.fromHyprland(Hyprland, Config.minimumWorkspaces)
    readonly property bool overviewActive: false

    signal configReloaded
    signal monitorsChanged
    signal screencastChanged(bool active)

    function normalizeWindow(toplevel) {
        if (!toplevel)
            return null;
        return {
            id: toplevel.address,
            raw: toplevel,
            title: toplevel.title ?? "",
            appId: toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "",
            workspaceId: toplevel.workspace?.id ?? -1,
            workspaceName: toplevel.workspace?.name ?? "",
            monitorName: toplevel.monitor?.name ?? "",
            isFloating: toplevel.lastIpcObject?.floating === true,
            isActivated: toplevel.activated === true,
            isUrgent: toplevel.urgent === true,
            activate: () => {
                if (toplevel.wayland)
                    toplevel.wayland.activate();
                else if (toplevel.address)
                    root.focusWindow(toplevel.address);
            },
            close: () => {
                if (toplevel.wayland)
                    toplevel.wayland.close();
                else
                    root.closeWindow(toplevel.address);
            }
        };
    }

    function activeWorkspaceId(screenName) {
        const screen = ShellState.screenNamed(screenName);
        return screen ? Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? -1 : -1;
    }

    function focusMonitor(name) {
        Hyprland.dispatch("hl.dsp.focus({ monitor = " + JSON.stringify(name) + " })");
    }

    function focusWorkspace(id, monitorName) {
        if (monitorName)
            focusMonitor(monitorName);
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    function focusWindow(idOrAddress) {
        const address = String(idOrAddress).startsWith("0x") ? String(idOrAddress) : "0x" + String(idOrAddress);
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
        return true;
    }

    function closeWindow(idOrAddress) {
        if (!idOrAddress) {
            Hyprland.dispatch("hl.dsp.close_window()");
            return;
        }
        const toplevel = Hyprland.toplevels.values.find(t => t.address === idOrAddress);
        if (toplevel?.wayland)
            toplevel.wayland.close();
        else
            Hyprland.dispatch("hl.dsp.close_window()");
    }

    function toggleFullscreen() {
        Hyprland.dispatch("hl.dsp.window.fullscreen()");
    }

    function toggleFloating() {
        Hyprland.dispatch("hl.dsp.window.float({ action = \"toggle\" })");
    }

    function moveWindowToWorkspace(target) {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + JSON.stringify(String(target)) + " })");
    }

    function stepWindowWorkspace(direction) {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = \"r" + (direction > 0 ? "+1" : "-1") + "\" })");
    }

    function moveWindowInDirection(direction) {
        Hyprland.dispatch("hl.dsp.window.move({ direction = " + JSON.stringify(direction) + " })");
    }

    function toggleOverview() {
        Quickshell.execDetached(["hyprctl", "eval", "local overview = (hl.plugin or {}).overview if overview then overview.toggle() end"]);
    }

    function logout() {
        Hyprland.dispatch("hl.dsp.exit()");
    }

    function isWorkspaceFullscreen(screenName) {
        const screen = ShellState.screenNamed(screenName);
        return screen ? Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false : false;
    }

    function resetSubmap() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
    }

    function dispatch(command) {
        Hyprland.dispatch(command);
    }

    function refreshToplevels() {
        Hyprland.refreshToplevels();
    }

    function refreshMonitors() {
        Hyprland.refreshMonitors();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.configReloaded();
            else if (event.name === "monitoradded" || event.name === "monitorremoved" || event.name === "monitoraddedv2" || event.name === "monitorremovedv2")
                root.monitorsChanged();
            else if (event.name === "screencast")
                root.screencastChanged(event.data.split(",")[0] === "1");
        }
    }
}
