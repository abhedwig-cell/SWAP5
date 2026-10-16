# F-PE-TEMPORAL04 P1 result — bounded HIST_HALF qualification

Date: 2026-09-26

Status: `PHYSICAL_ENVELOPE_PASS_PERFORMANCE_GATE_FAIL`

## P1A replicated oracle envelope

HIST_HALF:

`budget = max(1e-5 cm, 0.5 * dt * ||h_dot_previous||_inf)`

was repeated three times for every one of the 48 difficult dynamic-history corrector points.

Result:

- completion: 48/48 in all repetitions;
- max terminal |dh| versus refined oracle = 6.5653e-3 cm;
- max |dtheta| = 6.4270e-6;
- max relative terminal-flux difference = 7.199e-3, about 0.72%;
- max relative integrated-exchange difference = 1.677e-3, about 0.17%.

All preregistered physical P1 bounds pass:

- head <= 0.01 cm;
- dtheta <= 1e-5;
- relative terminal flux <= 1%;
- relative integrated exchange <= 0.5%.

## P1B runtime and retry work

HIST_HALF was compared with the FIXED_0P2 high-completion benchmark over all 48 physical points.

Aggregate result:

- HIST_HALF retries: 48;
- FIXED_0P2 retries: 0;
- HIST_HALF temporal rejections: 48;
- FIXED_0P2 temporal rejections: 0;
- solver rejections: 0 in both arms.

Every HIST_HALF point therefore incurs exactly one temporal rejection/retry, while the 0.2-cm benchmark accepts directly.

Paired repeated-trial runtime:

- median HIST_HALF / FIXED_0P2 ratio = 2.2858;
- minimum ratio = 2.1498;
- maximum ratio = 2.3533.

## Interpretation

HIST_HALF is physically well bounded but does not solve the performance objective.

The factor 0.5 follows naturally from the raw defect formula and is conservative enough to keep the oracle error below the preregistered P1 envelope, but it remains just strict enough to force one temporal subdivision on every tested dynamic point.

The looser P0 arms avoid that retry cost, but HIST_ONE and FIXED_0P2 exceed the preregistered P1 head and theta limits.

## Decision

HIST_HALF does not advance to production-shaped coupled replay because it fails the preregistered runtime/retry gate.

Do not relax the P1 physical error bounds post hoc.

No temporal policy is admitted by TEMPORAL04.