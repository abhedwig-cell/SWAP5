# MC-SOL01: supply-limited surface solute input

Status: proposed on canonical f8eca95ba623dc18db0110cd1b84af46857c8b9b.
Recovery: integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json.

The existing matrix owner, sorption/decay/transport process and native joint restart
remain authoritative. This additive application binds a transient typed rain and
irrigation supply window to every actual accepted downward matrix top flux.
All supply infiltrates. Initial/final pond water and pond mass are zero; evaporation,
runoff, runon, interception, snow, macropores and SSDI are excluded. This is a fully
closed bounded surface-to-soil route, not qualification of the missing pond budget.
No weather reader, irrigation manager or default application activation is claimed.

Historical authority: immutable B1.11 SWAP/solute.f90 SHA256
2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2.
The literal surface mixing block must be extracted independently, then followed by
the existing literal matrix sweep. Upward q is historical sign; water trace qtop
is upward, so negative qtop equals the nonnegative rain-plus-irrigation rate.
Rates are cm/day, concentrations mg/cm3, integrated mass mg/cm2. No runoff law or
new water pool is inferred from an incomplete trace.

State ownership: matrix_solute_state_t retains dissolved/sorbed mass, water endpoint,
clock, immutable parameters and revision. The transient supply is explicit on each
window and cannot replay against the consumed clock. Existing source root TSCF,
signed drains and lower-boundary concentrations apply; WOFOST81 is untouched.
Accepted water endpoints and reconstructed vertical faces are consumed read-only.
A full tentative chemical trace is validated before either water or chemical commit.
Rejected last-substep input cannot leak an accepted prefix. Restart reuses the existing
matrix joint/native codec because there is no new persistent surface pool or pending
forcing. A continuation supplies its next explicit forcing window.

The source infiltration cutoff is qtop < -1e-6 cm/day. Positive supply at or below
that threshold is rejected by this application: silently storing mass in a dry pond
would not satisfy this route. Zero supply is permitted for hiatus continuation.
Bounds are explicit before sums/products/divisions; no clipping or FPE acceptance.

Affected invariants:3,4,7,9,13,21,22,23,25,27,29,30. No existing production provider
or shared interface is changed. The new application is opt-in. Stable qualification
requires real Fortran O0/O2 and literal historical oracle, actual Richards water and
material ledgers, rejection/retry/rollback and fresh-process native continuation.
The protocol level4 gate remains selected once at the shared eligibility boundary;
highest low-air is not selected. All measured and failed outcomes remain distinct.
