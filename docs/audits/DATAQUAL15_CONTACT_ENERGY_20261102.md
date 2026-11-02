# DATAQUAL15 contact and exact energy composition, 2026-11-02

Status: **Canonically admitted diagnostic evidence; contact repair and full energy OPEN.**


## CLOSURE16 current-source numerical successor

The exact isolated stock-comparison correction is now installed in the current
production accounting module on the CLOSURE16 development branch. Canonical
admission is separate. Its raw measurements and consumer are
`integration/dataqual15/STOCK_PRODUCTION_CORRECTION_20261102.json` and
`python -B tests/dataqual15/verify_stock_correction.py`.

Checked GNU13.3 O0/O2 each accept all864 corrected stock representations and
reject all864 injected1J/m2 inconsistencies. The complete output equals the
earlier isolated candidate byte for byte. All864 raw theta-domain rejections
and all864 missing-advection rejections remain per build. The physical
variable-water residual remains exactly1.4503270298455375J/cm2 at gauge0C.
This is a numerical accounting repair, not a heat-equation or energy-transport
repair, and it changes no water, crop, thermal state or restart schema.

Current runtime preservation compiles186 real providers per optimization and
executes unchanged EB-I22/I23/I24/I25 tests with both accounting objects.
I22/I23/I24 pass at O0/O2. I25 fails with both objects on its external full-half
outflow fixture, with identical complete stdout and ERROR STOP reason; the
failure remains explicit. All eight paired old/new tests preserve behavior.
The first runner invocation stopped before compilation because an independent
shared source edit was not yet committed. The final measured run uses the
persisted shared source; no numerical result is inferred from the failed launch.

The original4.3.1 reference and current restricted numeric heat process both
use average moisture-dependent heat capacity multiplying the temperature
change. This is distinct from the endpoint change of `C(theta)*(T-Tref)`.
Exact endpoint storage additionally contains
`sum(dz*delta(C)*(Tmid-Tref))`. Conduction plus that identity cannot determine
advective donor energy: accepted water fluxes, donor temperatures and root/lateral
exports are required. Assigning that missing term from the residual would
produce closure by construction. No such receipt is invented here.
Full energy and the original failed whole-project scientific gate remain open.

The commands below reproduce immutable predecessor observations in explicit
historical mode. They do not inherit current-source qualification. Actual
current production is compiled by the three successor qualification runners
listed in the correction manifest. No full1827-day repeat was selected: this
accounting module is absent from the executed Grassgrowth build inventory,
and no Grassgrowth physical owner changes in this heat successor.

PR1484 is admitted at `ff7a2a7a808720ded0a11e7f000dc25a03e3b8b8`. All16
PR workflows are terminal SUCCESS; actual whole tree equals the tested tree.
The actual-merge sealed dossier verifier passes. Windows16.2 and Linux13.3
O0/O2 stdout are exact for all three experiments. Receipt:
`integration/dataqual15/CONTACT_ENERGY_CANONICAL_RECEIPT_20261102.json`.
Linux observations and artifact identity are retained in
`CONTACT_ENERGY_LINUX_OBSERVATIONS_20261102.json`. No production patch is installed.

Baseline is canonical `972bfc237794caacbbecd3017a7769149ad0d32f`, after
Windows native restart admission in PR1483. Measurement postimage is
`176a33d58`; no `src`, `app` or `reference` change is made by this unit.
The source bindings and sealed measurements are in
`integration/dataqual15/CONTACT_ENERGY_RESULT_20261102.json`. Reproduce with:

```bash
python -B tests/dataqual15/verify_contact_energy_evidence.py --historical
python -B tests/dataqual15/qualify_andelst_contact.py --output ../contact-fresh
python -B tests/dataqual15/qualify_energy_boundary.py --output ../energy-fresh
```

The first command verifies source identities, archived build and executable
identities and independent observations; it never executes archived binaries.
The latter commands compile actual current public production interfaces, with
checked O0/O2. Each Windows16.2 pair has byte-identical stdout. The new Linux
workflow independently runs both compilation closures; its result is recorded
separately and is not inferred from the Windows measurements.

## Andelst contact: ruled-out local remedies

`ANDELST_CONTACT_CAUSE.json` remains the authority for the actual coupled
Andelst state. The new driver uses its node26 pressure head and top26/top27
topology pair, with explicitly synthetic other DTO fields. It calls the real
sorptivity and unsaturated absorption owners; it does not claim to replay the
full historical DTO or regenerate the observed0.0223321cm/day jump.

