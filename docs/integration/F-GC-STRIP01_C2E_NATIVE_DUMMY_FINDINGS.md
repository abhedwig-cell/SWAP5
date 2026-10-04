# F-GC-STRIP01 C2E: native-registry Dummy-SWAP findings

Date: 2026-10-04. Status: bounded native-registry research qualification passed; no production admission.

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

## A/B interpretation and claim boundary

This establishes that the tested 50x1 native registry/application-context and MODFLOW strip can handle the prescribed recharge/recession forcing, spatial groundwater response, lateral flow, drain discharge, transaction publication and mass ownership when the real Richards participant is replaced by the analytic Dummy-SWAP response. The corresponding C2B real-SWAP path rejects ordinary full windows in the SWAP corrector after a separate experimental coupling-residual stopping issue is relaxed; it had no measurable groundwater response in its bounded accepted segment. The comparison supports a real-SWAP/Richards transaction-side blocker for the tested trajectory, rather than a general inability of the native registry and MODFLOW strip to respond.

This is a matched geometry, mapping, MODFLOW parameterization and forcing-envelope comparison, not a bit-for-bit rerun of real SWAP through the C2E test fixture. It does not prove that all production coupling topologies or real-SWAP states are correct, nor that the experimental MODFLOW-owned capacitance/drain partition is production-authorized. Hupsel and canonical admission remain out of scope. Production tolerances, retry rules, ABI semantics and physical ownership were not changed.

## Build/test note

The C2E research context compiled locally with the C1 profile and the three native cases passed. The existing `tests/fgc/run_fgc49b_fmr_participant_registry.sh` gate segfaulted in `fmr_serialized_storage` on both the C2E worktree and a clean archive of its pre-C2E HEAD, with the same runtime stack. It is recorded as an existing baseline failure, not as a C2E regression or a pass.

## Decision

`DUMMY_STRIP_QUALIFIED_COUPLING_INFRASTRUCTURE_SUPPORTED` — bounded to this native-registry research provider, tested MODFLOW6 strip and declared research storage ownership. C2B's separate corrector failure is consistent with a Richards/transaction-side limitation at the tested forcing/window regime. The next useful discriminator is a same-harness real-SWAP replay if a test-only provider hook can preserve all canonical participant semantics; no production solver or coupling gate should be tuned on the basis of this dummy result alone.
