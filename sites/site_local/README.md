# Switchyard Site Local

`switchyard_site_local` is the built-in local operations site for Switchyard.

## Responsibilities

- expose local apps such as processes, jobs, and logs
- map daemon snapshots into generic Switchyard resources
- expose recommended actions and resource details for local runtime state

## Why This Package Exists

Switchyard needs one first-party site that proves the platform is useful even
before any remote domain integration is plugged in.

## Current Scope

The site currently maps:

- processes
- jobs

The logs app exists in the catalog now, and richer log-stream resource mapping
can grow on this same seam.
