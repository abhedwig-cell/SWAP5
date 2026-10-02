# TOP03 nonlinear contact decision

The independently reconstructed stationary continuum contact law now passes the bounded synthetic component matrix. The remaining dry-start discrepancy isolates missing layer storage. This is test-only research, not production admission or a field resistance calibration.

## Pinned execution and preserved physics

The discrete finite-volume solver was pinned at `47d76926a401253fc86fa9844ebe5c26cdc8ff55`. It completes 458/468 local points and 9/18 new trajectories. It fails the stationary prerequisite: genuine competing discrete roots remain. At H=0.005 cm, soil head=-0.1 cm, R=0.5 day, m=8, independently balanced roots have fluxes -0.6181689010728271 and -0.6196944462492171 cm/day. Unavailable Newton results do not prove that no root exists.

The continuum extension was pinned at `4338fc4e985f3e9e24825d209dde0eac3c770378`; the execution repair at `0df7ab1a23c84ba06345d88344bbb9680783a0a6`. Integrating the stationary Darcy law changes the spatial oracle, while retaining actual K(h), its saturation jump, gravity, thickness and the matched soil half-cell. The scalar residual is strictly decreasing on the bounded monotone inundation branch. This establishes uniqueness there, not global uniqueness of arbitrary Richards solutions. Seven of eight selected discrete audit points independently establish competing roots with different saturation-cut cell masks; the eighth only establishes an available root.

The initial continuum run exceeded its 30-second process bound. Its in-memory prefix was not recovered. A separately executed O0 replay retained all 494 component controls. Removing redundant multistart work from the provider hot path and raising the process bound to 120 seconds preserves those 494 outputs exactly. Component tests still evaluate all three starts. No tolerance, constitutive law or hidden mutable state changed. No portable performance claim follows.

## Final evidence

Both O0 and O2 complete all 566 cases: 18 saturated controls, 468 local points, eight competing-root audits and 72 coupled trajectories, including all 18 new reduced trajectories. All 54 inherited trajectories remain exact. Final raw O0/O2 records are identical, SHA256 `2f3d76fe46b1b3530f077175735ff4b6f2104ed9c36ec94e0a2b91629ecb4660`.

Independent Python conductivity reconstruction, SciPy Gauss-Kronrod integration and Brent roots pass all 468 local points. Maximum flux error is 1.248743330961588e-10 cm/day, interface-head error 7.062794793455396e-11 cm and integrated length residual 1.033451102472327e-12 cm. All 18 saturated controls pass. There are 431 passing finite-difference derivative controls and 37 unavailable branch-crossing comparisons. Whole-soil mass error is at most 2.212674488077937e-13 cm.

Original numerical-readiness and physical budgets are unchanged. Of 24 event/origin comparisons, ten pass, five fail and nine remain unready with null verdicts. All eight ready prewetted comparisons pass. For dry origins, five intermediate events fail only the external top-transfer budget; two final events pass. This does not qualify the complete dry-start trajectory.

At the final event, the explicit dry layer stores 0.023230139299219014 cm for R=0.5 and 0.02317094487904716 cm for R=1. These equal the reduced model's external-input deficits plus its excess matrix input: respectively 0.02103719187181463 + 0.0021929474274043903 and 0.020157689568580328 + 0.0030132553104668114 cm. The contact law reproduces hydraulic pressure closely, but cannot own this water without a layer storage state. A looser final-event transfer budget cannot remove that mass obligation.

## Next owned slice and admission boundary

Continue with a test-only stateful layer reduction following `TOP03_UNSATURATED_CONTACT_ELIMINATION_DESIGN.md`: immutable layer origin, explicit candidate layer profile/storage, distinct external and matrix transfers, and their difference equal to layer storage change. Qualify accepted-window composition, retry/restore and receipt ownership. Do not hide mutable storage in the dynamic provider or assume that one arbitrary lumped bucket reproduces the distributed layer.

Production solver, constitutive cutoff and BASE exact-state policy are unchanged. Production parameters, thin-layer/R=0 limits, current-canonical solver/runtime reconciliation, rollback/restart and receipt admission remain open. Canonical head `f7c261a7f059c91d4a0aac16e378351f293aa080` was inspected, not admitted. PR #956 stays draft; no Actions run or merge is requested.

## Reproduction

The evidence archive retains phase-specific records, manifests, compiler logs, the initial timeout, independently replayed controls and inherited reference records. Run the two committed analyzers against `nonlinear-primary` and `continuous-replay`, using `--previous extended`, the corresponding pinned `--source` above and `--canonical f7c261a7f059c91d4a0aac16e378351f293aa080`. Component source reconciliation and documentation checks accompany the archive. The two result JSON files retain every local control and every physical readiness verdict.
