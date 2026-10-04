# F-GC-STRIP01 C2E: native-registry Dummy-SWAP findings

Date: 2026-10-04. Status: bounded native-registry research qualification passed; matched participant A/B completed; no production admission.

## Result

The 50-column analytic Dummy-SWAP response publishes through the native F-GC49D participant registry/application context and the native MODFLOW6 6.8.0 XMI engine. A single test-only provider per mapped cell keeps trial state, interface flux and tangent self-consistent. The native MODFLOW API package budget independently matches the participant transfer. The test-only provider contract is an additive Fortran seam; production constructors and the C API continue to bind real SWAP participants.

The hydrostatic control published four 0.25-day windows with all 50 heads and dummy states fixed at -1 m, no interface exchange, lateral flow or drain discharge, and exactly zero storage and mass change. Each participant reached revision and interface ledger count four. A deterministic rejection at participant 25 left all dummy states, revisions and ledgers unchanged; MODFLOW was not initialized or finalized, and a clean retry began from the same origin.

Two 120-window cases used 0.001 m/day uniform recharge for 80 windows, then 40 recession windows of 0.25 day each. Input over the strip was 1 m3. Both cases published every window, with converged MODFLOW solves, 120 commits per participant, drain discharge at the left boundary, lateral flow, and a head mound toward the right no-flow boundary.

| Metric | Near-transparent, C=1,000,000 m2/day | Finite resistance, C=0.125 m2/day |
|---|---:|---:|
| Dummy storage change | 0.1181834897 m3 | 0.1196280356 m3 |
| Interface transfer to MODFLOW | 0.8818165103 m3 | 0.8803719644 m3 |
| MODFLOW-owned storage change | 0.4727339582 m3 | 0.4751005439 m3 |
| Left drain outflow | 0.4090825521 m3 | 0.4052714205 m3 |
| Cumulative complete-domain residual | -1.56e-12 m3 | -5.40e-13 m3 |
| Largest absolute window residual | 2.72e-14 m3 | 1.26e-14 m3 |
| Maximum interface action/reaction rate mismatch | 1.39e-17 m3/day | 6.51e-18 m3/day |
| Maximum native MODFLOW storage vs head-derived difference | 2.28e-16 m3 | 2.89e-16 m3 |
| Final right-edge head | -0.9285669 m | -0.9284026 m |
| Maximum internal dummy/interface head difference | 1.00e-9 m | 8.00e-3 m |

The storage partition is disjoint and explicitly research-only: Dummy-SWAP owns its 0.05 m/m linear store and recharge; MODFLOW owns its separate 0.2 m/m research capacitance and the only drain. Interface flux is an internal transfer and is not counted as an external source. The CBC API package rate was compared after converting participant q from m/s to m3/day for unit-width cells. MODFLOW storage came from native `STO-SS` budgets, and was independently checked against storage computed from head change. The complete balance is input minus Dummy-owned storage change minus MODFLOW-owned storage change minus drain outflow minus residual.

The finite-resistance test produces a measurable internal/interface head difference and satisfies the prescribed resistance law to 7.6e-18 m3/day. The near-transparent case reduces the maximum difference to 1.0e-9 m, supporting the zero-resistance limit for this trajectory.

The zero, near-transparent, and finite-resistance result files were each repeated in a fresh process and matched byte for byte. The run was built from local source commit `163ee6e9013046aca74274473c855666f0aa2937`; its complete source tree (`0881328953a2378891fc30771f05cfc570ce9778`) is persisted on the branch as implementation commit `e25eb9f3b2dac2482c8e5f04d02c4430dbbdf743`. The compiler, research library and MODFLOW6 shared-library hashes are in `integration/f-gc/strip01/results/c2e-native/source_manifest.json`. Compressed full window results, compact per-window ledgers and selected 50-head/49-face profiles are persisted alongside it.

## Matched native-harness A/B

