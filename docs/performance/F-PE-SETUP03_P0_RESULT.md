# F-PE-SETUP03 P0 result — prevalidated sequential registry bind

Date: 2026-09-27

Status: `P0_PREVALIDATED_REGISTRY_QUALIFIED`

PR:
`#680 — F-PE-SETUP03: prevalidated sequential registry-bind qualification`

Measured head:
`bb2d13d2be2d7d9c6eee946d8289cb020326f991`

Workflow run:
`36350964184`

## Candidate

The research candidate combined:

1. scalable global tile/ledger uniqueness validation from SETUP02;
2. an explicitly prevalidated registry path used only by the fresh production bootstrap;
3. direct sequential slot placement at `slot = next_handle` when that slot is unused;
4. no per-bind duplicate-tile scan;
5. no per-bind first-unused-slot scan.

The ordinary registry bind path remained unchanged for callers that did not opt into the prevalidated research path.

## Semantic evidence

Duplicate tile/ledger guard tests passed.

Production-shaped warm-trial q/tangent checksums remained exact in the paired benchmark.

No production source was changed.

## Performance

### N=1,000

- baseline app initialize: 0.005650609 s;
- candidate: 0.003996387 s;
- ratio: 0.707249;
- speedup: 1.413929x;
- frozen no-regression gate: PASS.

### N=10,000

- baseline: 0.275338861 s;
- candidate: 0.033161452 s;
- ratio: 0.120439;
- speedup: 8.302980x;
- frozen >=3x gate: PASS.

### N=40,000

- baseline: 3.604299568 s;
- candidate: 0.112957227 s;
- ratio: 0.031340;
- speedup: 31.908534x;
- frozen >=8x gate: PASS.

## Attribution

The results confirm that repeated registry scans were the dominant large-N bootstrap pathology.

The production bootstrap had already established global uniqueness of tile IDs. Nevertheless, every registry bind repeated a full duplicate scan and a first-unused-slot scan.

For a freshly initialized registry filled once in sequence, those repeated scans were redundant.

Removing them under explicit prevalidated fresh-bootstrap authority changes bootstrap complexity from effectively quadratic toward O(N log N) overall because the remaining global uniqueness check is sort-based.

## Decision

SETUP03 qualifies the mechanism for a separate production-admission workunit.

Required production shape:
- retain the generic registry bind API and behavior unchanged;
- expose a dedicated, explicitly named prevalidated-fresh bind procedure;
- production bootstrap may call it only after global uniqueness validation;
- fresh sequential slot/handle invariants must fail closed;
- preserve exact participant identity, handle sequence, tile mapping and registry lifecycle.

Select:

`F-PE-SETUP04 — production admission of scalable bootstrap identity/registry binding`

