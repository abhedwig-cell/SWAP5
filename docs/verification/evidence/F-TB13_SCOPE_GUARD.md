# F-TB13 scope guard

F-TB13 is testbank/evidence preservation only.

Allowed delta:
- `.github/workflows/f-tb13-legacy-analytical-reference-preservation.yml`
- `tests/legacy_reference/extended_analytical/**`
- `docs/verification/F-TB13_LEGACY_ANALYTICAL_REFERENCE_PRESERVATION.md`
- `docs/verification/evidence/F-TB13_*`
- `integration/f-tb/F-TB13_STATUS.json`

Forbidden in this work unit:
- `src/**`
- `reference/**`
- production physics or solver changes
- timestep/retry policy changes
- mass-tolerance changes
- promotion of steady-state solute historical metrics to a release gate
- Basha completion claims
- claims of SWAP5 production solver equivalence
