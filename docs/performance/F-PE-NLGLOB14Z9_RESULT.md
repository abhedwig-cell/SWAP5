# F-PE-NLGLOB14Z9 result — control exposure beyond 10:16

Date: 2026-09-30

Status:

`BLOCKED_NLGLOB14Z9_CONTROL_EXPOSURE`

with preserved 4/4 accepted event evidence for `10:16 -> 11:16`.

Qualification authority:

- workflow run: `36670197731`;
- job: `109743355715`;
- workflow conclusion: SUCCESS;
- scientific aggregate: blocked by one post-event fine-RUNOFF endpoint solve failure before the frozen 102.4 d completion horizon.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Does the accepted persistent-KLAG control expose the next physical lower-edge retreat:

`10:16 -> 11:16`

within the staged 51.2 -> 102.4 d horizon, while all four fixtures remain valid through the selected horizon?

## Event exposure

The physical event is exposed in all four fixtures.

HEAD:

- dt 1.25e-4 d: 53.994375 d;
- dt 6.25e-5 d: 53.994500 d.

RUNOFF:

- dt 1.25e-4 d: 53.991250 d;
- dt 6.25e-5 d: 53.9913125 d.

All four accepted transitions are exact:

`10:16 -> 11:16`.

At the event:

- geometry remains contiguous;
- no node is skipped;
- no reverse transition is observed;
- physical mass remains clean.

## 102.4 d aggregate blocker

Three fixtures complete the full selected 102.4 d horizon.

The fine RUNOFF fixture:

- reaches and accepts the physical `10:16 -> 11:16` event at 53.9913125 d;
- remains finite and mass-clean through that event;
- later terminates with `ENDPOINT_SOLVE_FAILURE`;
- therefore does not satisfy the frozen full-horizon completion gate.

Because the preregistered positive classification requires valid coverage of all four selected-horizon fixtures, Z9 remains:

`BLOCKED_NLGLOB14Z9_CONTROL_EXPOSURE`.

The positive classification is not retroactively assigned.

## State and mass evidence

Across the exposed records:

- no reverse late-phase expansion;
- no skipped accepted node;
- no noncontiguous tail;
- no h/theta saturation-indicator inconsistency.

Observed maxima:

- interval physical mass ledger: about `2.36e-14 cm`;
- cumulative ledger: about `3.92e-12 cm`.

Final accepted saturated set after event exposure is nodes 11:16.

## Scientific interpretation

The physical retreat `10:16 -> 11:16` is strongly exposed and temporally stable across both route families and both retained dt levels.

However, Z9 was also a long-horizon completion test. One fine RUNOFF trajectory fails later, so the workunit cannot be closed positively under its original aggregate contract.

The event evidence remains valid as a partial result; the later numerical failure must not invalidate an already accepted physical event, but it does prevent using Z9 itself as the authorization step for further split ownership.

## Direct successor

Open a separately preregistered confirmatory event-exposure workunit with a bounded horizon just beyond the observed event, preserving:

- the same four fixtures;
- unchanged forcing;
- unchanged dt;
- unchanged solver tolerances;
- the same exact accepted event definition.

A 60.0 d confirmatory horizon is appropriate because it independently requires accepted progression beyond the observed ~53.99 d event without importing the later 102.4 d tail requirement.

If all four complete 60.0 d and expose the exact event, that successor may qualify the physical `10:16 -> 11:16` retreat for downstream split testing.

## Production boundary

Research only.

No production `src/**` change.

No production temporal ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
