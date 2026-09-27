# F-PE-TEMPORAL06 P0 result — production-shaped repeated corrector sequence

Date: 2026-09-26

Status: `REJECTED_BY_TANGENT_RESPONSE_OVERLAP`

## Protocol

Twelve difficult dynamic origin/history groups were exercised under 64 same-origin corrector requests per group.

Each sequence repeated:

`+0.001, +0.01, -0.001, -0.01, +0.001, -0.001, +0.01, -0.01 cm`

eight times.

The existing exact same-origin tangent cache was enabled with head limit 0.005 m and max age 8.

Policies:

- CURRENT_FIXED: 1e-5 cm;
- HIST_HALF: c=0.50;
- SELECTED: frozen blind-validated c=0.65.

Three fresh-process repetitions per group/policy were deterministic in completion, retry counts, cache counts and response checksums.

## Completion and retry result

Across 768 requests per policy:

### CURRENT_FIXED

- completed: 256/768;
- failures: 512;
- retries: 6144;
- temporal rejections: 6656;
- solver rejections: 0.

### HIST_HALF c=0.50

- completed: 768/768;
- failures: 0;
- retries: 768;
- temporal rejections: 768;
- solver rejections: 0;
- tangent cache fresh/reuse: 96 / 672.

### SELECTED c=0.65

- completed: 768/768;
- failures: 0;
- retries: 384;
- temporal rejections: 384;
- solver rejections: 0;
- tangent cache fresh/reuse: 96 / 672.

Thus c=0.65 halves the production-shaped retry burden relative to c=0.50 without introducing solver failures.

## Runtime

Across the 12 origin/history groups:

- median c=0.65 / c=0.50 runtime ratio = 0.73525;
- minimum ratio = 0.45994;
- maximum ratio = 1.01706.

The selected coefficient therefore gives about 26.5% median trial-runtime reduction in this repeated-sequence matrix.

Groups where both policies retain one retry remain near runtime parity. Groups where c=0.65 removes the retry are roughly twice as fast.

## Response overlap

Preregistered overlap limits between c=0.50 and c=0.65 were:

- relative q checksum difference <= 1%;
- relative tangent checksum difference <= 1%.

Ten of twelve origin/history groups pass both limits.

Two groups fail the tangent limit:

- O14 mid, history -0.1:
  - relative q difference = 3.036e-4, about 0.030%;
  - relative tangent difference = 5.8647e-2, about 5.86%.

- O14 mid, history +0.1:
  - relative q difference = 3.032e-4, about 0.030%;
  - relative tangent difference = 5.8648e-2, about 5.86%.

The q response remains very close, but the accepted-trajectory tangent does not remain within the frozen production-shaped overlap envelope.

## Interpretation

The blind-validated c=0.65 policy remains attractive for physical q/state behavior and materially improves retry/runtime performance.

However, changing the temporal acceptance path can alter the accepted-trajectory tangent enough to matter for the MODFLOW-facing linear response even when q itself barely changes.

This is a semantic coupling issue, not a new Richards solver failure.

## Decision

The preregistered production-shaped admission path stops at P0.

Do not proceed to MODFLOW-facing P1 with c=0.65 on the basis of policy-overlap evidence alone.

A subsequent, separately preregistered fresh-only tangent-authority discriminator was executed to diagnose the failed gate. That discriminator did not reopen P1; it established that neither c=0.50 nor c=0.65 published tangent is independently authority-consistent for the O14-mid failure region.

See:

- `F-PE-TEMPORAL06_TANGENT_AUTHORITY_PREREGISTRATION.md`;
- `F-PE-TEMPORAL06_TANGENT_AUTHORITY_RESULT.md`;
- `F-PE-TEMPORAL06_CLOSEOUT.md`.

No production temporal-policy change is authorized.