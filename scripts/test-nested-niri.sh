#!/usr/bin/env bash
# Run Niri nested inside an isolated sandbox to test Quickshell safely without
# affecting the host desktop session or host systemd units.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_WAYLAND="${WAYLAND_DISPLAY:-wayland-1}"
HOST_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ ! -S "$HOST_RUNTIME/$PARENT_WAYLAND" ]]; then
    echo "Error: Host Wayland socket $HOST_RUNTIME/$PARENT_WAYLAND not found." >&2
    exit 1
fi

# Ensure user-level development symlinks exist so Quickshell helpers and desktop-shell resolve
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec" "$HOME/.config/quickshell"
[[ -e "$HOME/.local/libexec/desktop" ]] || ln -s "$DOTFILES_ROOT/shell/.local/libexec/desktop" "$HOME/.local/libexec/desktop"
[[ -e "$HOME/.config/quickshell/desktop" ]] || ln -s "$DOTFILES_ROOT/quickshell/.config/quickshell/desktop" "$HOME/.config/quickshell/desktop"
for bin in "$DOTFILES_ROOT"/shell/.local/bin/*; do
    name="$(basename "$bin")"
    [[ -e "$HOME/.local/bin/$name" ]] || ln -s "$bin" "$HOME/.local/bin/$name"
done

# Create private sandbox
SANDBOX_DIR="$(mktemp -d /tmp/niri-nested-sandbox.XXXXXX)"
chmod 700 "$SANDBOX_DIR"

cleanup() {
    echo "Cleaning up nested sandbox..."
    fusermount -u "$RUNTIME_DIR/gvfs" 2>/dev/null || true
    fusermount -u "$RUNTIME_DIR/doc" 2>/dev/null || true
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT INT TERM

RUNTIME_DIR="$SANDBOX_DIR/runtime"
CONFIG_DIR="$SANDBOX_DIR/config"
STATE_DIR="$SANDBOX_DIR/state"
BIN_DIR="$SANDBOX_DIR/bin"
LIBEXEC_DIR="$SANDBOX_DIR/libexec"

mkdir -p "$RUNTIME_DIR" "$CONFIG_DIR" "$STATE_DIR" "$BIN_DIR" "$LIBEXEC_DIR"
chmod 700 "$RUNTIME_DIR" "$CONFIG_DIR" "$STATE_DIR"

# Symlink host Wayland socket as wayland-parent so child Niri does not clash with it
ln -s "$HOST_RUNTIME/$PARENT_WAYLAND" "$RUNTIME_DIR/wayland-parent"

# Stub systemctl to prevent any child process from touching host user units
cat <<'STUB' > "$BIN_DIR/systemctl"
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$BIN_DIR/systemctl"

# Stub dbus-update-activation-environment
cat <<'STUB' > "$BIN_DIR/dbus-update-activation-environment"
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$BIN_DIR/dbus-update-activation-environment"

# Symlink project scripts
for bin in "$DOTFILES_ROOT"/shell/.local/bin/*; do
    [[ -f "$bin" ]] && ln -s "$bin" "$BIN_DIR/$(basename "$bin")"
done
ln -s "$DOTFILES_ROOT/shell/.local/libexec/desktop" "$LIBEXEC_DIR/desktop"

# Symlink Quickshell desktop config
mkdir -p "$CONFIG_DIR/quickshell"
ln -s "$DOTFILES_ROOT/quickshell/.config/quickshell/desktop" "$CONFIG_DIR/quickshell/desktop"

# Generate nested Niri config by inserting nested Alt bindings into the single binds block
sed '$d' "$DOTFILES_ROOT/niri/.config/niri/config.kdl" > "$CONFIG_DIR/nested-niri.kdl"
cat <<'KDL' >> "$CONFIG_DIR/nested-niri.kdl"

    // Nested test controls (Alt-based to avoid collision with parent compositor)
    Alt+Return { spawn "kitty"; }
    Alt+Space { spawn "desktop-shell" "toggle" "launcher"; }
    Alt+D { spawn "desktop-shell" "toggle" "launcher"; }
    Alt+Shift+D { spawn "desktop-shell" "dock" "toggle"; }
    Alt+Shift+Q { spawn "desktop-shell" "toggle" "power"; }
    Alt+I { spawn "desktop-shell" "toggle" "settings"; }
    Alt+Shift+C { spawn "desktop-shell" "toggle" "controls"; }
    Alt+Shift+N { spawn "desktop-shell" "toggle" "notifications"; }
    Alt+Shift+Escape { quit skip-confirmation=true; }
    Alt+Q { close-window; }
    Alt+Left { focus-column-left; }
    Alt+Right { focus-column-right; }
    Alt+Up { focus-window-up; }
    Alt+Down { focus-window-down; }
}

spawn-at-startup "bash" "-c" "sleep 1.5 && desktop-shell toggle launcher"
KDL

# Pre-flight config validation
niri validate -c "$CONFIG_DIR/nested-niri.kdl"

echo "=========================================================="
echo "Starting isolated nested Niri session..."
echo "Parent Wayland: $PARENT_WAYLAND"
echo "Sandbox: $SANDBOX_DIR"
echo "Controls inside nested window:"
echo "  Application Menu (Launcher): Opens automatically on start, or press Alt+D / Alt+Space"
echo "  Top Bar: Visible across the top (logo on left, clock/tray on right)"
echo "  Dock: Press Alt+Shift+D"
echo "  Power Menu: Alt+Shift+Q"
echo "  Settings: Alt+I"
echo "  Terminal: Alt+Return"
echo "  Close Focused Window: Alt+Q"
echo "  Exit Nested Session: Alt+Shift+Escape"
echo "=========================================================="

# Launch nested niri in private D-Bus session
export DESKTOP_NESTED=1
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_STATE_HOME="$STATE_DIR"
export WAYLAND_DISPLAY="wayland-parent"
export QT_QPA_PLATFORM="wayland"
export PATH="$BIN_DIR:$PATH"
unset NIRI_SOCKET
unset HYPRLAND_INSTANCE_SIGNATURE

exec dbus-run-session -- niri -c "$CONFIG_DIR/nested-niri.kdl"
