# F-CI14 qualification record

Status: `QUALIFIED_CONTRACT_IMPLEMENTATION_REFERENCE_NUMERIC_PROFILE_BLOCKED`.

Qualified production-source change: `da5026d8b87ad2f3c7912360891839a120ecccb6`.
Qualified canonical postimage: `c226988ae0782a7d8d0818f5d4aeaab61b696de4`.
Canonical workflow: `34107845964`, job `101697462464`, PASS on 2026-09-07.

The focused gate passed at GNU Fortran `-O0` and `-O2` and the complete canonical dependency chain F-CI03 through F-CI14 passed. The gate pins the F-CI03 transaction core, F-CI12 temporal characterization and F-CI13 recoverable reference model. It verifies fail-closed unconfigured limits, unit-aware endpoint normalization, diagnostic-only lagged continuation state, temporal rejection/retry/rollback behaviour and unchanged hard mass accounting.

This qualifies the temporal acceptance contract implementation only. It does not qualify numerical B1.10 temporal limits. No solver-convergence tolerance, mass-balance tolerance or calendar rule is reused as temporal-accuracy policy.

The production B1.10 `execute_reference_interval` route therefore remains deliberately not admitted. Release requires independently qualified, source-bound B1.10 temporal limits plus characterization of every active optional process class.
