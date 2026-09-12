# F-TB09 integrated column physics, process interaction and conservation catalog

## Decision boundary

F-TB09 establishes the permanent **catalog contract** for integrated single-column physics qualification. It does not claim that all catalogued combinations already execute end-to-end or have passed scientific qualification. That distinction is deliberate: the current SWAP5 canonical contains qualified process and runtime building blocks, while the architecture status remains narrower than a fully integrated production kernel.

Canonical base at branch creation: `42544af575db522d012db491db801615577048df` (tree `4360cd08fd0e952978df9e2742bcc34fdede9ef1`).

During the live precondition check canonical advanced by F-CI49 from the initial observation to this base. Because TB09 still had no commits, the branch was fast-forwarded cleanly. F-CI49 qualifies restricted solver-service transaction and dynamic-top-boundary infrastructure with hard mass conservation; it does not itself supply the integrated process-interaction cases below.

The exit decision is:

`QUALIFIED_INTEGRATED_COLUMN_PHYSICS_TESTBANK_CATALOG_ESTABLISHED`

and becomes closed only when the F-TB09 workflow is green on the exact branch head.

## Rechecked authority chain

F-TB01 through F-TB08 were rechecked live before branch creation. Their exact branch heads and latest exact-head Actions runs were all successful. They are pinned in the machine-readable manifest. F-TB08 and the current canonical have diverged histories, so F-TB09 does **not** merge the TB08 branch. It reuses the immutable authority commits while adding only TB09 support files on top of the current canonical.

This avoids importing stale production history from a testbank authority branch.

## Existing coverage and non-duplication rule

The repository already has permanent or canonically admitted owner coverage for constitutives, Full-Richards/reference qualification, transaction/restart/MultiSWAP semantics, surface evaporation, root attribution and root uptake, DIVDRA/drainage, effective forcing, WOFOST physical binding and restricted soil-temperature runtime.

Those are building blocks, not a substitute for interaction qualification. F-TB09 therefore owns only the **cross-process seam** and shared column water ledger. It must not create second primitive owner tests.

In particular:

* generic restart remains owned by F-TB04; TB09 adds restart *during an active process interaction*;
* surface evaporation remains owned by F-PM06E/F-CI39/F-CI41; TB09 checks partitioning and drydown interaction;
* root uptake remains owned by F-MR35/F-CI37; TB09 checks its interaction with ET partition and crop development;
* drainage remains owned by F-MR36/F-CI36; TB09 checks its interaction with a changing bottom boundary;
* variable forcing remains owned by F-MR38/F-CI40; TB09 uses forcing changes to cross process transitions;
* WOFOST owner tests remain separate; TB09 adds a hard column water ledger across crop-development/root-uptake interaction;
* soil temperature stays inside the restricted F-TB06/F-CI43 scope. TB09 does not infer new thermal-hydraulic physics.

Targeted live repository searches did not identify existing permanent cases named for ponding+runoff, ET partition, or restart+mass interaction. Absence of a search hit is not itself scientific evidence; the ownership map above is the actual anti-duplication rule.

## Conservation oracle

Every TB09 case is water-bearing and therefore has an explicit mass oracle. The governing testbank identity is the F-TB01 mass ledger:

`DeltaStorage = Sum(Inputs) - Sum(Outputs)`.

For the current canonical result contract this is reconciled with `docs/verification/mass-accounting-contract.md`: the arithmetic residual over `[t0,t_end]` must close, and `mass_error_mm` is a reported residual, not a bookkeeping correction.

No process, solver, profile or fallback may buy acceptance by relaxing mass conservation. Numerical/physics tolerances are separate. Roundoff evidence may be machine-aware but may never become a water-loss budget.

## Oracle policy

The F-TB01 hierarchy is retained without modification: O1 exact, O2 manufactured, O3 independent numerical, O4 qualified Full Richards, O5 source-bound SWAP4.3.1, O6 property/invariant, O7 cross-solver consistency. The highest applicable oracle wins.

TB09 introduces no O5 legacy case and constructs no corrected golden baseline. Full Richards is used as the designated qualified numerical reference where appropriate, but an O4 label does not physics-qualify a case until exact reference execution evidence is pinned.

## Bounded pairwise/risk selection

F-TB09 intentionally does not cover all 55 pairs among the eleven requested physics dimensions. It selects the seams with the greatest conservation, ownership or transition risk:

| Case | Infiltration | Surface storage | Runoff | Soil evaporation | Root uptake | Drainage | WOFOST | Soil T | Bottom boundary | Variable forcing | Wet/dry |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 001 rain/pond/runoff | P | P | P |  |  |  |  |  | P | P | P |
| 002 ET partition/drydown |  |  |  | P | P |  |  |  | P | P | P |
| 003 drain/bottom |  |  |  |  |  | P |  |  | P | P | P |
| 004 WOFOST/root |  |  |  | P | P |  | P |  | P | P |  |
| 005 wet/dry reversal | P |  |  | P |  |  |  |  | P | P | P |
| 006 soil-temperature/forcing |  |  |  |  |  |  |  | P | P | P |  |
| 007 restart during ponding | P | P | P |  |  |  |  |  | P | P | P |
| 008 Full-Richards risk reference | P |  |  | P | P |  |  |  | P | P | P |

Mandatory risk pairs are machine-checked in the manifest. Pairs such as crop×runoff, crop×drainage, soil-temperature×runoff and soil-temperature×drainage are **not claimed covered**. They stay deferred until a scientific or production risk justifies a bounded case and, for soil temperature, until the relevant physics is admitted.

## Profiles

FAST contains only cheap high-value transition cases. CANONICAL adds broader interaction and restart coverage. RELEASE includes all cases suitable for release gating. DEEP contains the more expensive bottom-boundary, crop, restricted soil-temperature, restart and Full-Richards reference-oriented cases.

Profile choice never changes the physical configuration or the hard mass gate.

## Case admission states

All eight entries initially use `CATALOGED_NOT_PHYSICS_QUALIFIED`. This is not a weakness in the exit decision; it is the intended boundary. F-TB09 qualifies the permanent catalog, metadata, oracle hierarchy, conservation equations, bounded selection and execution-profile assignment. A future owner execution may promote a specific case only by pinning its executor, inputs, exact reference/evidence and scientific tolerances.

The validator rejects any attempt to mark a TB09 entry physics-qualified without changing this catalog contract.

## Defect routing

If execution of a TB09 case exposes a production defect, record the failing evidence and open a separate owner workunit. F-TB09 must not repair production source, quietly widen tolerances, redefine a process owner, or replace the reference.

## Architecture invariants

`integration/f-tb/F-TB09_INVARIANT_AUDIT.json` records all 30 project invariants. The strongest active checks here are generic time, transaction/restart integrity, hard mass conservation, Full-Richards reference availability, process reuse, physics/policy separation, bounded cost, diagnostics, optional-feature scope and explicit non-coupling claims.
