# Switchyard Daemon App

`switchyard_daemon_app` is the runnable OTP application that starts the local
Switchyard daemon.

## Responsibilities

- configure the daemon with site modules
- provide the actual long-lived local daemon process for CLI and TUI clients

## Why This Package Exists

The daemon runtime and the daemon application should not be the same thing. This
package keeps runtime behavior reusable while still providing a concrete OTP app
for local operation.

## Current Scope

The initial daemon app wires together the built-in local site over the shared
daemon foundation.
