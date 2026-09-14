# F-RG05 — Current-Canonical SWAP5 Program Rebaseline

## Decision

F-RG05 rebaselines the governed SWAP5-v1 program against the exact current canonical observed at authoring:

- canonical: `integration/f-ci-canonical@24b02660a7924323d1587b4adf77a160c9ef7d04`
- tree: `fd14037490b62750e133eacb3d429de2b06f7f9a`
- source tree: `22b94efb12543cce9945ba0ccefdf9a9a612de51`
- reference tree: `9d08625217d7c0a7385df9da6a04183bcd9cb9e6`

The current canonical is the F-CI65 admission of the independently qualified F-GC24 coupled restart/split-run/replay postimage. F-CI65P postimage reconciliation was still active when this snapshot was authored. F-RG05 does not turn that admitted child capability into G05 parent completion.

The qualified program measurements remain:

| Measurement | F-RG05 |
|---|---:|
| Restricted Production Baseline | 100.0% |
| Technical Engine measured | 89.905063291139% |
| Active technical ceiling | 89.0% |
| Technical Engine reported | 89.0% |
| Overall frozen SWAP5-v1 | 83.004545454545% |

This is intentionally unchanged from F-RG03.

## Why the score does not increase

F-RG01C freezes the denominator and gate fractions. F-RG04 additionally forbids evidence-to-authority, child-to-parent, qualification-to-admission and composition-to-production auto-promotion. The post-F-RG03 work therefore changes the score only when it closes an explicit previously unearned parent gate.

The main later advances do not meet that condition:

- F-PM19 plus F-TB12/F-TB12P make drainage-v1 completion and permanent preservation much stronger, but D06 was already 100%.
- F-RG04 strengthens scientific evidence, qualification, assurance, composition and admission governance, but GOV02 was already fully credited and GOV03 is not release-ready.
- F-DOC17 improves Status-A reconciliation but does not change the public working count: 2 of 22 remain SATISFIED/CLOSED.
- F-TB11/F-TB11P permanently protect already-qualified 100%-capabilities but do not themselves close T02 or T03.
- F-SI38 is a qualified prescribed-qbot temporal-certificate source capability, not a canonical-admitted true whole-window groundwater response tangent.
- F-CI64/F-CI64P Energy Balance work has frozen SWAP5-v1 weight 0.
- F-GC24/F-CI65 is a genuine G05 restart/replay sub-capability advance, but the G05 end-to-end composition remains incomplete.
- RossFast remains research-only with frozen SWAP5-v1 weight 0.

This is not a claim that the repository made no progress. It is a statement that governed program completion is not allowed to increase without a matching frozen parent gate.

## Domain snapshot

| Domain | Completion |
|---|---:|
| D01 Kernel / transactions / generic time / mass | 100.0% |
| D02 State / persistence / restart | 100.0% |
| D03 Full Richards / soil-water reference solver | 100.0% |
| D04 Soil-water solver interface | 100.0% |
| D05 ET / root uptake / surface evaporation | 100.0% |
| D06 Drainage / restricted surface-water completion | 100.0% |
| D07 Crop / WOFOST | 100.0% |
| D08 Soil temperature and snow required profile | 100.0% |
| D09 Other required production physics | 40.0% |
| D10 Serialized MultiSWAP | 100.0% |
| D11 Parallel MultiSWAP | 79.375% |
| D12 Runtime composition | 100.0% |
| D13 Groundwater interface and coupling | 82.0% |
| D14 Performance / bounded-cost / fallback | 53.0% |
| D15 Permanent testbank | 83.928571428571% |
| D16 Scientific traceability / documentation | 51.666666666667% |
| D17 Status-A readiness | 9.090909090909% |
| D18 Governance / reproducibility / release evidence | 85.0% |

The formal 100% domains remain D01–D08 except D09, plus D10 and D12.

## Active hard gates

HG06 remains active because required production-critical v1 capability is still below the required qualification state. O02 macropore production coverage and PF02 bounded-cost/fallback qualification are sufficient to keep the 89% ceiling active.

HG07 remains active because the generic current-canonical integrated executable physics layer T03 has not been qualified by the F-TB11/F-TB12 preservation work.

HG08 remains active because formal Status-A readiness is not 22/22 and controlled WR-QA-2024 has not been reconciled.

## Updated execution wave

Four ownership-disjoint lanes can proceed in parallel, subject to serialized F-CI admission:

1. **Macropore/O02** — the next F-SI number observed free is F-SI39. F-SI36–F-SI38 now belong to other sensitivity/temporal work and must not be reused.
2. **Performance** — F-PE12 was observed free and should own PF02 plus M12/PF03 bounded-cost and production-scale isolation evidence, without changing physics.
3. **Groundwater/G05** — F-GC24 restart/replay is admitted by F-CI65. F-GC25, F-GC26 and F-GC27 were observed branch-free and remain suitable for the remaining MultiSWAP/diagnostics, external aquifer composition and final parent closure sequence. F-GC20, F-GC22 and the unresolved F-GC23 tangent dependency remain explicit prerequisites.
4. **Documentation/Status-A** — F-DOC20 was observed free and may advance DOC03/DOC04/A01 evidence without owning production semantics.

RossFast and Energy Balance remain isolated zero-weight tracks under SWAP5-v1. Their success or failure cannot silently change this denominator.

## Architecture invariants

All 30 SWAP Core Architecture Invariants were checked. F-RG05 is governance/evidence-only and introduces no adverse architecture delta. Mass conservation remains absolute, reference mode remains available, MultiSWAP and groundwater composition gaps remain explicit, and bounded-cost policy cannot change physics to meet performance targets.

## Authority boundary

F-RG05 changes no production or reference source and performs no F-CI admission or F-VQ qualification. Its decision becomes effective only if the dedicated exact-head workflow succeeds on the commit containing the complete F-RG05 package.

The next F-RG rebaseline is triggered after roughly 4–6 substantive **parent-gate** closeouts, immediately on an ownership/scope/denominator conflict, or after a major parent-level canonical architecture admission.
