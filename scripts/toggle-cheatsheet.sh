#!/usr/bin/env bash
# Toggle the Quickshell cheatsheet (~/.config/quickshell/desktop). Super+K reaches
# the shell directly through a global shortcut; this wrapper is for anything
# else that wants to open or close it.
exec qs -c desktop ipc call cheatsheet toggle
