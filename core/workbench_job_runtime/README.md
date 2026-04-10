# Switchyard Job Runtime

`switchyard_job_runtime` defines structured local job lifecycle behavior.

## Responsibilities

- create typed job records
- validate lifecycle transitions
- track progress counters
- keep job state consistent across daemon operations

## Why This Package Exists

Process execution alone is not enough for an operator workbench. The platform
also needs durable, inspectable job state that can outlive one UI frame or one
terminal session.

## Current Scope

The initial runtime focuses on predictable job transitions and progress updates.
It is intentionally small and proven by focused tests.
