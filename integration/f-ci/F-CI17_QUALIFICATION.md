# F-CI17 canonical baseline supersession registry

Status: `QUALIFIED_CANONICAL_BASELINE_REGISTRY`.

Qualified canonical postimage: `4ec5ce2a638047a2468967944902bc7d92f37339`.
Canonical workflow: `34110319677`, F-CI17 job `101705702221`, PASS.
Workflow completion: 2026-09-07T10:16:51Z.
Full canonical dependency chain: F-CI03 through F-CI17 PASS.

F-CI17 qualifies the machine-readable canonical baseline and supersession registry. Exactly one development baseline is active: `integration/f-ci-canonical`. Every other audited integration line is SHA-pinned as `SUPERSEDED_HISTORICAL_ONLY`, is prohibited as a new production-development baseline, and is retained only for lineage, qualification provenance or recovery. `integration/f-ci-canonical-copy` is explicitly not a fallback canonical line.

The immutable `F-CI16_EXIT_GATES.json` replayed successfully in the qualified dependency chain, so later current-gate updates do not mutate the F-CI16 qualification record.

F-CI17 changes no production source, physics, solver policy, numerical tolerance or mass-balance rule. On the F-CI15 exit-gate contract this evidence is sufficient to change CI-G10 from `BLOCKED` to `QUALIFIED`. The overall F-CI downstream-release flag remains false at this closeout because CI-G02 and CI-G05 remain blocked and CI-G04, CI-G06, CI-G07, CI-G08 and CI-G09 still require explicit scope/ownership reassessment.
