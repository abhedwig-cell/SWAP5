# F-PE-TEMPORAL07 P1 result

Date: 2026-09-26

Status: `PASS_PRODUCTION_CACHE`

## Protocol

The existing production tangent cache was enabled with unchanged controls:

- head limit = 0.005 m;
- max age = 8.

Ten difficult dynamic origin/history groups executed the 64-request same-origin sequence.

Authority:
- cache-disabled c=0.65 q and exchange for each request;
- fresh c=0.65 tangent at refresh points.

## Result

For every group:

- fresh tangent evaluations: 8;
- tangent reuses: 56;
- q with cache versus cache-disabled authority: bit-identical;
- integrated exchange with cache versus cache-disabled authority: bit-identical.

Aggregate:

- groups: 10;
- maximum absolute q difference: `0.0`;
- maximum absolute exchange difference: `0.0`;
- invalid reuse events: `0`.

No solver rejection or ownership change was introduced.

## Decision

P1 passes.

The production tangent cache is behaviorally transparent for the frozen c=0.65 response map within the qualified repeated-sequence envelope.
