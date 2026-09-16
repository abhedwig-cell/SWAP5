# F-CI15 qualification record

Status: `QUALIFIED_EXIT_GATE_CONTRACT_NEUTRAL_ASSESSMENT`.

Qualified postimage: `073ccff4096a922095a5c15390a6a6dc949e99aa`.
Canonical workflow: `34108760793`, job `101700562852`, PASS on 2026-09-07.
Full canonical dependency chain: F-CI03 through F-CI15 PASS.

F-CI15 qualifies the machine-readable exit-gate contract, its schema validation and its fail-closed downstream-release semantics. It does not qualify any factual CI-G01 through CI-G10 assessment. Every gate remains deliberately `NOT_ASSESSED` with `allows_downstream_release=false` until a separate evidence-bound assessment is performed.

The contract requires, per gate, `status`, `required`, `evidence`, `source_commit`, `qualification_commit`, `blockers`, `holds`, `last_verified` and `allows_downstream_release`. Commit values, when present, must be exact lowercase 40-character Git SHAs.

No production source, physics, solver policy, mass tolerance or numerical reference profile was changed by F-CI15. In particular, F-CI14's hold remains in force: the B1.10 production `execute_reference_interval` route is not admitted without independently qualified temporal numerical limits and complete active-process characterization.