There are36 controlled cases per build: dt1e-3/1e-8/1e-13day, entry width
0/1e-4/1e-3cm, perturbation1e-4/1e-6/1e-8/1e-10cm. The whole-cell mask leaves
a finite0.11805cm/day jump even at the smallest dt. Amount decreases with dt;
the rate jump does not. Central differences scale as jump/(2epsilon).
Smoothing the entry-pressure gate leaves this separate topology jump intact.
This bounds the next repair: changing Newton budget, dt alone, or the entry
gate cannot make this controlled residual differentiable.

A continuous partial-wall partition changes a law also present in B0; it is
not automatically a B1 bug correction under ADR-0005. A numerical event or
active-set treatment must instead establish the intended contact law and
show accepted mass closure, no double exchange, rollback, restart and full
original481-day execution. Neither alternative is silently installed here.

## Heat plus exact stock and boundary ledger

The432 explicit component inputs are recovered byte-for-byte from completed
Sprint04 branch `75907a72b30e3d7180c6a715e1492eda3bf6197a`, archive SHA256
`46ba4ef8101cf8a4b533f3d8c12761fb20d71488ea634e9f5f77862be29ed277`.
Its historical109-file archive is retained under
`SPRINT04_ENERGY_COMPONENT_INPUTS.tar.xz`. These are derived snapshot and
interpolated-water/counterfactual component inputs, not accepted application
hydraulic substeps. Old whole-tree qualification is not inherited.

The new executable composes the current restricted heat owner with the existing
exact linear-mixture stock and whole-column energy ledger owners. It evaluates
reference temperatures0C and5C, with an independent Python endpoint-stock
calculation. It exposes two previously untested interface problems:

1. All432 raw input profiles contain theta above the rounded porosity by at
   most1.1102230246251565e-16. The heat owner permits1e-12; the exact stock owner
   rejects any excess. All864 raw stock evaluations retain their real
   `WCSA_STORAGE_FAILURE`. The diagnostic then explicitly clips only its
   accounting copy, bounded by64 machine epsilons; original input bytes and
   the actual heat calculation remain unchanged. This is not a production
   normalization policy or an unqualified change to the strict storage domain.
2. After that diagnostic normalization, all864 missing-advection evaluations
   correctly return `WCSA_INCOMPLETE_BOUNDARY` without publishing a balance.
   With explicitly counterfactual zero advection,632/864 evaluations return
   `WCSA_BALANCE_FAILURE`: sum of per-node stock changes and difference of
   whole-column stocks disagree at roundoff scale. The source check scales
   its comparison by the small change rather than the accumulated stock.
   The original rejection is retained, including when a projected numerical
   balance is available. Independent endpoint stock agrees within6.854e-9J/m2.
   A future numerical correction should use a justified summation-error bound
   and retain genuine mismatch and missing-boundary rejection controls.

The zero-advection residual equals the composition term
`sum(dz * delta(C) * (Tmid - Treference))` within1.716e-7J/m2. This independently
confirms the retained conduction-equation limitation:

| Component experiment | Gauge0C max absolute residual J/cm2 | Gauge5C |
| --- | ---: | ---: |
| Frozen water | 1.575e-11 | 7.061e-12 |
| Interpolated variable water | 1.45032703 | 0.74084669 |
| Isothermal5C | 1.12017292 | 1.515e-12 |
| Isothermal0C | 0 | 1.12017292 |

The gauge dependence is expected when the energy carried by changing water
and displaced gas has not been supplied. Neither assigning zero nor inferring
an advective receipt from the residual is acceptable physical closure.

## Executed isolated numerical correction

`STOCK_PROJECTION_NUMERICAL_CANDIDATE.patch` supplies a concrete correction of
the representation-consistency check. It accumulates absolute endpoint stocks
and uses the floating-point summation bound gamma(4n+4), alongside the existing
small-change comparison. It does not alter energy storage, boundary receipts,
physical residuals, theta acceptance, heat solving or completeness scope.

`qualify_stock_projection_candidate.py` applies that reviewable patch in an
isolated Git fixture and links the resulting module into the same actual
component driver. On persisted postimage `e8a7de63a`, Windows16.2 checked
O0/O2 each accept all864 normalized stock representations, with zero
roundoff rejections. A separate injected1J/m2 stock inconsistency is rejected
in all864 evaluations per build. The raw864 theta-domain rejections remain;
the physical1.45032703J/cm2 variable-water residual remains numerically exact.
Both candidate and fault-control O0/O2 pairs have identical stdout.

The immutable candidate experiment is in
`STOCK_PROJECTION_CANDIDATE_EVIDENCE_20261102.tar.xz`, with build commands,
actual source, patched/fault source, executables, logs and result metadata in
`STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json`. The Linux workflow repeats
the candidate and fault controls. This correction is implemented and tested
as an isolated candidate; it is not applied to current production or called
a full-energy qualification.

