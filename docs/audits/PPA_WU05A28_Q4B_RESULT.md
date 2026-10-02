# PPA-WU05-A28-Q4B result — dynamic policy-threshold crossing

Date: 2026-10-02
Status: QUALIFIED_BRANCH_ONLY

## Stage A exact-only fixture selection

Run 37032036237 used exact fixed-64 RFM only. O05 forcing variant 3 is the frozen executable threshold fixture for both geometry variants. It completes 24 days with mass residual below 1e-10 cm and repeatedly moves between the h < -30 cm and -30 <= h < -3 cm bands. Cycle-boundary sampling records 19 transitions over 20 cycles; the first sampled state has no predecessor.

No executable Stage-A candidate visited h >= -3 cm. No forcing was intensified to manufacture that occupancy. Dynamic Q4B therefore qualifies the 64/32 transition; the 16-panel branch remains covered by the 36-material constitutive Q2 frontier rather than this dynamic fixture.

## Stage B frozen exact versus A28_V1

Run: 37034574277
Postimage: 31dd3708632f37a443879ae2b326901bc8013bfe
Artifact: 11240085829
Digest: sha256:a9638c0da39aa043572e6ce1e3f16824642366cb59270c48776b0d0136dbbd79

Both frozen geometry cases complete in exact and approximate mode. Across 40 cycle-boundary pairs:
- max storage difference: 1.4770741785e-7 cm;
- max bottom-outflow difference: 3.1458624505e-7 cm;
- max sampled theta difference: 1.5831882194e-9;
- max approximate mass residual: 9.9759804584e-11 cm;
- max endpoint-water difference: 0 cm.

The fixture retains the Q4 mid-history trusted reconstruction/replay and candidate-discard immutability gates. Both completing exact/approx trajectories pass them.

## Decision

Q4B closes the missing executable dynamic threshold-crossing question for the observed -30 cm A28_V1 transition. Combined with Q1-Q3 and Q4 H1/H2, A28_V1 now has broadened constitutive, short-trajectory, long-history, reconstruction/replay and dynamic 64/32 threshold evidence.

The >= -3 cm 16-panel branch has broad constitutive evidence but no long-history dynamic crossing in this fixture. This is a coverage boundary, not an observed failure.

A28 remains opt-in and non-default. Canonical admission and large MultiSWAP-MODFLOW scaling/coupling qualification remain separate decisions.
