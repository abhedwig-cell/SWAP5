# F-PE-MIQUAL09 closeout — paired equilibrium serialized-runtime benchmark

Date: 2026-10-01

Final status:

`MIQUAL09_EQUILIBRIUM_PERFORMANCE_NOT_READY`

MIQUAL09 is closed as a qualified negative performance result.

The moving-interface manager is physically exact and reduces deterministic nonlinear work by 18.75%, but the current serialized runtime composition is about 5.5% slower in both wall and CPU time across 11 preregistered pairs.

This is sufficiently stable that more repetition of the same benchmark is not useful.

Direct successor:

`F-PE-MIQUAL10 — serialized manager overhead attribution and zero-waste adapter audit`.

The successor should:

- profile/cost the manager adapter path;
- remove only redundant runtime work;
- preserve full accepted-state authority;
- preserve exact full fallback/bypass;
- preserve the MIQUAL06 eligibility envelope;
- re-run the unchanged MIQUAL09 benchmark after each admitted optimization candidate.

Do not relax physics or benchmark gates to obtain speedup.

Production default remains `LEGACY_NUMERICS`.
