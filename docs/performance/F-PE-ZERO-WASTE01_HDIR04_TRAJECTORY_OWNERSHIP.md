# F-PE-ZERO-WASTE01 H-DIR04 — trajectory ownership transfer

Date: 2026-09-25

Status: `NEGATIVE_REJECTED_ROLLED_BACK`

Authority parent: `f3c8e1642310f7303802e23f187d1f4981e39539`

Candidate: `e0b9a7ba0aa8dfece9e2e150d2d106e3c34907d9`

## Hypothesis

The accepted directional trajectory copied two N-vectors from the step result into pending state and copied them again from pending into current trajectory state. Because pending vectors are cleared immediately after acceptance, ownership transfer with `move_alloc` appeared to be a pure data-movement optimization.

## Component evidence

Shared-CI microbenchmark:

| N | pending allocate+copy+deallocate | second two-vector copy | four move_alloc transfers |
|---:|---:|---:|---:|
| 60 | 31.40 ns | 13.39 ns | 1.93 ns |
| 200 | 73.82 ns | 35.89 ns | 1.86 ns |
| 1000 | 243.76 ns | 184.60 ns | 1.87 ns |

The component benchmark therefore confirmed real copy/allocation work.

## Candidate qualification

The candidate retained the generic copy-stage API and added a serialized consuming stage. Validation occurred before ownership transfer, and accepted pending vectors were moved into current trajectory state.

Direct contract evidence passed:

- `FPE_ZERO_WASTE01_HDIR04_COPY_API_PRESERVED=PASS`
- `FPE_ZERO_WASTE01_HDIR04_CONSUMING_IDENTITY=PASS`
- `FPE_ZERO_WASTE01_HDIR04_PREMOVE_FAIL_CLOSED=PASS`
- `FPE_ZERO_WASTE01_HDIR04_O0_O2_IDENTITY=PASS`

Broad preservation gates also passed.

## Isolated runtime result

Exact parent-versus-candidate directional paired run:

- mean candidate/parent ratio: 1.002118524
- median ratio: 1.000498243
- mean speedup: -0.211852%
- mean delta: +35.887320 ns/interval
- N=10
- paired harness verdict: PASS

The effect is neutral-to-negative at application-host scale. The component savings do not resolve into end-to-end benefit and do not justify extra ownership complexity.

## Decision

Reject and roll back the production ownership-transfer candidate.

Retain the copy-cost measurement and this negative result as evidence. Do not reopen H-DIR04 without a materially different ownership design or evidence from a workload where trajectory-vector movement is demonstrably dominant.
