# MC-SOL01: supply-limited surface solute input

Status: PR1234, science O0/O2 PASS; full preservation pending.
Canonical base f8eca95ba623dc18db0110cd1b84af46857c8b9b.
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

## Bounded tested execution

Final execution2291376815e3d33e21cb655d109f915300ed7d19 is sealed in the source-bound
scientific capsule named by the status record.150 literal surface mixing cases,
actual accepted Full Richards through two windows with signed lower/drain exchange
and root extraction, whole water/solute ledgers, true reaction overdraw after a
successful water trial, smaller retry,14 last-carrier/supply negatives per window,
replay rejection, opaque/native/fresh-process continuation and10 decoder negatives
per optimization pass. O0/O2 endpoint SHA256:
7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e.

There are two process providers (compile0.3411s, link0.1080s, native0.0035s) and238
actual private water/chemical/restart providers (compile128.3231s, link0.2065s,
native18.1815s). The process is daily feedback; the larger closure is required by
the existing private Richards/transaction/native restart owners. No new codec,
persistent cache or general test framework is introduced. Initial strict real-zero
warning and an overdraw fixture outside the bounded rate domain were corrected;
their failed raw attempts and O0 leaf feedback remain separate from final cold PASS.

The new composition intentionally selects frexp=1. Existing nonlinear0.5..2 remains
admitted through its own route. This surface scope has node count1..4096, water
1e-8..1, thickness1e-4..1e4cm, interface distance at least1e-4cm, saturation fraction
at least1e-8, concentration at most1e6mg/cm3, per-node amounts at most1e12mg/cm2,
rate magnitude at most1e6cm/day and4096 drain levels. Positive timestep is
1e-100..1000days, clock magnitude at most1e8days and revision at most1e8. A supply
split has each rate0..5e5cm/day. Reaction configuration is bounded before arithmetic:
absolute parameter-vector values at most1e6, temperature-50..60C, gamma0..1,
reference moisture at least1e-8 and moisture exponent0..10. Existing constructor
positivity/equilibrium checks remain authoritative. This is fail-closed numerical
acceptance, not unconditional stability or qualification of every point in the box.

A dry surface has no persistent chemical store in this application. Any nonzero
historical floating-point surface residue is rejected, including tiny positive
residue, rather than erased or silently omitted by the existing restart codec.
A general pond/dry-deposition owner is the next block for those cases. This bound
is deliberate; supplied mass, actual transfer and accepted storage must all close.

The new three providers are additive; all prior production sources, callers,
fixtures, runtime selectors and references are unchanged. Two shared eligibility
guards recognize only the exact source/evidence postimage. Original CO2 assertions
still execute in situ. Previous age/reactive/mineral ownership is verified on the
exact admitted frozen peer after whole-source delta validation. No simultaneous
N/chemical/age execution or combined restart is inferred. One full moving run is
selected on a new immutable final candidate; compile/link/native split inside that broad shell is
UNKNOWN.14 original frozen workflow scopes remain separately bound; no new hosted
15-job qualification is claimed.

## Remaining production queue

| Family | Next dependency-ready block |
| --- | --- |
| SOL surface | Actual per-substep pond/rain/irrigation/runoff water receipts; persistent surface/dry-deposition mass, complete soil-plus-pond balance and native continuation. |
| SOL age | Surface age budget over those water receipts; existing root/drain/lower age route is already admitted. |
| SOL sorption/reaction | Wider historical exponent0..10/inverse semantics and accepted thermal forcing; separate from admitted bounded nonlinear matrix and prescribed decay. |
| NUT crop/soil | Crop N supply/demand over the already admitted mineral and reactive pools, preserving accepted WOFOST81 fixation. |
| NUT forcing/events | Accepted environment/heat, amendment/residue/calendar contracts after the relevant owners are ready. |
| General execution | Default/multicolumn activation and simultaneous companion states need their own atomic acceptance/restart contracts. Aquifer SWBR remains source-defect rejected. |

Master243 dispositions remain unchanged. Only the POND facet/queue is selected for
this bounded progress receipt; the complete historical capability stays ACTIVE.
The existing global stale-inheritance failure is not a new full-master PASS.

Final carrier review tightened the previously relative rate comparison to exact
accepted top-flux equality. The old preliminary provider reproducibly accepts a
large finite mismatch that exceeds the absolute water budget; the new real Fortran
control discriminates this. The original stopped moving execution atdebc95c5 is
CENSORED_NOT_PASS (owning session Ctrl-C exit130), never preservation. The final
scientific capsule binds the exact postimage, final driver and preimage witness.

## Final current-canonical additive admission

The original final O0/O2 evidence and its real Fortran counterexample to relative
water-rate matching remain bound to immutable `238b6184`; preliminary results and
the interrupted moving run remain superseded/CENSORED, never preservation PASS.

Current admission must be evaluated on the later harvest/SWRD2 canonical source.
Select a fresh cold O0/O2 surface process and actual accepted Richards/matrix
composition with every original balance, signed flux, retry and native restart
negative. Reuse the original exact large-finite-rate water-mismatch witness only
while its complete corrected production and driver bytes remain unchanged.
Seal actual compiler/input/command/raw identities and all final endpoints.

For this bounded additive route, require an exact comparison proving that no
existing production/reference byte changes from the qualified canonical. Only
the three explicit surface providers may be added. Default activation remains
absent. Removing the explicit surface owner dispatch and surface eligibility
case must reproduce complete incumbent verifier, control and moving runner
bodies. Execute the admitted incumbent owner's complete retained proof at its
immutable positive source and require the fresh current surface proof at all
public successor entrypoints. Retain original evidence controls on the original
final source, then discriminate current source, current scientific coverage and
missing/corrupt proofs independently. An old positive evaluated against already
stale current source is not a valid negative-control baseline.

Under the binding change-impact execution policy, this exact additive proof plus
fresh affected process/composition/restart science preserves the unchanged
production defaults without repeating a full moving numerical run solely to
teach its source guard three new explicit providers. This supersedes the earlier
full-moving selection for that guard-only reason. It does not inherit a new full
F-CI PASS or waive a changed default, shared contract, owner state or equation:
any such change invalidates this bounded admission path. Highest low-air remains
NOT_SELECTED_POLICY. Persistent pond/source storage, runoff/evaporation and
nonlinear surface composition remain open; aquifer remains rejected. No full
SW431-SALT-POND capability or census promotion follows.
