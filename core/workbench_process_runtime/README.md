# Switchyard Process Runtime

`switchyard_process_runtime` manages local subprocess execution for the daemon.

## Responsibilities

- validate managed process specs
- spawn local OS processes through ports
- capture stdout and stderr lines
- expose exit status back to the daemon seam

## Why This Package Exists

Local process management is operational infrastructure. It should not be mixed
into the UI or hidden inside site-specific code.

## Current Scope

The initial runtime proves one essential seam: Switchyard can start a managed
process, stream its output, and report completion without involving the TUI.