## Next executable implementation boundary

The candidate can next enter the numerical accounting owner through its
explicit dependency/admission reconciliation, with these actual113-node inputs
and the1J negative control as regressions. The theta-domain mismatch
needs an explicit shared input contract before changing a production owner.
Neither correction adds a water-energy transport law.

Full-energy work still requires actual accepted interval receipts: top and
bottom water transfer with donor temperature, root extraction, lateral and
macropore transfer, and a consistent reference including displaced gas. Internal
transfers must cancel pairwise; negative flux selects the opposite donor. The
atmospheric/plant scope must additionally name radiation, latent/vapor energy
and freeze/thaw where applicable. Current sensible-only results deliberately
keep `full_energy_balance_complete=false`. No denominator, full scientific
equivalence or production promotion changes.

Canonical restart merge CI is now terminal: runs41424758938,41424758951 and
41424759098 pass. Runs41424758946,41424758966,41424758982 and41424758992 retain
their existing DATAQUAL12 `unreviewed delta` source-guard failure. These failures
are not converted into scientific PASS.

## CLOSURE16 matched original/current heat owners

The new test calls the **unmodified compiled B1.11** `temperature_numeric`
and current `trial_restricted_soil_temperature` on identical explicit geometry,
texture, old temperature, water endpoints, air temperature and duration. It uses
all432 immutable Sprint04 inputs, not an inferred accepted application trajectory.
The original source is reconstructed and manifest-verified from the existing
B1.11 authority; no copied heat formula stands in for the original solver.

Checked GNU Fortran13.3 O0/O2 each complete432 paired evaluations. Their complete
stdout is byte-identical. Heat capacities agree exactly and the maximum nodal
temperature difference is1.066e-14C. Independent endpoint storage evaluated from
the **original** solved temperatures retains a1.450327029850J/cm2 variable-water
gap,1.120172916227J/cm2 for isothermal5C and2.754e-12J/cm2 at fixed water.
Original and current conductive boundary energies differ by at most4.832e-13J/cm2;
the original boundary flux is evaluated directly from original `tetop`, `heacon`
and solved `tsoil`, independently of the SWAP5 boundary ledger.
Thus the selected heat equation and its variable-water energy limitation are
shared with B1.11. They are not a new SWAP5 heat-solver implementation difference.
This does not prove full coupled trajectory equivalence, explain every forcing
route or establish physical completeness of the original formulation.

Result, raw measurements, actual original build manifests and the first failed
controller aggregation are retained in
`integration/dataqual15/PAIRED_HEAT_OWNER_RESULT_20261102.json` and its named
capsule. The first native O0 run completed but result aggregation incorrectly
requested kind4 instead of the actual kinds0..3; no physical assertion failed.
The corrected runner completed both optimization modes. Reproduction:

```bash
python -B tests/dataqual15/qualify_paired_heat_owner.py --compiler /usr/bin/gfortran --output /tmp/paired-heat-new
```

### Minimal physically complete coupling path

The immediate blocker is **accepted interval donor-temperature provenance**,
not absence of a water mass ledger. `app/grass_project/initial_interval.f90`
already requests accepted water substeps and consumes their root sinks, but
`fmr_water_flux_substep_trace_t` has no node temperature endpoints. The heat
owner itself receives only start/end hydraulic views and has no face, root or
lateral water-energy transfers. Endpoint water changes cannot uniquely recover
those transfers or the temperature of external incoming water.

| Existing owner | Reusable authority | Remaining change |
| --- | --- | --- |
| `mod_fmr_water_flux_trace_contract` | Accepted times, water endpoints, top/bottom rates, root and signed drainage/source vectors | Append matched pre/post node temperatures to the same rollback-selected trace; retain forcing and accepted-state identity. |
| `mod_fmr_bottom_thermal_carrier` and external thermal provider | Accepted local outflow donor endpoints and explicit external inflow response | Bind real Grassgrowth bottom exchange; external incoming temperature must remain unavailable until supplied. |
| `mod_eb_i25_multisubstep_sensible_boundary_runtime` | Rollback-safe multisubstep top conduction and explicit liquid inflow donor | Does not qualify soil-side top outflow or snow/melt mixing. Do not replace rainfall/irrigation water temperature with air temperature. |
| `mod_liquid_water_sensible_enthalpy` | Existing signed water amount and donor-temperature sensible transport law | Reuse it for each accepted root/lateral/face transfer, selecting the upstream donor by sign. |
| `mod_whole_column_sensible_energy_accounting` | Exact mixture stock and explicit top/bottom boundary projection | No root or lateral energy fields exist. Add explicitly available root/lateral and displaced-gas transfers before claiming the entire rooted/drained column balance. |

