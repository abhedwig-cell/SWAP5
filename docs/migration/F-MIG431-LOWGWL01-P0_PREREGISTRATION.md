# F-MIG431-LOWGWL01-P0: shared Richards prerequisite

Status: centrally registered prerequisite; no SWBOTB=1 production admission.
Baseline: `27b271c2f3d1ea54e0110f56b73400e3b6935e11` on integration/f-ci-canonical.
Workstream: central F-MIG431 lower-boundary migration.
Official sole branch: `work/f-mig431-lowgwl01-p0-shared-richards-authority`.
Future application unit LOWGWL01-A is not issued. LOW01-A already denotes admitted SWBOTB=4 and is not reused.

## Reconcile and falsification

LOW05-A is closed through PR#974. SWBOTB=1 remains the next larger line before 3 and 8. It is not a bounded application adapter over existing mode5. Source-authority carrier `integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json` contains the lossless corrected SWAP4.3.1 B1.11 sources. Verify every member hash before extraction. Full corrected-member manifest: `docs/performance/evidence/F-PE19_B1_11_source_manifest.sha256`. No source re-upload is required.

B1.11 readswap.f90:851-873 reads DATE1/GWLEVEL in cm, bounds [-10000,1000], overlap check, and rejects any supplied GWLEVEL above the fifth compartment lower face. Ordinary migration must preserve that geometry/domain guard. Headcalc.f90:94-129 has a higher-groundwater special top branch, but that branch is outside this ordinary parser-admissible slice; it must not be admitted accidentally.

Boundbottom.f90:36-38 samples AFGEN(GWLTAB, ..., t1900+dt). This is a soil-profile vertical coordinate, not the lower-face pressure head HBOT5 and not MODFLOW external datum. Soilwater.f90:79-96 initialization samples t1900+dt-1, sets hydrostatic pressure heads from GWLEVEL-z, and rejects proximity to the lower face at 1e-4 cm. The absolute initial calendar origin and proposal/sibling/retry timing must be reconciled from swap/timecontrol before an application contract is approved. AFGEN interpolation, endpoints, knots, source overlap semantics and unit conversion must be independently frozen, not borrowed merely because LOW05 uses AFGEN.

Headcalc.f90:131-148 selects NN and below-profile fllowgwl. In-profile it solves only NN unsaturated nodes, imposes the groundwater interface gradient, sets saturated water contents below NN, reconstructs all qv and saturated heads, and derives qbot (395-410). Below-profile it derives hbot = GWLEVEL-z(n)+dz(n)/2, with fluxes.f90:28-30 subsequently closing qbot from whole-profile storage and sources. Thus the two branches have different flux/state publication responsibilities. Mode5 equivalence only applies to the below-profile head row, not to the whole mode1 state machine.

## Concrete current blockers

1. Public legacy solver and serialized Reference profile correctly reject mode1. The persisted diagnostic must prove this remains fail-closed, with no candidate emitted.
2. Typed geometry owns exactly n active coordinates. Current ported HeadCalc reads grid_z(NN+1) after NN reaches n. Direct diagnostic bypass of the public guard with n=8 and GWLEVEL=-100 cm reads z(9). Bounds checking reproduces this at O0 and O2. Legacy MOD_grid has spare array capacity, zero-initialized unused z; importing that incidental padded shape into the public typed geometry is not an approved fix. Preserve B1.11 valid-domain branch decisions with explicitly bounded indexing. This finding is typed-port incompatibility, not automatic scientific falsification of B1.11.
3. In-profile groundwater helpers still use global watcon/hconduc/cofgen, including saturated theta and neighbor conductivity, rather than explicit constitutive ownership. Establish provider-consistent interface and saturated-node evaluation; determine whether existing provider calls suffice before proposing a new ABI.
4. Mode1 accepted candidate, derived diagnostic groundwater level, full-node fluxes and compartment/whole-profile mass certificates are not currently admitted. Prove validity of full-node residual publication below NN and the below-profile post-HeadCalc closure. Do not fabricate zero residuals or duplicate bottom accounting.

## Issued scope and held-fixed authorities

P0 owns source-backed design reconciliation and diagnostic qualification for mode1 selection, explicit constitutive evaluation, candidate publication and mode-specific accepted mass ownership. Production implementation is gated on a persisted shared-authority design decision specifying these contracts. The branch is not permission to change other selectors or shared transaction/groundwater/restart semantics silently.

Existing `bottom_head` and state binding `gwlinp` can carry a mode-tagged value structurally; a missing field/new ABI is not proven. Freeze its mode1 meaning before use. Retain exact active-node typed geometry. Keep groundwater fixed-interface/MODFLOW owner, external datum, coupling ledger, public C ABI, runtime acceptance owner and restart format fixed unless a separate central prerequisite is established.

Invariants: solver returns candidates only; rejected trials do not alter committed physical state; accepted accounting commits exactly once; explicit inputs/providers own physics; forcing is not committed groundwater state; numerical history is not restart authority; physical modes remain separate from controller policy.

## Mandatory exit gates before LOWGWL01-A

- Freeze DATE1/GWLEVEL, geometry admissibility, initial-state timing, original-proposal versus sibling/retry evaluation and exact near-node/interface tolerances against B1.11.
- Qualify in-profile, near-node, below-profile and crossing cases at O0/O2 against frozen B1.11 decisions and numerical behavior, including heterogeneous constitutive inputs where claimed.
- Prove all physical nodes remain represented in storage/state despite reduced NN unknowns; explicit provider ownership, candidate groundwater diagnostic and full-node mass certificates.
- Prove reject/replay/restart equivalence and exactly-once accepted bottom amounts, independently recomputed from unrounded storage/source/boundary terms.
- Preserve admitted SWBOTB=2/internal -2, 4, bounded ordinary5, groundwater-owned5, 6 and7 through dependency-aware gates. No claim for8 or9.
- Persist required qualification/admission evidence only after production postimage exists. Local negative feasibility is not that qualification.

## Recovery

Read `integration/audits/F-MIG431-LOWGWL01-P0_STATUS.json` first. Runner `tests/fmig431/run_lowgwl01_feasibility.py` builds a fresh isolated closure at O0/O2 with bounds/FPE checks; its support fixture is FSI04, not whole-model E2E evidence. The raw diagnostic intentionally bypasses the public guard and must never be exported as production use. Central status will record the exact persisted postimage and result after replay. No production sources are changed by this registration.
