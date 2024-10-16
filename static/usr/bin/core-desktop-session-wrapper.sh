#!/bin/bash

# This script runs outside of snap confinement as a wrapper around the
# confined desktop session.
snap_cmd="$1"
snap_name="$(echo "$snap_cmd" | cut -d . -f 1)"

# Set up PATH and XDG_DATA_DIRS to allow calling snaps
if [ -f /snap/snapd/current/etc/profile.d/apps-bin-path.sh ]; then
    source /snap/snapd/current/etc/profile.d/apps-bin-path.sh
fi

export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export GSETTINGS_BACKEND=keyfile

dbus-update-activation-environment --systemd --all

# Don't set this in our own environment, since it will make
# gnome-session believe it is running in X mode
dbus-update-activation-environment --systemd DISPLAY=:0 WAYLAND_DISPLAY=wayland-0

# Set up a background task to wait for gnome-session to create its
# Xauthority file, and copy it to a location snaps will be able to
# see.
function fixup_xauthority() {
    while :; do
        sleep 1s
        xauth_file="$(ls -1t $XDG_RUNTIME_DIR/snap.$snap_name/.mutter-Xwaylandauth.* | head -n1)"
        if [ -f "$xauth_file" ]; then
            cp "$xauth_file" $XDG_RUNTIME_DIR/.Xauthority
            return
        fi
    done
}
fixup_xauthority &

# Symlink the Wayland socket from the snap's private directory
ln -sf "snap.$snap_name/wayland-0" $XDG_RUNTIME_DIR/wayland-0
# Symlink sockets for pipewire and pipewire-pulse
ln -sf "snap.$snap_name/pipewire-0" $XDG_RUNTIME_DIR/pipewire-0
ln -sf "snap.$snap_name/pulse" $XDG_RUNTIME_DIR/pulse

exec "/snap/bin/$snap_cmd"
