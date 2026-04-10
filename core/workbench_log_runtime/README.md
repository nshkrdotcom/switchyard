# Switchyard Log Runtime

`switchyard_log_runtime` owns bounded in-memory log buffering helpers.

## Responsibilities

- create bounded log buffers
- append log events
- return recent events
- filter events without re-implementing storage everywhere

## Why This Package Exists

Logs are a shared platform concern. Every future site and app will need a clean
way to work with live and recent log output.

## Current Scope

The package currently provides small pure helpers for buffering and filtering.
That is enough for the first daemon-backed runtime seam.
