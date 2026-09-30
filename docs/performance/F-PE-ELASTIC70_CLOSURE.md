# F-PE-ELASTIC70 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_PRODUCTION_SHAPED_PERFORMANCE_CONFIRMED

Canonical baseline:
`integration/f-ci-canonical@a3af828f442da7665615b222a0d3a7e5e614ac53`

Owning application policy:
F-PE-ELASTIC69.

Qualified research authority:
- branch: `research/f-pe-elastic70-production-transaction-performance`;
- qualified postimage: `5c0c81d927198f16a583eb46a26073434698b648`;
- result document commit: `b05de882c535833b0299907118b5300323439d6d`;
- workflow run: `36741177600`;
- job: `109975662353`;
- conclusion: SUCCESS.

## Closed claim

The canonically admitted GENERATED ELAS mode-7 application policy with explicit
caller-owned temporal head budget `0.20 cm` has production-shaped performance
confirmation on the actual ELASTIC65 mass-first serialized transaction path.

Exact difficult discriminator:

- BOFEK/BRO profile 8016;
- exact profile geometry and Staringreeks retention;
- generated Ss prepared through the admitted ELASTIC44 application-host path;
- h0 = -20 cm;
- top-flux perturbations -0.05, -0.035, +0.035, +0.05 cm/day;
- initial attempted dt = 0.015625 day;
- bottom_mode=7;
- swkimpl=0.

## Deterministic work result

Both 0.01 cm and 0.20 cm complete all four cases.

At 0.01 cm:
- 20 total transaction retries;
- 20 temporal rejections;
- accepted substep 0.0009765625 day in every case.

At 0.20 cm:
- 0 transaction retries;
- 0 temporal rejections;
- the initial 0.015625-day attempt is accepted in every case.

Mass rejections:
0 in both arms.

Solver rejections:
0 in both arms.

O0/O2 identity:
PASS.

Production source delta:
none.

Classification:

`QUALIFIED_GENERATED_MODE7_0P20_PRODUCTION_TRANSACTION_PERFORMANCE_CONFIRMED`.

## Timing interpretation

The isolated four-case transaction sequence, repeated 100 times, produced an
O2 CPU-time ratio of approximately 0.179 for 0.20 cm versus 0.01 cm.

This is descriptive supporting evidence only.

Do not translate it into a generic 82% SWAP, MultiSWAP or MODFLOW speedup.
The qualified portable claim is the deterministic removal of 20 temporal
retries in the bounded discriminator.

## Architectural boundary

This result strengthens, but does not broaden, ELASTIC69.

Still unchanged:

- 0.20 cm remains application-owned, not a universal default;
- hard physical mass remains unchanged;
- frozen alpha remains unchanged;
- solver balance tolerances remain unchanged;
- swkimpl=1 remains outside;
- live MODFLOW bottom_mode=5 policy remains a separate route.

No new production implementation or re-admission is required.

## Closure

F-PE-ELASTIC70 is closed.

Further work on this topic should only be population-level mode-7 MultiSWAP
measurement with realistic GENERATED-ELAS column mixtures if such a measurement
is operationally useful.

No additional physical-oracle work or budget widening is required by this line.
