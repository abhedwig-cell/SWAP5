# F-CI18 exit scope and ownership qualification

Status at materialization: `PERSISTED_EXIT_SCOPE_CANDIDATE_CI_PENDING`.

F-CI18 changes no production source and does not modify the F-CI15 gate names, required flags or fail-closed release rule. It resolves only the scope ambiguity identified by the F-CI16 assessment.

The candidate interpretation distinguishes a canonical-development-baseline gate from downstream capability completion. It proposes qualification of G02, G04, G05, G06, G07, G08 and G09 because the F-CI-owned contract/evidence is present and the unavailable broader capabilities are explicitly fail-closed. G01, G03 and G10 remain qualified.

This is not yet a gate promotion. `F-CI_EXIT_GATES.json` remains at the qualified F-CI17 assessment until the focused F-CI18 gate and complete canonical dependency chain pass on the materialized F-CI18 postimage.

Non-delegable constraints remain provenance integrity, transaction correctness, hard mass conservation for every admitted path, fail-closed behavior for unqualified reference/optional-process capability, and one canonical development baseline.
