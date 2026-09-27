# F-PE-SCHEDCACHE01 closeout

Date: 2026-09-27

Status: `CLOSED_LOW_RETURN`

Captured-origin schedule caching is semantically clean but performance-neutral.

At N=40,000 it is slightly slower than baseline.

No production source change is authorized.

Recommended next route:
OpenMP placement / affinity qualification on the existing worker-local runtime.
