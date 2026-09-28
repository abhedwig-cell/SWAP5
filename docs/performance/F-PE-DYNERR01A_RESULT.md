# F-PE-DYNERR01A result — false-safe boundary-transition attribution

Date: 2026-09-28

Status: `REGIME_PATH_MISMATCH_CONFIRMED`

Authority: Actions run `36418142458`.

The DYNERR01 false-safe at B01/POND, dt=0.02 d is a boundary-path mismatch:

- full-step final regime: HEAD;
- first-half final regime: FLUX;
- second-half final regime: HEAD.

The full endpoint has ponding, the first half does not, and the second half returns to the head-boundary route.

Across the 60 complete mechanism points this is the only observed full/half regime-path mismatch.

Therefore the severe false-safe is attributed to an unrepresented dynamic-top regime transition, not to mass loss or an unavailable provider derivative.

This attribution changes no DYNERR01 gate or outcome.
