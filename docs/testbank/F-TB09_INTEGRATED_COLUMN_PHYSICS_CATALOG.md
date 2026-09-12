# F-TB09 integrated column physics, process interaction and conservation catalog

## Decision boundary

F-TB09 establishes the permanent catalog contract for integrated single-column physics qualification. It does not claim that all catalogued combinations already execute end-to-end or have passed scientific qualification.

The frozen composition base is `integration/f-ci-canonical@42544af575db522d012db491db801615577048df` (tree `4360cd08fd0e952978df9e2742bcc34fdede9ef1`). During closeout the moving canonical advanced to `ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868` through F-CI49P. That change is governance/preservation-only: no production source, reference, scientific tolerance or solver functionality changed, and hard mass conservation remained unchanged. F-TB09 therefore keeps its frozen base rather than chasing a non-scientific postimage commit.

The exit decision is:

`QUALIFIED_INTEGRATED_COLUMN_PHYSICS_TESTBANK_CATALOG_ESTABLISHED`

It is valid only with exact-head CI green at both workflow start and end.

## Live predecessor authority recheck

F-TB01 through F-TB08 are pinned by exact branch-head commit and successful exact-head run in `integration/f-tb/F-TB09_AUTHORITY_RECHECK.json`.

The initial TB09 materialization contained stale/non-resolvable run identifiers for F-TB04 through F-TB07. Those identifiers are explicitly superseded by the final live recheck. The predecessor commit authorities themselves did not change.

## Existing permanent integrated cases

The anti-duplication inventory is case-ID based, not just owner-name based. Important already-permanent cases include:

- `SWAP5-TB-DIVDRA-RUNTIME-0001-v1`, integrated active DIVDRA runtime, F-TB01;
- `SWAP5-TB-SURFEVAP-RUNTIME-0001-v1`, integrated restricted surface evaporation, F-TB01;
- `SWAP5-TB-ROOTUPTAKE-PARALLEL-0001-v1`, restricted root uptake, F-TB01;
- `SWAP5-TB-EFFECTIVE-FORCING-0001-v1`, effective forcing, F-TB01;
- RB1 root and surface-evaporation release cases from F-TB03;
- generic restart and restart-mass cases from F-TB04;
- restricted thermal atomic/restart cases from F-TB06.

TB09 does not reissue any of these. It owns only the missing cross-process seam: shared accounting, transition behaviour, lower/upper-boundary interaction, crop/root interaction and restart during active physics.

## Coverage and risk selection

The requested dimensions are infiltration, surface storage, runoff, soil evaporation, transpiration/root uptake, drainage, crop/WOFOST, admitted soil temperature, bottom boundary, variable forcing and wetting/drying transitions.

The catalog deliberately avoids the full combinatorial product. Eight bounded cases cover the highest-risk pairwise seams:

| Case | Main interaction |
| --- | --- |
| 001 | rainfall → infiltration → ponding/storage → runoff |
| 002 | ET partition → soil evaporation + root uptake |
| 003 | drainage + changing bottom boundary |
| 004 | crop development + root uptake |
| 005 | wetting → drying reversal |
| 006 | restricted soil temperature + variable forcing |
| 007 | restart during ponding/runoff interaction |
| 008 | Full-Richards high-risk integrated reference case |

Case metadata in `testbank/manifests/F-TB09_INTEGRATED_COLUMN_PHYSICS_CASES.json` contains stable ID, physics scope, oracle, water equation, tolerance provenance, execution profiles, expected diagnostics, theory/equation references and architecture invariant IDs.

All cases remain `CATALOGED_NOT_PHYSICS_QUALIFIED` until an owner workunit pins an executable case and evidence.

## Hard conservation and sign convention

Every water-bearing case has a hard water-balance oracle. The authoritative identity is:

`delta_storage = sum(signed_external_amounts)`

with positive signed amount entering the SWAP accounting domain and negative signed amount leaving it. The independently recomputed residual is:

`residual = delta_storage - sum(signed_external_amounts)`.

Internal transfers between SWAP-owned stores, including surface-to-soil infiltration, cancel from the external ledger.

For initial expanded case equations, a bare `Q_bottom` that is subtracted denotes the non-negative **outward** bottom-flux amount listed as an output. Upward bottom flow belongs only to inputs. Production evidence must use one canonical signed bottom amount and may never book both representations.

Mass conservation is not a numerical-policy tradeoff. Head, physics, fallback and performance tolerances may not absorb missing water.

## Oracle policy

F-TB09 inherits the F-TB01 hierarchy unchanged: O1 exact, O2 manufactured, O3 independent numerical, O4 qualified Full Richards, O5 source-bound SWAP4.3.1, O6 property/invariant, O7 cross-solver consistency.

No O5 legacy case is introduced and no corrected golden baseline is constructed.

## Profiles

FAST carries three cheap high-risk specifications, CANONICAL six, RELEASE seven and DEEP five. Membership overlaps intentionally. Profile selection changes test cost and cadence, not physics or the mass gate.

## Defect routing

A source defect exposed while implementing or executing a TB09 case is evidence for a separate owner workunit. F-TB09 may not repair production source, widen tolerances, redefine process ownership or replace the reference.
