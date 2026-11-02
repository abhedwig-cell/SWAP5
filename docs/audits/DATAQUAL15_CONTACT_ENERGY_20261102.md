# DATAQUAL15 contact and exact energy composition, 2026-11-02

Status: **Executed diagnostic evidence; contact repair and full energy OPEN.**

Baseline is canonical `972bfc237794caacbbecd3017a7769149ad0d32f`, after
Windows native restart admission in PR1483. Measurement postimage is
`176a33d58`; no `src`, `app` or `reference` change is made by this unit.
The source bindings and sealed measurements are in
`integration/dataqual15/CONTACT_ENERGY_RESULT_20261102.json`. Reproduce with:

```bash
python -B tests/dataqual15/verify_contact_energy_evidence.py
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
