# F-PE-TIMEARCH08 result — preferred-step memory separation shadow

Date: 2026-09-28

Status: `QUALIFIED_PREFERRED_STEP_MEMORY_SHADOW`

Authority:

- canonical base: `integration/f-ci-canonical@230f71ee3b2ca991624977fb3b73a2acd5f86f3a`;
- Actions run: `36427522257`;
- job: `108945044965`;
- workflow conclusion: SUCCESS.

## Preservation

PASS:

- TIMEARCH07 full production preservation;
- TIMEARCH06 service preservation;
- 20-case BOFEK Reference preservation;
- worker-context O0/O2 identity;
- standalone/no-worker path;
- shadow source isolation.

The shadow values are not read back into timestep execution.

## Shadow result

Frozen synthetic event grid:

- 36 scenarios;
- every scenario contained event clipping;
- all 36 showed persistent divergence between the legacy post-event proposal and at least one separated-memory shadow;
- median number of divergent decisions per scenario: 46.

Maximum observed shadow / actual preferred-dt ratio:

- RETAIN: 4.0;
- EVIDENCE: about 12.0.

## Interpretation

Hard-event clipping materially contaminates current numerical proposal memory.

The effect persists beyond the single clipped interval because current legacy adaptation grows again from the shortened executed dt.

The EVIDENCE shadow can become much more aggressive than current behavior because it applies numerical growth to the preserved pre-event preference. It is therefore not eligible for direct activation from this observation alone.

The RETAIN shadow is less aggressive, but still materially different from legacy execution.

## Decision

Preferred numerical-step memory and executed event-limited dt should remain separate production concepts.

TIMEARCH08 qualifies the worker-local shadow seam, not a new timestep algorithm.

A behavioral successor must separately qualify whether any preserved-memory rule may influence execution.