First implement the accepted thermal endpoint capture in the existing trace,
then assemble root extraction and outward drainage energy from those local
accepted donors. For inward lateral/bottom/top water, require explicit external
donor temperatures. Trace capture must be transactional: rejected full and half
trials cannot publish receipts, and file restart must reproduce selected accepted
intervals. Internal face contributions use one amount and one donor evaluation
with equal and opposite signs, so they cancel exactly in column accounting.

Next solve a conservative equation for the same exact mixture stock, driven by
those independently obtained signed energy transfers and conduction. Merely
adding endpoint composition change to a boundary ledger would manufacture
closure and is excluded. The displaced pore-gas energy convention must match the
gas capacity already included in exact storage; otherwise changing the reference
temperature changes the alleged energy residual. Surface evaporation also needs
a declared liquid/vapor/latent boundary convention. Grassgrowth has SWSNOW0 and
SWFROST0, but root extraction and SWDRA1 are active, so omitting those sinks is
not a valid simplification for this project.

Installing advective heat physics changes the shared B1.11 conduction formulation.
It therefore needs an explicit separately qualified SWAP5 model change, or a
reference correction only if the intended original formulation is shown to have
been implemented incorrectly under ADR0005. Literal-equivalence tolerances must
not be broadened to hide this distinction. Thermal timestep-error control and
the failed preregistered coarse-native temperature test remain separate from
that physical development. No complete-project or scientific denominator changes.

## CLOSURE16 current Andelst reconstruction

A clean GNU Fortran13.3 checked O2 build of canonical7a7f994d executes the
unchanged prepared original physical input from day1 with sharp entry (width0).
The90-second bounded observation completes day1 and source intervals through
1.9400000000023283days, then is censored. Its day1 water residual is
-1.1442e-14cm. This is neither a natural solver failure nor a full project.
An initial direct launch with literal CLI width0 was rejected by the existing
positive-width grammar; the corrected invocation uses the existing empty
argument for sharp entry. Both observations are retained.

The separate authentic2.748-day historical payload is rebound only in its
executable binding and CRC for a current-source diagnostic. That historical
payload and control retain the0.0001cm entry ramp; this is not an original
sharp-route restart qualification. Baseline failure takes18.08s and rejects
with29874 nonlinear iterations,2523HeadCalc calls,416 accepted internal
substeps and minimum accepted dt8.8818e-16day. The complete rejected stream
is byte-exact to the diagnostic origin.

A real HeadCalc observer tests a specific implementation hypothesis: the
dynamic top boundary might refresh macropore residual flux while the existing
freeze flag suppresses its derivative. The observer stops if that conjunction
occurs. It does not occur anywhere on the failing replay; the unmodified
failure is reproduced in17.73s with exact rollback. No speculative Jacobian
change is installed. This negative result does not qualify all freezing routes.
The independently measured sharp-entry and perched-topology discontinuities
remain the direct blockers. Changing iteration limits or smoothing only the
entry gate does not establish a conservative original contact solution.

Exact fresh build manifests, observations, original bound commands, the
observation source and rollback streams are sealed in
`integration/dataqual15/CLOSURE16_CURRENT_ANDELST_EVIDENCE.tar.xz`.
Machine-readable source/input scope is
`integration/dataqual15/CLOSURE16_CURRENT_ANDELST_RESULT.json`.
Validate with `python -B tests/dataqual15/verify_closure16_andelst.py`.
The archived replay launcher records its original workspace paths; independent
reproduction must first build the pinned source using
`tools/solute/build_project.py --native-water --optimization O2`, then substitute
the new build/root paths while preserving all scientific command arguments.
No archived executable is required or executed by the verifier.

The original481-day execution is still OPEN. The corrected-wall/ramped130-day
result is retained under its prior, different physical/numerical scope. No new
fully executed project, whole energy qualification or denominator increment is
claimed. The direct next Andelst implementation must give the discontinuous
exchange a conservative numerical event/contact treatment, with one identical
accepted exchange receipt for matrix and macropores and intact rollback/restart.

CLOSURE16 actual admission: PR1486 merged at58b89f37 with the complete tree
7aa11305 byte-exact to the qualified candidate. All three new evidence consumers
pass on the actual merge. Sixteen of17 PR workflows pass; the remaining Hupsel
Sprint03 source-pin failure is independently reproduced on unmodified canonical
7a7f994d and retained as FAILURE. The existing recovery record owns the receipt
under `closure16_canonical_receipt`. No production or full-scientific promotion.
