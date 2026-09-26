# F-PE-DIR01 Repair04 result

Date: 2026-09-26

Status: `REJECTED_NOT_MATERIAL`

Experiment:
compact trajectory-only serialized attempt-context representation.

## Preservation

The specialized bottom-head directional fixture preserved:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted-step count;
- accepted backsolve count;
- nonlinear iteration count;
- constitutive evaluation count.

No generic transaction-core edit was made.

## Heap effect

The compact context did reduce payload size, but not allocation count.

Across 100,000 intervals:
- malloc count: unchanged;
- free count: unchanged;
- calloc/realloc count: unchanged;
- malloc bytes: reduced by 38,400,000 bytes.

Equivalent per interval:
- malloc count delta: `0`;
- free count delta: `0`;
- allocated-byte reduction: approximately `384 bytes`.

Thus the experiment confirms that the existing full context carries unrelated payload when trajectory is the only active rollback owner. However, the allocator call count remains unchanged.

## Runtime effect

Ten paired same-run measurements gave:

- mean candidate/base ratio: `0.996727238`;
- median ratio: `0.995988698`;
- mean speedup: `0.327276%`;
- median speedup: `0.401130%`;
- mean reduction: approximately `51.6 ns/interval`;
- minimum pair ratio: `0.988665722`;
- maximum pair ratio: `1.014262689`.

The result is too small relative to hosted-runner timing variation to support a production optimization.

## Decision

Repair04 is rejected as not material.

No production code for Repair04 is admitted.

The experiment remains useful evidence:
- reducing attempt-context byte size alone is insufficient;
- allocation count and higher-frequency directional work matter more than compacting the context object;
- future DIR01 repairs should target a repeatedly executed local directional computation or allocation chain with a stronger expected effect.

Repair01 and Repair03 remain the retained DIR01 production changes.
