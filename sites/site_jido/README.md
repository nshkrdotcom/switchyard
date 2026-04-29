# Switchyard Site Jido

`site_jido` is the durable operator/control-plane surface for Switchyard.

It renders `jido_integration_v2` runs, boundary sessions, and attach grants so
the workbench can operate Jido-managed systems without owning durable truth.

The site maps snapshots into run, boundary-session, attach-grant, and explicit
site-state resources. Details include related streams, route/target/grant
metadata, lease information, and redacted policy data where available. Empty,
unavailable, degraded, and error states are represented as `:site_state`
resources, and provider-local search returns typed navigation results without
secret metadata.
