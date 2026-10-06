# Source-bound master coverage disposition decisions

Status: WORKSTREAM_DISPOSITION_DECISIONS_FOR_REVIEW.
Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`.
These decisions change migration scope records, not production physics or the
frozen Status-A denominator. They require review with the master audit PR;
no new runtime option is activated.

## SW431-LOW1: REJECTED

The legacy prescribed-GWL moving/internal saturated-profile boundary is
intentionally excluded from this SWAP5 migration. The existing lower-boundary
closeout already parks it by decision. This master decision makes the coverage
disposition explicit instead of leaving a permanent parked state.

Source authority: B1.11 `boundbottom.f90` 36..38, `headcalc.f90` 94 onward and
`soilwater.f90` 81 onward. The route prescribes an interior groundwater level,
changes the solved/saturated profile and derives boundary fluxes through that
special profile algorithm. It is real legacy physics and is classified
CORE_PHYSICS, not file plumbing. No claim is made that it is mathematically
invalid or that its old mass balance necessarily fails.

Project rationale: retain explicitly owned fixed-interface aquifer exchange,
typed lower-head/flux/resistance boundaries and a single groundwater storage
owner. Do not add a second internal groundwater-level/profile-reset authority
inside the soil solver. The current fixed-interface MODFLOW capability and
LOW03/LOW05 are separately admitted capabilities; they are not claimed as
numerically equivalent replacements for LOW1. This is a deliberate scope
rejection, not SUPERSEDED and not whole-groundwater rejection.

Evidence: `docs/migration/F-MIG431_LOWER_BOUNDARY_CLOSEOUT_2026-10-03.md`,
`docs/integration/SWAP5_MODFLOW6_FIXED_INTERFACE_CLOSEOUT.md`, and the ownership
rules in `docs/architecture/invariants.md`. Reintroducing the historical LOW1
semantics would require a new explicit project scope decision and independently
qualified ownership contract.

## SW431-KMEAN: SUPERSEDED as numerical compatibility

B1.11 `functions.f90` 4..62 selects arithmetic, geometric, harmonic weighted or
unweighted intercell conductivity, or a supplied Darcian lookup in
`MOD_Kavg_Szym.f90`. These are face-flux discretization policies for the same
Richards/Darcy soil-flow capability, not independent persistent constitutive
models or storage processes. SWAP5's admitted Reference Richards face-flux
provider supplies that intended functional capability with its qualified
numerical policy. No equality of trajectories across all seven legacy
averaging choices is claimed.

The source mean choice must therefore not block physical coverage solely
because a historical numerical knob has no typed selector. This decision does
not remove or reject any retention/conductivity constitutive equation, hydraulic
layering, hysteretic reversal state, elastic storage or vapour contribution.
Those have separate capability IDs and dispositions. Any future reason to
reproduce a particular legacy discretization belongs in a separately qualified
numerical compatibility workunit, without changing physical ownership.

Implementation authority: the Reference Richards hydraulic provider and solver
contract. Qualification/admission authority: F-SI09 and the current Reference
Richards production baseline, as recorded in
`docs/science/soil-hydraulic-constitutive-relations.md` and
`docs/status-a/CURRENT_STATUS.md`.

## IHWCKMODEL=4: SUPERSEDED by the admitted unimodal MvG provider

The actual WC_K_models_04_11 dispatcher identifies model 4 as unscaled unimodal MvG, not PDI. Its Gamma1 retention law, Mualem conductivity and analytic capacity derivative are the same intended physical relations delivered by the default production provider at zero entry head. The provider supplies its qualified numerical saturation and dry-end regularization; selector preservation or bitwise trajectory equivalence is not the functional requirement. The source-bound reproducible comparison gives maximum relative errors below 9e-14 for theta/K/C over 24 cases at each of O0 and O2. The tested domain and exclusions are persisted in SWAP431_MODEL4_CURVE_REVIEW.json. This replacement does not dispose of models 5–11 or persistent hysteresis.
