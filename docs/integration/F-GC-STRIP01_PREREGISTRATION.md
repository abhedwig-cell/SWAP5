# F-GC-STRIP01 — 50 m cross-section SWAP–MODFLOW6 benchmark

Status: **research preregistration; not production-admitted and not canonical admission**

## Objective and frozen scope

Construct a reproducible half-drain-spacing cross-section: 50 MODFLOW6 cells at 1 m spacing, one horizontal aquifer layer, a left drain, a no-flow right symmetry boundary, and a no-flow aquifer base. The 50 m model domain represents half of an approximately 100 m drain spacing. SWAP supplies one homogeneous Reference Richards column per land cell in the eventual coupled phase.

The staged work is:

1. standalone MODFLOW6 steady recharge and analytical Dupuit comparison;
2. standalone transient drain-down without recharge or ET;
3. simple-forcing SWAP–MODFLOW6 coupling;
4. Hupsel forcing;
5. transaction, replay, restart and ownership qualification;
6. reproducible scripts, figures, machine-readable results and bounded closeout/advice.

No phase will claim that SWAP freatic GWL equals MODFLOW head throughout the profile. The primary coupled measures are interface flux/action-reaction, state and storage ownership, total water balance, lateral response, coupling-window timing, and accepted-state/replay semantics.

## Repository baseline and reconciled authorities

The pinned start is canonical `integration/f-ci-canonical` at `53059a5225fa45cd6121d4bc4c7310dcc4e0660c`. The exact branch was created from that commit as:

`work/f-gc-strip01-50m-swap-modflow-benchmark`

Current Status-A pages are a frozen denominator and refer to the post-Status-A canonical supplement. The controlling concrete SWAP5–MODFLOW6 application chain is F-GC49D and its successors, not the older SWAP4 report. Its relevant owners include the prepared MODFLOW6/XMI solve lifecycle, F-GC40 cell aggregation, F-GC41 whole-window acceptance/retry/publication ordering, F-GC49C service composition and F-GC49D production FMR context.

The admitted fixed-interface production contract at this head defines:
- interface state as hydraulic head at the fixed lower coupling plane, datum aligned to SWAP lower-face head;
- SWAP physical column storage as an owner;
- MODFLOW STO as `HEAD_STATE_CAPACITANCE`, not independently authorized physical regional storage;
- active drainage owner as `NONE` in the restricted production profile;
- committed-only SWAP/groundwater/ledger restart, with no prepared-handle or mid-Newton restart;
- MODFLOW timestep publication before SWAP commits and then ledger commits.

Therefore the independent regional water-balance and MODFLOW-drain parts of this research benchmark are **not inherited production claims**. Standalone MODFLOW phases may use physical convertible-aquifer storage and a drain package as a separately qualified groundwater-only model. The coupled phase must first state and evidence an application-domain, non-overlapping physical storage and drainage ownership model. If that cannot be reconciled without changing shared production authority, record a central prerequisite before any such shared change. Do not reinterpret `HEAD_STATE_CAPACITANCE` as physical storage, add a second drain owner, or count interface ledger exchange as storage.

## Historical source, not present authority

The Library report `Rapport_Koppeling_SWAP4_en_MODFLOW6_V04.docx` contains a 10-cell/10-column drain-down strip, including initially saturated columns draining to the left and no precipitation or evaporation, plus separate heterogeneous strips and regional cases. It also documents the historic predictor/corrector scheme and head/GWL differences where resistance separates the coupling plane from the freatic surface. These are useful fixture ideas and expected qualitative checks only. The report predates the current admitted SWAP5 ownership contracts and does not establish their semantics.

Repository fixtures F-GC44 through F-GC47 demonstrate live MODFLOW6 6.8.0 with real SWAP participants, prepared-solve ownership, cell bindings, accepted publication and 1:1, N:1 or mixed topology. Their C bridges remain qualification fixtures; they must not be promoted into production ABI or treated as this 50-cell scientific result. Existing tests build MODFLOW6 6.8.0 through FloPy's `get_modflow`, pin the Linux archive SHA-256 `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`, and bind the Fortran dependencies explicitly.

A repository Hupsel SWINTER0 fixture exists at `tests/f-app06/fixtures/hupsel_swinter0_b111_exact.part00.csv`; its exact completeness and compatibility with a full meteorological forcing sequence remain to be verified. Do not treat the fixture name as proof that a complete Hupsel simulation is ready.

## Standalone MODFLOW oracle and first parameterization

