# SWAP 4.3.1/B1.11 hydraulic and hysteresis reconstruction

Status: workstream authority for `work/swap431-hyd-hyst-closeout` until canonical admission.

Baseline pinned at start: `integration/f-ci-canonical@71fecec02aabe020e9950dc6d08f9dbb35fc2413`.

This record reconstructs the semantic families behind the legacy hydraulic selectors. It does not treat one selector as one production component.

## Source authority

B1.11 is the corrected SWAP 4.3.1 reference snapshot with source-manifest SHA-256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

Relevant B0 members and identities:

- `SWAP/hysteresis.f90`: `720094abf49eb95b032c96c6c7feeda632b9fdd5f40b397a20e5fbd27d9f39db`
- `SWAP/MOD_MvG_functions.f90`: B0 `a27252d...`, B1.11 corrected `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`
- `SWAP/MOD_RIA.f90`: B0 `a8695bbc...`, B1.11 corrected `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`
- `SWAP/sptabulated.f90`: `bd7c58107c866580b0a30fd4ff2fa9aa022ab9aa970e87ce6886ba99e44a94b9`
- `SWAP/WC_K_models_04_11.f90`: B0 `1f956cae...`, B1.11 corrected `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`

The ordered B1.11 corrections include SWAP-009, SWAP-010 and SWAP-011. In particular MODEL7 capacity must use the SWAP-010 corrected weighted common denominator; the old formula is not an admissible oracle.

## Constitutive family decomposition

| Census capability | Semantic disposition |
| --- | --- |
| MODEL2 | Exponential test relation. Separate simple constitutive subfamily. Implemented as an override at the common provider seam. |
| MODEL3 | Basic bimodal MvG without entry-pressure continuation. Implemented in the same selector-aware classical wrapper as MODEL2. |
| MODEL5 | Truncated/scaled unimodal MvG. Implemented in the extended K0 family. |
| MODEL6 | Basic bimodal MvG. Implemented in the extended K0 family. |
| MODEL7 | Truncated/scaled bimodal MvG. Implemented with the corrected B1.11/SWAP-010 capacity expression. |
| MODEL8 | PDI unimodal. No-vapor value path implemented; vapor remains a separate capability. |
| MODEL9 | Truncated PDI unimodal. No-vapor value path implemented; vapor remains separate. |
| MODEL10 | PDI bimodal. No-vapor value path implemented; vapor remains separate. |
| MODEL11 | Truncated PDI bimodal. No-vapor value path implemented; vapor remains separate. |
| MODEL12 | RIA/de Rooij constitutive family. Still open. This is a genuinely different relation, not a parameterization of MvG/PDI. |
| POWER | Orthogonal dry-end conductivity power tail in the default-MvG branch. Implemented as a conductivity-only wrapper. |
| VAPOR | Orthogonal PDI vapor-conductivity contribution for MODEL8-11. Still open and deliberately excluded from the implemented K0 family. |
| RIA-VAPOR | Vapor contribution inside MODEL12/RIA. Still open with MODEL12. |
| TABLE | Historical `SWSOPHY=1` TSPACK value/derivative representation. Still open as generic external-table compatibility. |
| LINEAR-TABLE | Historical `SWSOPHY=-1` precomputed intercept/slope representation (`fl_use_tables`). Still open and distinct from TSPACK. |

MODEL4 is not part of this open census slice; it is the ordinary untruncated MvG relation already represented by the admitted analytical owner.

## Ownership of implemented stateless families

The production chain is compositional:

`default MvG -> MODEL2/3 override -> MODEL5-11 override -> optional POWER -> optional frost conductivity wrapper`.

The underlying immutable `cofgen` authority remains parameter-owned. The new wrappers own no committed physical state and do not own retry, acceptance, rollback or mass accounting. They only answer constitutive queries.

POWER applies only to default-MvG nodes, matching the B1.11 dispatch order. It is not silently applied to MODEL2/3 or MODEL5-12. The first admission is K0/`SWKIMPL=0`; derivative/`SWKIMPL=1` remains separate.

The MODEL8-11 implementation is explicitly no-vapor. This avoids silently swallowing the separate temperature-dependent vapor contract and the known PDI vapor-temperature defect investigated by F-PDI-VT.

## TABLE is not F-TAB02

The old `SWSOPHY=1` route accepts externally supplied table values and evaluates them through TSPACK. That is not the same capability as F-TAB02.

F-TAB02 is an internally generated, immutable, default-MvG-equivalent K0 representation with bounded production qualification. Its records explicitly exclude generic user tables and legacy `SWSOPHY=1`. Therefore F-TAB02 evidence may inform interpolation architecture, but it cannot close SW431-HYD-TABLE.

The legacy `SWSOPHY=-1` route is different again. It reads precomputed intercept/slope arrays and dispatches direct linear segments with the legacy head-bin indexing. It should become a small immutable typed linear-table owner if migrated; it must not be conflated with TSPACK or generated K0 tables.

## HYST1/HYST2 state decomposition

`SWHYST=1` and `SWHYST=2` are one stateful hysteresis family with different initial branch:

- HYST1 starts on the main wetting curve, branch index `+1`;
- HYST2 starts on the main drying curve, branch index `-1`.

Legacy reversal logic is historical-state dependent. For each node it compares previous accepted head `hm1` with the new head `h`. A reversal is eligible when

`(hm1-h)/branch_index > tau`

and the new head lies strictly between `-1000 cm` and `-10 cm`.

On reversal the branch index changes sign and the active scanning-curve parameters are reconstructed. Wetting reversals use the wetting alpha and solve a scanning residual water content; drying reversals use the drying alpha and solve a scanning saturated water content. Bounds corrections can trigger an inverse pressure-head reconstruction, after which capacity is recomputed.

Therefore hysteresis cannot be migrated as a stateless selector or parameter choice.

The target owner must persist, per active hysteretic node, at least:

- current wetting/drying branch index;
- current scanning-curve residual/saturated water-content state or an equivalent lossless parameterization;
- the accepted head/theta state needed to decide reversal at the next accepted endpoint.

The update belongs at accepted-step transition, not during an uncommitted Newton trial. Rejected trials must not advance branch/scanning state. Restart must serialize the same hysteretic continuation state, and replay from restart must reproduce branch decisions.

## Current claim ceiling

Implemented on this work branch, pending persisted integrated qualification:

- MODEL2;
- MODEL3;
- MODEL5;
- MODEL6;
- MODEL7;
- MODEL8 no-vapor;
- MODEL9 no-vapor;
- MODEL10 no-vapor;
- MODEL11 no-vapor;
- POWER on default-MvG K0.

Still open:

- MODEL12/RIA;
- PDI VAPOR;
- RIA VAPOR;
- generic TSPACK TABLE;
- LINEAR-TABLE;
- HYST1/HYST2 stateful owner.

No claim is made for `SWKIMPL=1`, generic external tables, vapor-temperature semantics, RIA, or hysteretic restart until their own evidence exists.
