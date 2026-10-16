# F-PE-NLGLOB05A result — floor-aware convergence certificate discrimination

Date: 2026-09-29

Status:

`NLGLOB05A_MIXED_CERTIFICATE_SIGNAL`

Canonical base:

`integration/f-ci-canonical@01adcb51992615e7a09016f1ce63a244c40acf3c`

Qualification authority:

- workflow run: `36540512902`;
- certificate-discrimination job: SUCCESS.

## Frozen question

Can a single post-backtracking Newton-state snapshot distinguish terminal numerical exhaustion at the qualified storage/balance floor from genuinely unresolved earlier Newton states, while preserving the existing head and ponding convergence contract?

The frozen C0 certificate required:

- `r_bal <= 10`;
- dominant `r_storage_ulp <= 10`;
- existing head contract `r_head <= 1`;
- existing ponding contract when applicable;
- finite diagnostics;
- unchanged route consistency;
- iteration > 1.

No solver behavior was changed.

## Coverage

PASS.

- bank cases: `96`;
- endpoint-failure cases: `96`;
- audited iterations: `768`;
- diagnostic coverage: `1.0`;
- process failures: `0`.

## Terminal discrimination

C0 certifies:

`96 / 96`

terminal endpoint-failure states.

Terminal certification fraction:

`1.0`.

Every route/mode family certifies:

`16 / 16`

terminal states.

Thus the target terminal population is fully covered.

## Hard negative controls

All hard state-local negative controls pass perfectly:

- NC1 above-floor iterations: `292`, rejection `1.0`;
- NC2 head-unresolved iterations: `244`, rejection `1.0`;
- NC3 ponding-unresolved iterations: none present in the frozen audited population, rejection treated as `1.0`;
- NC5 storage-floor-absent iterations: `278`, rejection `1.0`;
- route mismatches: `0`.

The certificate therefore does not confuse clearly unresolved balance, head, storage-floor or route states with numerical exhaustion.

## Decisive negative control

The independent early-iteration control fails strongly.

NC4 contains:

`576`

iterations earlier than the final two Newton iterations.

C0 false-positive fraction:

`0.49306`.

The preregistered maximum was:

`0.01`.

Therefore nearly half of the early Newton trajectory already satisfies the same local balance-floor, storage-floor, head and ponding snapshot conditions as the terminal failure.

This is the decisive failure.

## Frozen classification

The full qualification gate fails.

The hard unsafe controls do not fail, and terminal usefulness is high, so the preregistered residual classification is:

`NLGLOB05A_MIXED_CERTIFICATE_SIGNAL`.

NLGLOB05A does **not** qualify:

`NLGLOB05A_FLOOR_CERTIFICATE_DISCRIMINATION_QUALIFIED`.

## Interpretation

The current endpoint blocker cannot be certified safely from a state-local snapshot alone.

NLGLOB04 remains valid: the terminal residual is at a storage representation floor.

NLGLOB05A adds that the same representation-floor signature can occur much earlier while useful Newton evolution is still occurring.

Therefore:

- being at the storage floor is necessary evidence of exhaustion in this bank;
- it is not sufficient evidence of terminal exhaustion;
- existing head and ponding convergence do not supply the missing specificity;
- an admissible certificate must contain trajectory/history evidence about **lack of further progress**, not merely current-state thresholds.

This is not a reason to loosen any tolerance.

## Consequence

NLGLOB05B test-only acceptance replay is **not authorized** from C0.

Do not:

- accept every state in the one-decade floor neighborhood;
- alter BALTOL02;
- alter head or ponding tolerances;
- change physical interval mass acceptance;
- tune C0 thresholds post hoc.

A successor may investigate a separately preregistered **trajectory-exhaustion discriminator** based on already observed Newton/backtracking history, for example persistence at the floor together with collapse of achievable merit improvement.

Such a successor must retain the NLGLOB05A early-iteration population as a mandatory negative control.

## Production boundary

Research-only result.

No production `src/**` change.

No numerical default or physical mass authority change.

`LEGACY_NUMERICS` remains production default.
