#!/usr/bin/env bash
# Toggle the Quickshell dashboard (~/.config/quickshell/desktop). Super+D reaches
# the shell directly through a global shortcut; this wrapper is for anything
# else that wants to open or close it.
exec qs -c desktop ipc call dashboard toggle
