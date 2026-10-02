# TOP03 stateful distributed-contact preregistration

Date: 2026-10-02. Test-only proposed contract. Baseline: 1f507d6cc18f995ef7c171b61d3eb7601669da02.

Implement a distributed finite layer with immutable accepted origin, candidate pressures/water contents and separate integrated external and matrix transfers. Every compartment satisfies dz*(theta_candidate-theta_origin)/dt + q_up-q_down=0. External input minus matrix input equals layer storage change. Only the fixture owner advances layer state after accepting the coupled candidate; provider evaluation never advances it.

The primary numerical policy deliberately matches the explicit SWKIMPL=0 comparator: internal layer faces and layer/matrix interface use conductivities at the immutable step origin, while the top arithmetic boundary face uses candidate conductivity as in the comparator. This is a time-discrete reduction, not a current-K stationary closure. The separately qualified continuum stationary law remains unchanged. A diagnostic current-candidate-K option must remain clearly separate and cannot silently substitute for the primary scheme.

Retain actual retention/K laws, saturation jump, gravity, L=0.2 cm and R=0.5/1 day. No lumped bucket, smoothing, production solver change, provider hidden history, finite BASE exact-state tolerance or receipt admission.

Primary coupled matrix: m=8,16,32 and ns=128,256,512; explicit dry/wet, constant R, stateful dry/wet, both O0/O2. Eighteen saturated limit controls. Preserve inherited 54 trajectory records exactly. Fail unavailable solves explicitly. Root status does not prove nonexistence. Use deterministic immutable-origin seed; qualify branch ambiguity separately before general admission.

Hard gates: local compartment residual 1e-11 cm/day; layer transfer/storage closure 1e-11 cm; two-sided interface head 1e-10 cm; accepted local/kernel flux 1e-10 cm/day; whole layer+soil mass 1e-10 cm; immutable soil and layer origin; exact O0/O2 physical records. Compare using unchanged spatial/temporal readiness and original top/interface/bottom/water/head budgets. Null readiness stays unavailable, never pass.

Lifecycle gates before production: same-origin changed-head trial/replay, rejection, retry with smaller dt, accepted full/half transfer composition, candidate-storage receipt validation and restart continuation. These must be actual tests, not inferred from intent(in). A full-step and two half-steps need not have identical physical states; each branch must close independently, and only the selected branch may be published.

Canonical a89990169fb8429a0fd143df9e3d28b9a35d28b8 has relevant newer macropore storage-increment and matrix-area changes in kernel/provider/contracts. Hold the research baseline fixed. No current-canonical qualification inheritance or merge is asserted. Invariants 3,7,8,11,13,14,28 apply. PR #956 remains draft.

Recovery: new test-only stateful module, fixture and runner, then pinned O0/O2 matrix and independent face/storage audit. Persist source before expensive execution. Negative evidence and execution failures are retained.