Use a 50 m wide by 1 m deep plan-view strip, `nlay=1, nrow=1, ncol=50`, `delr=1 m`, `delc=1 m`, model top 0 m and impermeable base -10 m. Recharge is initially uniform at 0.001 m/d. Set a left drain at stage -5 m relative to land datum, with positive conductance chosen high enough that the first-cell head excess is small relative to the resolved profile rise; record its actual value and verify it through a conductance sensitivity. The right edge and aquifer base are no-flow. Use a convertible layer with an explicitly declared `Sy`; this only represents physical storage in the standalone aquifer oracle.

For Kx = 0.1, 0.25, 0.5, 1.0 and 2.0 m/d, predict the midpoint saturated thickness (h_{mid}), measured above the -10 m base, from the idealized fixed-head/no-flow Dupuit relation:

`h_mid^2 - h_drain^2 = R L^2 / Kx`

with (L=50) m and ideal (h_{drain}=5) m. The corresponding ideal midpoint rise above the drain stage is approximately 1.80, 0.95, 0.48, 0.24 and 0.12 m. This predicts that Kx=0.5 m/d is a useful initial visible-profile case; it does not predetermine the MODFLOW result. Compare the actual DRN cell-centered finite-volume solution against an oracle that accounts for the drain-cell location and finite conductance, in addition to the continuum Dupuit estimate. Record total recharge (0.05 m3/d), total drain outflow, storage/budget residual and K sensitivity. Reject an oracle comparison that silently assumes a fixed-head boundary when the DRN boundary is materially head-dependent.

The drain-down phase starts from a flat elevated water table near -3 m (7 m saturated thickness above the base), zero recharge and no ET. Track heads at selected columns, the right-edge no-flow flux, MODFLOW-reported storage change and cumulative drain flow. The water balance must close using the selected MODFLOW budget definitions before adding SWAP.

## Coupled qualification contract

Before implementing the full coupled run, freeze the units, signs, geometry and mass equation from the exact current source and adapter contracts. In particular, distinguish:
- native SWAP bottom flux (positive into SWAP);
- public SWAP outward exchange;
- MODFLOW API source (positive into groundwater);
- SWAP soil-column storage;
- any separately authorized physical aquifer storage;
- interface ledger (transfer accounting only).

The interface flux pair must cancel as action/reaction and must be counted once. The eventual domain balance is derived from the chosen application boundary and ownership model, not assumed from a generic formula. SWAP columns must provide vertical exchange at their own locations; MODFLOW must provide lateral intercell flow and the uniquely owned left drain.

Use one homogeneous, numerically easy sand row selected from qualified repository soil data. Confirm the exact hydraulic profile and SWAP bottom/interface elevation before locking it. Use identical soil and forcing per column initially. The first coupled forcing should isolate a prescribed uniform exchange/recharge pulse and no ET/runoff; only then add a real simple SWAP forcing and proceed to the available Hupsel series. Do not emulate lateral drainage inside any SWAP column.

For each coupled window record all 50 SWAP interface exchanges, MODFLOW API terms and cell heads, lateral face flows, drain rate/amount, each separately owned physical storage change, SWAP storage/ET/runoff, accepted window endpoints, retry/replay identity and whole-domain residual. Also retain SWAP freatic GWL as a diagnostic that may differ physically from MODFLOW head.

Use absolute residual limits fixed before qualification from solver precision, time-step, cell volume and expected budget rounding. Report both absolute and normalized residuals. Never widen limits solely to turn a failure green.

## Frozen hypotheses and falsification

- A uniform recharge profile yields a smooth, symmetric-upward (toward the right symmetry boundary) Dupuit-like water-table mound; the midpoint-rise magnitude follows the K range qualitatively.
- With no inflow or ET, groundwater storage decreases monotonically until the drain stage is approached and cumulative drain flow matches storage loss.
- In the coupled pulse test, exchange farthest from the drain traverses SWAP vertically and MODFLOW laterally before leaving through the left drain; a stand-alone SWAP column does not represent that lateral pathway.
- A nonzero MODFLOW-head/SWAP-GWL difference can be physically valid when the soil profile contains hydraulic resistance between the coupling plane and freatic surface.

Any failed hypothesis is retained with raw output and classified as model setup, numerical discretization, MODFLOW package, SWAP process, coupling orchestration or unresolved physics/ownership.

## Deliverables and gates

The branch will hold a source-backed preregistration and status record first, then exact input/configuration, runnable small scripts, Dupuit/finite-volume oracle, raw machine-readable results, plots, qualification document and a closeout/advice record. Reproducibility includes pinned SWAP/MODFLOW/FloPy versions, source/input hashes, parameter files, solver settings, commands, seeds where relevant and output hashes.

Canonical admission is explicitly out of scope. Completion may result in: (a) reproducible research benchmark with bounded coupled qualification; (b) a falsified or blocked coupled balance with standalone A/B results preserved; or (c) an explicitly registered shared-authority prerequisite. No paper claim follows automatically.
