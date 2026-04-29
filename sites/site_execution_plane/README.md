# Switchyard Site Execution Plane

`site_execution_plane` is the raw substrate/admin surface for Switchyard.

It renders brokered `execution_plane` process sessions, operator terminals,
jobs, streams, and explicit site-state resources inside the Switchyard product
shell without claiming runtime ownership.

The site maps daemon snapshots into contract resources and details, implements
provider-local search, and distinguishes operator UI transport from
managed-process attach. Process, job, and stream details include related IDs
where backing snapshot data exists. Empty, unavailable, degraded, and error
states are represented as `:site_state` resources instead of being hidden as
plain empty lists.
