# F-PE-APPROX04 P1 — response-only surrogate prototype

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH_ONLY`

## Frozen envelope

P0 supports an initial local response envelope of:

- same captured origin lineage/revision;
- same coupling window;
- absolute interface-head displacement <= 0.25 cm;
- maximum surrogate age 8.

Outside that envelope the prototype must fall back to an exact physical trial.

## Ownership semantics

A surrogate evaluation returns only:

- predicted groundwater exchange q;
- retained origin tangent;
- provenance that explicitly identifies the response as surrogate.

A surrogate evaluation does not:

- create a SWAP candidate state;
- mark publication readiness;
- mutate committed state;
- increment revision;
- become commit eligible.

## Exact-final rule

After an iterative corrector selects a final interface head, an exact physical trial at that final head is mandatory.

Only that exact final trial may:

- expose candidate state;
- become publication ready;
- be committed.

If exact final validation fails, the corrector result is rejected.

## P1A — deterministic corrector-sequence prototype

Use the six frozen PROFILE06 difficult origins.

For each case create bounded same-origin head sequences that exercise:

- monotone positive displacement;
- monotone negative displacement;
- return toward origin;
- alternating displacement.

All intermediate offsets must remain within +/-0.25 cm.

Compare:

### Exact arm
Every requested head executes a physical participant trial and then discards its candidate except the final validation trial.

### Surrogate arm
- one exact origin response establishes q0 and tangent0;
- intermediate eligible heads use q_pred without a physical trial;
- final head executes one exact validation trial.

Required observations:

- exact physical solve count;
- surrogate physical solve count;
- q error at every intermediate head;
- final exact q identity;
- final candidate validity;
- final endpoint/state identity;
- runtime.

## P1B — performance rule

A prototype is only interesting if it avoids at least 50% of physical corrector solves on the bounded sequences.

Do not count avoided tangent-only work as avoided physical solves.

## Advancement

Proceed to a live coupled prototype only if:

- all final exact validation trials pass;
- no surrogate response can leak into commit state;
- intermediate q error remains within the P0 envelope;
- physical solve count is reduced by at least 50%;
- runtime is speed-positive on at least five of six difficult cases.

No production code change is allowed in P1.
