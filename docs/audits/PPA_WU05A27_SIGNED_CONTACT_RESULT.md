# A27 signed contact prototype and source-unit repair result

Date: 2026-10-02 UTC
Status: RESEARCH_BLOCK_COMPLETE; TRANSITION_ROUTE_FALSIFIED; SOURCE_REPAIR_LOCALLY_TESTED
Full A27 benchmark: OPEN. Canonical admission: NOT_CLAIMED.
Reconciled canonical: 029453104b98d835790f2e09eb9e804aa3eaff4a.
Initial A27 head: a02f55587fdfa75dccafe2364b0c9fc9a5f9e2ed.
Research column source postimage: 57eeac0cbe98969f449593047810eb23bbf667d2.
Production source-repair tested postimage: d23d0c62ac84b63f013cd9466cad359d8c0121c3.
Transition falsifier tested postimage: d1311fbf13c347f8a82f926874a6ac6a64745b2f.
Compiler: local GNU Fortran 13.3.0. No Actions requested.

## Scope and changes

The proposed signed-contact law, isolated under research/rfm/a27, composes
signed saturated Darcy exchange with the existing max(Philip,Darcy) structure
for unsaturated matrix contacts. Transfer is capped by accepted donor/receiver
budgets and the shared finite IC receiver. See SIGNED_CONTACT_CONTRACT.
It is not dispatched by production, and does not change MB or top-input ownership.

A separate existing production source-unit defect was reproduced and repaired
on this branch only. See SOURCE_UNITS_CORRECTION_CONTRACT.
No shared signature, persistence state or production physical option changes.

## Source-unit defect and verified candidate repair

The actual production composer divides endpoint release by dz*dt.
The actual RFM source wrapper passes it unchanged into Reference Richards,
whose compartment source is areic cm/day. The solver consumes source without
multiplication by dz, so the joint-domain transfer differs by 1/dz.

The real-production-composer / real-RFM-wrapper / real-Richards probe measures:
- endpoint release: 8.9331194339199466e-4 cm;
- represented matrix compartment dz: 10 cm;
- old matrix receipt: 8.9331194338126974e-5 cm;
- corrected matrix receipt: 8.9331194339070663e-4 cm.

Matrix receipt is measured independently by paired candidate storage and
bottom-flux differences, not inferred from the declared RFM ledger.
The repair changes only release/(dz*dt) to release/dt in the production
composer. It therefore fixes this areic Reference seam. It is not an
approval for all other source/sink implementations.

Local post-repair checks passed:
- A27 actual-composer source-unit correction probe;
- A26 production composer;
- A26 live trial preparer, zero-RFM limit and existing refinement oracle;
- A26 real-Richards source binding, O0/O2;
- A26 serialized backend compile/preservation, O0/O2.

The pre-repair test demonstrated a cross-domain mismatch, despite individual
RFM declared-transfer and matrix solver residual checks. Existing A26 evidence
must not be cited as proof that this actual source receipt equals IC loss
on arbitrary compartment thicknesses. This branch repair is not canonical yet.

## Prototype contact evidence

Analytic signed Darcy intake/release, exact equilibrium, active full-capacity
and empty-donor limits, matrix budget limits, dry-contact no-water control,
unsaturated max-not-sum law, invalid NaN fail-closed and deterministic
20000-point bounds/immutability/replay screen all pass at O0 and O2.

These are stateless process-candidate replay checks, not full backend
checkpoint/restart or reject/retry qualification.

## Evolving Richards evidence

120 cases (2 Ks, 3 initial receiver/matrix cases, 4 exchange modes, 5 timestep
resolutions) completed with 1200 trajectory records. Modes:
0 omitted, 1 reverse-only standard research law, 2 signed standard research
law, 3 proposed signed RFM-inspired contact operator.
dt=0.002,0.001,0.0005,0.00025,0.000125 day; original wet/dry and bottom-recession
geometry comes from FINITE_EXCHANGE_PREREGISTRATION.

Mode 3 additionally binds actual accepted-state matrix K and node sorptivity
from the production constitutive/sorptivity providers. Horizontal K=0.1*K;
length=20 cm, chi=1. Contact age=(step-1)*dt is a research clock,
not a qualified per-contact wetting/reset history. Explicit matrix receipt
budget 100 cm permits through-flow into saturated cells.
No parameter was tuned to match the standard law. Darcy geometry coefficients
differ between the two experiment laws, so differences are not an equivalence
qualification or a full standard/RFM runtime comparison.

Every step passes combined matrix+IC storage versus bottom inflow within
1e-7 cm and receiver bounds 0..5 cm. Max emitted solver residual:
2.518e-15 cm.

Finest-step mode-3 receiver states:
| Ks cm/day | Dry/empty | Wet/empty | Wet/initial 4 cm |
| --- | ---: | ---: | ---: |
| 1 | 0 | 1.750109 cm | 3.371123 cm |
| 5 | 0 | 2.376558 cm | 2.477472 cm |

All receiver endpoint differences contract with refinement.
For Ks=1 initially filled, contraction is slower:
0.000702622, 0.000561125, 0.000436513, 0.000339418 cm.
Therefore no universal first-order convergence claim is made.
Counts and CPU diagnostic timings are preserved but do not demonstrate
a production speedup or better stability.

## Explicitly falsified transition route

Passing mass conservation does not resolve a defective constitutive switch.
The representative-point wet/dry switch jumps when water first reaches a
contact: at fixed dt=0.1 day, changing contact depth by 1e-9 cm changes
release by 0.08040716960416655 cm in the frozen-sorptivity boundary oracle.

A second oracle with nonzero frozen wall-history S shows a jump of
0.05640716960416654 cm when matrix head crosses zero and the law switches
from max(Philip,Darcy) to saturated signed Darcy.
The column prototype recomputes current S, so its contracting trajectories
do not qualify preserving the existing production wall-history semantics.

These jumps falsify direct promotion of this representative-point,
hard-switch prototype as the production two-way replacement.
No arbitrary smoothing factor or residual fitting was introduced to hide them.

## Decision and production boundary

Two-way exchange remains physically motivated by the finite-receiver
experiments. A conservative split can conserve water and evolve Richards
states, but this proposed transition treatment is not integration-ready.

Proceed in two separate tracks:
1. qualify/admit the bounded source-unit repair after current canonical
   dependency reconciliation;
2. resolve finite wetted-contact geometry and the current-state versus
   wall-history sorptivity transition before implementing production
   two-way RFM. Then repeat event/rainfall A/B/C comparisons.

No general RFM equivalence, stability or speed claim is supported.
The full benchmark, worker scaling and original eight regimes remain open.

## Durable evidence

SIGNED_CONTACT_EVIDENCE.json.gz in docs/audits/evidence contains the complete
1200-record CSV, endpoint summary, old and corrected source-unit probes,
and local preservation logs with per-file SHA256 manifest.
Archive SHA256:
f0b87298afe0a5359d6b47ca2fc9607a24274e2cc70ef6c48a82f8e33d1b7485.
Its full repository filename is PPA_WU05A27_SIGNED_CONTACT_EVIDENCE.json.gz.
Transition falsifier output is separately retained as
PPA_WU05A27_SIGNED_CONTACT_BOUNDARY_FALSIFICATION.txt.
Documentation source checks passed previously; strict MkDocs build is not
claimed in this environment.