The follow-on C2E-AB01 replay uses the same 50-cell mapping, C1 MODFLOW6 6.8.0 strip, native F-GC49D application service, coupling tolerance, 0.001-day windows and 0.001 m/day recharge for both participant variants. The Dummy-SWAP cases replace the real leaf response with the C2E analytic participant; the real case starts from the accepted C2A real-SWAP transaction so the second window retains its Richards temporal history. The real fixture changes only prescribed top infiltration to the preregistered `-0.1 cm/day` before constructing the next window.

| Participant and resistance | C2a zero window | C2b recharge | Recharge-window balance/response |
|---|---|---|---|
| Dummy, near-transparent `C=1,000,000 m²/day` | Published | Published in one window | `5e-5 m³` input; dummy storage `9.9442e-6 m³`; transfer `4.0056e-5 m³`; MODFLOW storage `3.9769e-5 m³`; drain `2.8697e-7 m³`; residual `6.07e-16 m³` |
| Dummy, finite `C=0.125 m²/day` | Published | Published in one window | `5e-5 m³` input; dummy storage `4.9875e-5 m³`; transfer `1.2461e-7 m³`; MODFLOW storage `1.2377e-7 m³`; drain `8.36e-10 m³`; residual `7.83e-16 m³` |
| Real SWAP, `2e-15 m/s` coupling residual gate | Published; all columns revision 1 | Rejected at first `swap-corrector`, iteration 1 | No publication or mass update; profile hash, 50 revisions and 50 ledgers unchanged; MODFLOW timestep not finalized |
| Real SWAP, `1e-12 m/s` sensitivity | Published; all columns revision 1 | Same rejection at first `swap-corrector`, iteration 1 | Same unchanged state and lifecycle outcome |

Both dummy response variants produce a nonzero spatial/lateral MODFLOW response toward the right no-flow edge and left drain flow during this deliberately short matched window. The longer C2E pulse/recession cases establish the larger head mound and substantial drainage response. All four confirmatory results replay byte for byte in fresh processes. The real run's C2a hash is identical to the rejected C2b hash and final hash; all revisions and ledgers remain at 1. MODFLOW lifecycle counts show two prepare/solve calls (one per window), but only the accepted C2a window finalized the solve and timestep.

The primary real-SWAP failure persists when the experimental flux residual tolerance is relaxed from `2e-15` to `1e-12 m/s`; therefore this specific first-iteration rejection is not explained by the coupling residual stopping gate. It is localized to the real-SWAP corrector/transaction path for the tested state and forcing. The experiment does not identify a single Richards equation or prove all real-SWAP states fail.

Full results, selected 50-head/49-face profiles, replay hashes and source/toolchain manifests are under `integration/f-gc/strip01/results/c2e-native/ab01/`. The preregistered protocol is `integration/f-gc/strip01/F-GC-STRIP01_C2E_AB_PREREGISTRATION.json`.

### Exact-origin real-SWAP participant probes

To locate the C2b rejection without changing the native service, each real participant was then run independently and discarded from the exact accepted C2a origin at `t=0.001 d`, interface head `-1 m`, and the preregistered fixed infiltration. The probe uses the exact absolute interval start. It verifies that the committed profile hash, storage, all 50 revisions and all 50 ledgers are unchanged after the diagnostic trials.

All 50 columns returned identical outcome vectors at each tested duration and rate. At `0.1 cm/day`, every isolated transaction has zero accepted substeps, 2 solver rejections, 7 temporal rejections, 9 attempts and 8 retries for the `0.001 d` interval. Its reported temporal head-infinity bound is `0.867884 cm`, versus the C1 research fixture's `1e-5 cm` budget, a normalized indicator of about `86,788`. At `1e-5 d` and `1e-6 d`, the bound remains about `8,679` and `2,745` times the budget respectively, and no substep is accepted. At `1e-4 d`, the terminal observation has no valid temporal estimate; the trial still records 2 solver and 7 temporal rejections with no accepted substeps.

