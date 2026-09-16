# SWAP5 deliberate future scope after Status-A

Date: 2026-09-16

This page records capabilities that are deliberately outside the current Status-A denominator. Their absence from Status-A is not, by itself, a defect or open blocker. A capability becomes a release blocker only when an applicable acceptance authority explicitly requires it for the active release boundary.

Current authority is `992a5c657bfe10a10100f92e0cb77c4825ae65b6`; the pinned scientific production baseline is `50346642bd565f79134ea17d5462e544b354998c`.

## FUTURE / NOT CURRENTLY ADMITTED

| Future scope | Current boundary |
| --- | --- |
| EB | Excluded from the current Status-A denominator. No expansion of EB theory, architecture or implementation is implied by this documentation refresh. |
| ROSS / RossFast | Excluded from the current Status-A denominator. No ROSS/RossFast implementation or scientific admission claim is made here. |
| Advanced Snow | Snow beyond the qualified restricted one-call-daily path, including arbitrary-duration, subdaily or broader multi-day semantics, requires separate future authority. |
| Parallel/concurrent real-physics MultiSWAP | Status-A admits serialized MultiSWAP v1 only. Parallel/concurrent real-physics orchestration remains future scope. |
| Broad MODFLOW/backend evolution | The current external groundwater gateway is a structural boundary, not admission of a broad concrete MODFLOW backend or arbitrary future backend semantics. |
| Wholesale legacy IO modernization | Existing IO needed by the admitted baseline remains usable, but a wholesale modernization/redesign is not part of current Status-A. |
| Broad stable public API | Bounded runtime/adaptor surfaces do not constitute a general stable public SWAP5 API. Such an API requires its own contract and admission. |
| Speculative performance optimization | Performance changes beyond separately qualified and admitted work such as the bounded F-PE11 closure remain future work. Status-A does not authorize optimization that changes science, transaction semantics or unqualified execution modes. |
| Other capability extensions | Any extension not named by current Status-A acceptance remains outside the denominator until it receives an appropriate scientific/architectural contract, qualification and canonical admission. |

## Interpretation rule

Future design documents may describe some of these areas in more detail. Such design intent must not be cited as evidence that the functionality is present or admitted now. When future work is admitted, update the current Status-A successor authority and traceability map rather than retroactively rewriting historical documents.

See [SWAP5 Status-A current status](CURRENT_STATUS.md) for the admitted current boundary.