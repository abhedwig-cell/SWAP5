# F-DOC34 authority matrix — Status-A reference preservation

## Decision surface

F-DOC34 explains what **reference preservation** means for the frozen SWAP5 Status-A denominator and how immutable qualification authority differs from moving/current-source replay. It also corrects stale reviewer-facing navigation that currently presents several suite labels as literal `tests/run-*.sh` paths even though those paths do not exist on the frozen trees.

F-DOC34 does not create a new equivalence claim, rerun scientific qualification, or change production/reference/test semantics.

## Controlling authorities

| Authority | Exact identity | Permitted use |
|---|---|---|
| Live canonical at branch start | `d0a41c39d7ff95db99bcf8360ac9b474fdf164d7` | documentation integration base |
| Frozen Status-A authority | `992a5c657bfe10a10100f92e0cb77c4825ae65b6` | frozen review denominator |
| Frozen scientific production baseline | `50346642bd565f79134ea17d5462e544b354998c` | scientific production postimage |
| Frozen scientific tree | `3b085d7dea3d3f3fce42ad9d8f259a8350205846` | production/reference/test-tree denominator used by scientific qualification |
| Status-A release-readiness record | `tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md`, blob `336a94b22ef508343fa322d7a0cfa84cb9eb30c6` | same-tree reconciliation, inheritance policy, current denominator and release conclusion |
| F-TB11 preservation record | `docs/testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`, blob `7fa2b1acbdb9964b14cdc987caec915f18e2caf1` | stable preservation IDs and distinction between immutable authority and current-source replay |
| F-TB11 replay runner | `testbank/runners/run_ftb11_current_source_replays.sh`, blob `fbfd57f20feae026feeea821043787b83ed35a43` | concrete moving/current-source transaction, mass, restart, MultiSWAP and publication replay on its pinned authority |
| F-SI33 Full Richards completion | `8a162a7b4aa7a67778ed9be454cfcd67d01276ce`; status blob `bd5c582bd249168b71af974e167d29741bf49393` | reference-solver production/reference binding and 100% completion authority |
| Current Status-A traceability | `docs/status-a/TRACEABILITY.md` at branch start | reviewer-facing authority map; may be corrected prospectively where navigation is stale |

## Authority layering

Reference preservation is not one test and not one checksum. The bounded authority chain is:

1. **frozen scientific/reference postimage** — exact commit/tree fixes what is being reviewed;
2. **capability qualification** — e.g. F-SI33 proves the admitted Full Richards reference solver boundary, including production/reference binding and preservation within its stated denominator;
3. **canonical admission** — the qualified capability becomes part of accepted SWAP5 state;
4. **permanent preservation role** — F-TB11 assigns stable regression IDs and protects admitted semantics without copying every historical qualification suite;
5. **same-tree/current-source reconciliation** — the Status-A release-readiness authority inherits unchanged evidence and reruns only dependency-sensitive moving gates.

A later source change does not retroactively invalidate immutable historical evidence, but it does prevent that evidence from being treated as current-head proof until the relevant dependency surface is reconciled.

## Concrete F-TB11 preservation roles

F-TB11 includes stable roles such as:

- `FTB11-FR-001` — Full Richards/reference preservation with exact source/reference provenance;
- `FTB11-TXN-001` / `FTB11-MASS-001` — fail-closed transaction and mass semantics;
- `FTB11-RST-001` — restart continuation;
- `FTB11-MSW-001` — serialized MultiSWAP continuation;
- `FTB11-REJECT-001` / `FTB11-ETPUB-001` — rejected/accepted publication ownership semantics;
- `FTB11-SEAM-001` — mandatory solver seam / no non-admitted HeadCalc bypass.

The executable replay runner materializes independently qualified F-VQ65/F-VQ71 oracle source against its pinned canonical worktree instead of silently treating old fixtures as valid after their contracts became stale.

## Stale path adjudication

The current Status-A narrative and historical release-readiness record refer to names such as `tests/run-baseline.sh`, `tests/run-smoke.sh`, `tests/run-kernel.sh`, `tests/run-transactional.sh`, `tests/run-independent-oracle.sh`, `tests/run-mixed-smoke.sh` and `tests/run-numerical.sh`.

Those literal root-level files are absent from both the frozen scientific tree and the Status-A authority tree. F-DOC34 therefore treats them as historical/umbrella suite labels, **not executable repository paths**. The historical qualification record remains unchanged. Current reviewer-facing documentation should instead link to concrete preservation authorities such as `testbank/runners/run_ftb11_current_source_replays.sh`, capability-specific test directories, and the immutable qualification records that own each claim.

## F-GC29 naming boundary

The Status-A release-readiness narrative uses “F-GC29” as an umbrella attribution for a same-tree residual/preservation reconciliation. Separately, `integration/f-gc/F-GC29_*` contains the Optional Groundwater Response Sensitivity Service Extension. These are not interchangeable authorities. F-DOC34 attributes reference preservation to the release-readiness reconciliation and its pinned evidence, not to the response-sensitivity workunit.

## Claim ceiling

Permitted:

- explain the layered preservation model and exact frozen denominator;
- describe stable F-TB11 roles and the concrete replay runner;
- describe F-SI33 as the Full Richards/reference completion authority;
- state that checksum, closure and O0/O2 claims are bounded by their specific qualified fixtures and authority;
- correct current documentation links/wording where historical suite labels were rendered as nonexistent paths.

Forbidden:

- universal bitwise equivalence for every SWAP configuration or input;
- equivalence of all historical SWAP options to Status-A;
- automatic validity of old evidence after a relevant dependency changes;
- promotion of RossFast or any post-Status-A solver work into the frozen denominator;
- rewriting immutable qualification records merely to improve prose;
- production, reference, test, physics or numerical-policy changes.

## Documentation verdict

`REFERENCE_PRESERVATION_TECHNICAL_REFERENCE_SUPPORTED`