The rate sweep at `0.001 d` separates the zero-forcing equilibrium from a sudden positive fixed-flux onset. Zero flux completes one substep in all columns. Every tested positive rate (`0.0002`, `0.001`, `0.01`, and `0.1 cm/day`) fails in all columns with zero accepted substeps. The outcome is not monotone in the final solver/temporal status fields, because those describe the terminal observation after retries; do not infer a smooth rate law from these five points. The highest rate's large temporal bound and the short-duration probes support a temporal-history/onset limitation in this test trajectory. They do not establish that a full-service rate ramp would pass, nor that this research fixture's head budget is the sole cause.

This rules out a spatially unique outlier in the independently probed homogeneous origin. It does not reveal which participant the application service first sees as failed, because the probes are separate discarded backend calls, not instrumentation inside the serial 50-column service call. The isolated zero-flux pass and positive-flux rejections also do not substitute for the full-service C2b failure. No production temporal budget, solver tolerance, retry policy or coupling semantics changed. The duration and rate contracts, full result arrays, replay identities and source hashes are recorded under `integration/f-gc/strip01/results/c2e-native/ab01/participant_diagnostics/`.

## Claim boundary

This establishes that the tested native registry/application path and MODFLOW strip accept this recharge window, produce a spatial groundwater response and drain discharge, and close mass when using either analytic dummy response. Real SWAP rejects that same recharge window in its corrector, before publication, even with a looser research coupling residual tolerance. Exact-origin isolated probes show identical temporal/solver rejection patterns in all 50 homogeneous participants under the tested positive-flux onset. The evidence supports a real-SWAP temporal-history/transaction-side blocker for this trajectory, rather than a general inability of the native application service, participant registry or MODFLOW strip to respond.

The participant variants use their respective test-only construction fixtures, while keeping native F-GC49D orchestration and MODFLOW execution. This does not prove that all production coupling topologies or real-SWAP states are correct, nor that the experimental MODFLOW-owned capacitance/drain partition is production-authorized. Hupsel and canonical admission remain out of scope. Production tolerances, retry rules, ABI semantics and physical ownership were not changed.

## Build/test note

The C2E research context compiled locally with the C1 profile and the three native cases passed. The existing `tests/fgc/run_fgc49b_fmr_participant_registry.sh` gate segfaulted in `fmr_serialized_storage` on both the C2E worktree and a clean archive of its pre-C2E HEAD, with the same runtime stack. It is recorded as an existing baseline failure, not as a C2E regression or a pass.

## Decision

`DUMMY_STRIP_QUALIFIED_COUPLING_INFRASTRUCTURE_SUPPORTED` — bounded to this native-registry research provider, tested MODFLOW6 strip and declared research storage ownership. C2E-AB01 directly shows dummy publication and MODFLOW response while real SWAP rejects the matched recharge transaction at the corrector for the tested state/window. Do not tune production solver or coupling gates based on this bounded research result alone.

### Lower-rate exact-origin probes

A preregistered follow-up probed all 50 participants independently at `t=0.001 d`, head `-1 m`, and the ordinary `0.001 d` duration with rates from zero through `2e-4 cm/day`. The result JSON from two fresh processes is byte-identical (`08ed03cfce44c24ce7550aa15e5592a49cfe92f829f3fccc4ef3b1d76337c057`). Every rate yields the same outcome in all 50 participants, and the committed profile hash, storage, revisions and ledgers remain unchanged by the discarded probes.

At zero flux, all participants complete one accepted substep. `1e-8 cm/day` also completes in one substep; `1e-7` and `1e-6 cm/day` complete after retries with two accepted substeps. All participants return failure with zero accepted substeps at `1e-5`, `1e-4`, and `2e-4 cm/day`. Thus this fixture has an isolated-probe transition between `1e-6` and `1e-5 cm/day` for the prescribed 0.001-day onset. The temporal indicator is non-monotone across the accepted cases (`0.1386` at `1e-8`, `0.00108` at `1e-7`, and `0.0304` at `1e-6`, normalized by the `1e-5 cm` fixture budget), so this is not a smooth rate law and does not establish a service-level forcing envelope.

