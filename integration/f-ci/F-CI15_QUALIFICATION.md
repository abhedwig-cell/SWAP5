# F-CI15 qualification record

Status at materialization: `PERSISTED_CI_PENDING`.

F-CI15 persists the machine-readable F-CI exit-gate contract before any further automatic downstream release decision. It deliberately makes no factual assessment of whether a gate is currently met. Every gate starts at `NOT_ASSESSED` with downstream release disabled.

The contract defines CI-G01 through CI-G10 and requires, per gate, `status`, `required`, `evidence`, `source_commit`, `qualification_commit`, `blockers`, `holds`, `last_verified` and `allows_downstream_release`.

The focused gate validates the exact gate set, status vocabulary, required fields, commit-SHA syntax when populated, fail-closed release semantics and consistency of the top-level downstream release flag.

F-CI15 changes no production source, physics, solver policy, mass tolerance or reference numerical values.
