# PPA-WU05-A28-Q4 preregistration — long-history approximate RFM envelope

Date: 2026-10-02
Status: PREREGISTERED

## Question

Does A28_V1 remain bounded relative to exact fixed-64 RFM when wall history is repeatedly accumulated, dried, reactivated and replayed over trajectories much longer than the 0.20-day Q3 screen?

## Frozen numerical policies

Exact arm: RFM exact policy, 64 panels.
Approximate arm: RFM_SORPTIVITY_POLICY_A28_V1:
- h < -30 cm: 64;
- -30 <= h < -3 cm: 32;
- h >= -3 cm: 16.

No soil-, cycle- or case-specific retuning after execution.

## Long-history forcing families

Use the existing ten-cell A27 production fixture and both B01 and O05 parameterizations, both geometry variants, with three deterministic histories:

H1 pulse/recovery: repeated strong rain pulse followed by dry recovery.
H2 clustered storms: two wet pulses separated by a short dry interval, then long recovery.
H3 threshold cycling: moderate pulses chosen to repeatedly traverse the -30 and -3 cm panel-policy boundaries.

Each history runs at least 20 wet/dry cycles and at least 100 times the Q3 trajectory duration. Sampling occurs at every cycle boundary.

This remains a controlled numerical production fixture, not climate validation.

## Gates

For every exact/approximate jointly completed case:
- mass residual <= 1e-6 cm at every committed interval;
- cumulative total-input/output accounting remains complete;
- final total-storage difference <= 0.02 cm;
- maximum cycle-boundary total-storage difference <= 0.02 cm;
- maximum sampled theta difference <= 0.01;
- maximum endpoint-water difference <= 0.02 cm;
- wall age remains finite/nonnegative;
- wall sorptivity remains finite/nonnegative;
- no approximate-only solver/admission failure relative to exact.

Record nonlinear iterations, retries and wall time. Timing is diagnostic only.

## Replay/restart semantics

At a fixed mid-history accepted-state boundary:
1. capture the committed state/checkpoint;
2. execute the next interval and retain its accepted post-state;
3. restore/reconstruct from the same accepted boundary and execute the identical forcing interval again;
4. require bitwise-identical committed RFM state and exact equality of sampled matrix state for each policy.

A rejected/discarded trial from the same checkpoint must not mutate committed RFM state.

This gate tests deterministic replay/transaction ownership. It does not claim external file-format restart qualification unless an actual serialized restart path is exercised.

## Decision boundary

Q4 passes only if all histories and replay gates pass without policy retuning. Passing Q4 can support an A28 long-history production-candidate claim. It does not itself establish canonical admission, MultiSWAP scaling performance, MODFLOW coupling stability or a portable speedup.

## Q4 design note

Repository inspection shows that `fmr_capture_checkpoint` exposes checkpoint capture for trial/retry semantics, but the A27 fixture does not expose a public committed-state restore-from-checkpoint operation. Q4 therefore separates two claims:

- **replay from accepted state**: create two independent committed-state copies from the same accepted snapshot and execute identical forcing; require identical results;
- **transaction rollback**: exercise candidate discard and verify the original committed state is unchanged.

Do not label either test as external serialized restart. File-format restart remains outside A28 unless a real restart API is located and exercised.

## Reconstruction refinement

A later bounded inspection located the public trusted persistence boundary `kernel_reconstruct_committed_state_trusted`. Q4 may therefore additionally reconstruct a fresh committed carrier from an accepted physical snapshot plus its original lineage, revision and committed time, then replay the next forcing interval. Require the reconstructed and uninterrupted paths to produce bitwise-identical RFM state and exact sampled matrix state.

This qualifies the in-memory trusted reconstruction contract for this RFM continuation state. It still does not qualify a particular external restart file codec or parser.