These remain discarded component calls from one accepted C2a origin. They do not show that a 50-column real-SWAP service window publishes at any positive rate, and they do not establish that a multi-window gradual ramp succeeds. The primary matched `0.1 cm/day` C2b service window remains rejected at `swap-corrector`. Full arrays, compact table, protocol and toolchain/source hashes are persisted in `integration/f-gc/strip01/results/c2e-native/ab01/participant_diagnostics/`.

### History-aware real-SWAP service ramp

The preregistered full-service ramp starts from the accepted C2a zero-forcing transaction and applies one fixed infiltration rate per 0.001-day native service window, increasing by a factor of ten. All 50 real-SWAP columns publish the `1e-8`, `1e-7`, and `1e-6 cm/day` windows. The next window, `1e-5 cm/day`, rejects at `swap-corrector`, iteration 1. The rejected window leaves the profile hash, all 50 storage values, revisions, and interface ledgers unchanged at revision/count 4. The four-window result is byte-identical across two independent fresh processes (`4ce85c705e20ce753cec1ba12497cd5c2e083aa9adcee19c0f5d7f4eae2a49eb`).

The accepted inputs are extremely small: `5e-12`, `5e-11`, and `5e-10 m3` per window. Each closes against Dummy/SWAP-owned storage change with absolute residuals `2.22e-15`, `6.21e-15`, and `1.82e-15 m3`; the corresponding relative residuals are `-4.44e-4`, `1.24e-4`, and `-3.64e-6`. At these small magnitudes, the relative values expose cancellation in the storage diagnostic and are not used as a convergence gate. Cumulative through the third window, input is `5.55e-10 m3`, storage change is `5.5499783e-10 m3`, drain is zero, MODFLOW storage is zero because this research GWF has no STO package, and the absolute residual is `2.17e-15 m3` (relative `3.92e-6`). Interface transfer remains internal.

The MODFLOW heads remain exactly `-1 m` across all 50 cells and drain flow is zero, so this accepted microforcing range does not demonstrate a measurable groundwater response. The first rejected `1e-5 cm/day` window confirms rollback at the real-SWAP corrector boundary despite gradual history-preserving onset. It does not establish behavior at practical recharge magnitudes or explain the Richards failure mechanism. The ramp harness changes only test fixture context creation and runner support; production solver, transaction, storage ownership, and numerical gates are unchanged. Full results, preregistration, compact mass ledger, source and native-library hashes are persisted under `integration/f-gc/strip01/results/c2e-native/ab01/participant_diagnostics/`.

### Temporal-certificate diagnosis at the ramp failure origin

A preregistered exact-origin replay was run after the failed `1e-5 cm/day` full-service window from the unchanged state at `t=0.004 d`. All 50 discarded participant probes return identical diagnostics: zero accepted substeps, zero solver rejections, nine temporal rejections, zero mass rejections, nine attempts and eight retries. The temporal certificate is available and valid, with normalized indicator `7.8110` against the acceptance limit `1`; the unnormalized head-infinity bound is `7.8110e-5 cm` against the fixture budget `1e-5 cm`. Every probe completes at its start time, and state hash, storage, revisions and ledgers remain unchanged. The two fresh-process result files are byte-identical (`20e3fb14ca467d6798cc403c0495a5b873970981bcc0d51909458df702189354`).

This is confirmatory evidence that the proximate failure at this trajectory and forcing is consistent with the real-SWAP temporal-certificate gate, rather than a solver convergence or mass-rejection outcome. It does not show that the certificate budget is physically too strict: the probes are discarded backend calls, not instrumentation of the exact service-internal call, and the temporal indicator itself has not been independently validated against a refined solution here. No budget or production gate was changed. Addendum, compact result, full replay, and tool/source hashes are persisted alongside the ramp evidence.
