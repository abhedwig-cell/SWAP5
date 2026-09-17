# PUB-GC E1 screening provenance correction

Status: **authoritative chronology correction**

Publication owner: `PUB-GC`

This decision corrects the screening authority after two workflow executions became visible on `research/pub-gc-e1-screening`.

## Chronology

1. `PUB-GC-E1-SCREEN-0001` was preregistered at commit `5c5d30273437bfc5082d2c91a75d25681cc8d15d` on 2026-09-17T23:05:04Z.
2. Before any SCREEN-0001 workflow execution began, `PUB-GC-E1-SCREEN-0002` was preregistered at commit `bc8dca037912de10dbfce33d1ca7a62b34bc7761` on 2026-09-17T23:06:56Z and explicitly declared `supersedes_before_execution: PUB-GC-E1-SCREEN-0001`.
3. The reason was prospective: SCREEN-0001 reused the already observed qualification pair `B=-70 cm, dt=0.02 d`; SCREEN-0002 replaced it with a disjoint class-based 21-row grid before screening output existed.
4. SCREEN-0001 nevertheless executed later, beginning 2026-09-17T23:09:03Z. Because it had already been superseded, that run is non-authoritative for stress-class selection regardless of its successful technical completion.
5. Commits `4377317335a5d895aef58afab5d46d23f20a6162` and `8471425a1fb32a82cd4c94ed05fc4b3bba3cce60` incorrectly treated SCREEN-0001 as the controlling screening result. Their repository history is retained, but their scientific/readiness interpretation is superseded by this correction.
6. SCREEN-0002 used manifest authority `bc8dca037912de10dbfce33d1ca7a62b34bc7761`, blob `2aef35c16f1b7c87ebd7ff572adeb24e4e830ee4`.
7. Before SCREEN-0002 execution, commit `37e72ae755bce9920db7f157082fa13def3fea22` prospectively authorized one workflow-only push trigger because the connected execution surface had no workflow-dispatch action.
8. The scientific screening bytes immediately before that trigger were frozen by immutable Git state `a46acf93ae7918293f88f095c4138f617be1b64e`: test blob `7b598d103bf23c19c4dace8e9fdfebd264cd02a5`, runner blob `79654bb6901b33f291cf316db7e9cb915ef5e8c7`, dispatch-only workflow blob `bc58a6f75107446e0ba571c6e1abc3153bae45cc`.
9. Trigger commit `13bed3b93330bf403be96e0b7886274206c954b9` modified only `.github/workflows/pub-gc-e1-screening.yml`; no screening oracle, runner, production source, origin-harness or GW-A bytes changed.
10. SCREEN-0002 run `35285701916` started at 2026-09-17T23:11:42Z and completed successfully at 2026-09-17T23:12:37Z.
11. After the run, commit `6f60cec1442ebaa15cb47baba25ff62a9499d6e9` restored the workflow to dispatch-only.

## Code-head-lock deviation

The SCREEN-0002 manifest retained the literal placeholder `FREEZE_BEFORE_EXECUTION` in its inline `screening_code_commit` / `code_head_lock` fields. This field was not retrospectively edited before execution.

The actual scientific code freeze is therefore represented by the immutable pre-trigger Git state `a46acf93ae7918293f88f095c4138f617be1b64e` and the prospective trigger decision `37e72ae755bce9920db7f157082fa13def3fea22`.

This is recorded as a **provenance-format deviation**, not hidden or rewritten as if the placeholder had been populated. The scientific design, 21-row grid, metrics, selection rule, holdout rule and scientific code bytes were fixed before SCREEN-0002 output existed.

## Authority decision

- SCREEN-0001: **NON_AUTHORITATIVE_SUPERSEDED_BEFORE_EXECUTION**.
- SCREEN-0002: **authoritative prospective supporting screening**, subject to its declared nonclaims.
- No numeric result from SCREEN-0001 may guide the primary E1 design.
- SCREEN-0002 may select only the broad duration / perturbation class / sign specified by its manifest.
- The exact SCREEN-0002 row and all previously observed qualification/screening numeric points remain excluded from primary reuse.
- Neither screening establishes or falsifies H1.

This correction changes evidence authority only. It does not alter production code, model physics, qualification state or the screening data.
