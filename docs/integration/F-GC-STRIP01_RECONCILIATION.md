# F-GC-STRIP01 reconciliation — coupled inputs and ownership

Status: research reconciliation; the selected-reference standalone MODFLOW A/B is qualified with a retained low-K sweep negative. No canonical admission is asserted.

## Baseline and current route

The experiment was preregistered from canonical `integration/f-ci-canonical` at `53059a5225fa45cd6121d4bc4c7310dcc4e0660c`. The current fixed-interface SWAP5–MODFLOW6 application route is F-GC49D and its accepted successors, backed by:

- `integration/f-gc/F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json`
- `docs/integration/SWAP5_MODFLOW6_FIXED_INTERFACE_CLOSEOUT.md`
- `docs/integration/SWAP5_MODFLOW6_FIXED_INTERFACE_DRAINAGE_OWNERSHIP.md`
- F-GC40 cell response aggregation and F-GC41 whole-window acceptance/retry/publication contracts.

These supersede historical SWAP4 coupling timing for current implementation claims. F-GC44–47 fixtures provide real-SWAP/MODFLOW qualification topologies, but their C bridges are not the production ABI.

## State, flux and storage

The accepted exchanged state is hydraulic head at the fixed lower coupling plane, mapped datum-aligned to SWAP lower-face hydraulic head. It is not defined as SWAP phreatic GWL; their difference may reflect unsaturated/intervening hydraulic resistance.

Native SWAP bottom flux is positive into SWAP; public SWAP outward exchange is its sign-reversed, unit-converted value. MODFLOW API source is positive into groundwater, so accepted action/reaction exchange cancels once across the interface.

SWAP owns physical soil-column storage. MODFLOW STO is admitted as `HEAD_STATE_CAPACITANCE`; it does not authorize independent physical regional storage or a combined SWAP+STO physical water balance. The interface ledger records transfer, not extra storage.

The current restricted production groundwater profile admits no active drainage owner (`NONE`). The standalone A/B instead assigns the DRN package to the standalone aquifer model and qualifies its separate physical storage. That evidence cannot be carried into a production-shaped coupled total balance by relabeling STO or counting the interface exchange as storage. A coupled experiment with aquifer storage and a left drain requires an explicit non-overlapping application-domain owner for each, plus evidence for its whole-window mass equation. Any shared transaction, datum, ABI or groundwater-ownership change must first be separately preregistered as central authority work.

Committed-only restart is the current boundary; prepared handles and mid-Newton scratch do not persist. Publication order remains MODFLOW timestep finalize once, SWAP commit once, then interface ledger commit once. Rejected trials own no accepted state or mass.

## Historical fixture and input availability

The Library report `Rapport_Koppeling_SWAP4_en_MODFLOW6_V04.docx` includes a 10-column initially saturated drain-down strip with no precipitation or evaporation, and broader strip/drain and regional experiments. It is a historical test-design source. Its old predictor/corrector semantics do not override the current F-GC contracts.

The canonical repository contains `tests/f-app06/fixtures/hupsel_swinter0_b111_exact.part00.csv` (573,880 bytes). This is a partial SWINTER0 exactness fixture, not the complete Hupsel meteorological forcing sequence. The restored-source authority `integration/f-app/F-APP03_HUPSEL_AUTHORITY_RESTORED.json` identifies historical member `283.met`, but the forcing payload is not present in this repository tree or in the searched Library project material. Hupsel dynamical runs cannot be reconstructed from the fragment alone. Subsequent source recovery followed the repository's F-APP03 lineage workflow to immutable public source `SWAP-model/swap-testcases` commit `a1b15843e9e9732713bed1ee41d09c16c3136593`. Its complete 1,096-day 2002–2004 `283.met` input is now persisted under `integration/f-gc/strip01/inputs/`. Git blob identity is reproduced exactly, and coverage/finite-value checks pass. Its raw SHA differs from the original B0 archive member, so it is an explicitly qualified public-input candidate, not a claim of exact B0 weather-file identity. Current SWAP5 typed forcing binding still requires qualification.

The repository's B01 BOFEK material is a hydraulic archetype for screening, not a complete, qualified BOFEK profile ID and layer mapping. The F-PE-BOFEK01 closeout explicitly says the complete profile catalogue/mapping is absent. It therefore cannot be presented as the requested qualified Dutch sandy soil profile without additional source evidence. The SWAP5 Reference soil route and exact source can execute a supplied profile, but solver availability alone does not qualify invented profile inputs scientifically.

## Consequences for phase ordering

- The K=0.5 m/d standalone A/B reference has passed its original head, rate and volume gates. The K=0.1,50-cell arithmetic-oracle head gate remains failed; native mesh refinement and an upstream-thickness diagnostic explain it. See the standalone qualification document.
- A coupled flux-only or prescribed-exchange diagnostic may still be explored as a research fixture, but it cannot be reported as the requested physical drain/storage balance until both physical owners and the complete water inputs are explicit.
- Phase C needs a source-backed simple sand profile and a frozen SWAP forcing/profile plus the exact research-domain storage/drain ownership declaration.
- Phase D now has a complete immutable public Hupsel input candidate; it still requires a qualified current typed forcing binding and must not be called the original B0 raw payload.
- No result of this unit grants production admission or supports the blanket equality `GWL_SWAP = H_MODFLOW`.

These are bounded evidence gaps, not a falsification of MODFLOW lateral-flow physics. Preserve them as research prerequisites instead of changing shared coupling semantics implicitly.
