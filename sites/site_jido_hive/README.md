# Switchyard Site Jido Hive

`switchyard_site_jido_hive` maps Jido Hive workflow truth into Switchyard
contracts.

## Responsibilities

- expose Jido Hive apps such as rooms and publications
- map Jido Hive snapshots into generic resources
- surface workflow details and recommended actions through the shared contracts

## Why This Package Exists

Jido Hive should be a site inside Switchyard, not the platform center. This
package keeps that boundary explicit.

## Current Scope

The initial mapping focuses on:

- room workflow state
- publication state
- room-level actions such as run, provenance, and publish
