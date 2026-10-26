# Existing-owner macropore/Rutter/numeric heat composition

Baseline 043e92ac319d3a3b8ca40b57e995be60db91679a. HIST-INTEGRATION01.
Affected invariants: 3, 7, 13, 21, 23, 25. No new state class, process formula,
solver policy or tolerance. The existing Boesten/macropore state inherits the
optional temperature owner. Its typed restart must retain temperature exactly.

Smallest remaining dependencies: (1) runtime currently rejects numeric heat in
Rutter/Boesten/macropore layouts; (2) typed FMR restart rejects the same complete
state; (3) original native application input/dispatch and full-profile composition
remain separate, not established by a four-node interface test.

First executable closure selects the existing combined Rutter/Boesten/macropore
layout, Reference frozen conductivity, full/half stepping, numeric soil heat,
no frost/snow, no chemistry, no response drainage or root compensation. Matrix
hydraulic water is passed to the unchanged legacy numeric heat provider, as in
the historical endpoint split. No advective macropore energy law is introduced.
Thermal readiness, node identity and numeric mode must be checked explicitly.
Existing nonthermal paths retain their exact preimage behavior.

Qualification uses the existing MIGMAC10 serialized replay driver with its
rollback, smaller retry, A/B/A and typed restart assertions; add independent
bit-exact temperature comparisons, active heat and energy checks. Short controls
must reject incomplete heat configuration and unsupported modes atomically.
Check O0/O2, observer independence and same-input nonthermal preservation.
Full original Andelst, macro chemistry, multi-domain/long-duration thermal
accuracy and file restart publication remain unqualified unless separately run.
