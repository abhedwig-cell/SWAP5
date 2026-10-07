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
| MODEL8 | PDI unimodal. Value path plus the shared SWAP-009-corrected vapor owner implemented. |
| MODEL9 | Truncated PDI unimodal. Value path plus the same shared vapor owner implemented. |
| MODEL10 | PDI bimodal. Value path plus the same shared vapor owner implemented. |
| MODEL11 | Truncated PDI bimodal. Value path plus the same shared vapor owner implemented. |
| MODEL12 | RIA/de Rooij constitutive family. Still open. This is a genuinely different relation, not a parameterization of MvG/PDI. |
| POWER | Orthogonal dry-end conductivity power tail in the default-MvG branch. Implemented as a conductivity-only wrapper. |
| VAPOR | Orthogonal PDI vapor-conductivity contribution for MODEL8-11. Implemented once as a shared SWAP-009-corrected K0 owner, with trial-start soil temperature supplied by the existing thermal-state owner. |
| RIA-VAPOR | Vapor contribution inside MODEL12/RIA. Still open with MODEL12. |
| TABLE | Historical `SWSOPHY=1` TSPACK value/derivative representation. Still open as generic external-table compatibility. |
| LINEAR-TABLE | Historical `SWSOPHY=-1` precomputed intercept/slope representation (`fl_use_tables`). Implemented as its own immutable typed owner and kept distinct from TSPACK. |

MODEL4 is not part of this open census slice; it is the ordinary untruncated MvG relation already represented by the admitted analytical owner.

## Ownership of implemented stateless families

The production chain is compositional:

`default MvG -> MODEL2/3 override -> MODEL5-11 override -> optional POWER -> optional frost conductivity wrapper`.

The underlying immutable `cofgen` authority remains parameter-owned. The new wrappers own no committed physical state and do not own retry, acceptance, rollback or mass accounting. They only answer constitutive queries.

POWER applies only to default-MvG nodes, matching the B1.11 dispatch order. It is not silently applied to MODEL2/3 or MODEL5-12. The first admission is K0/`SWKIMPL=0`; derivative/`SWKIMPL=1` remains separate.

The MODEL8-11 family now has a single optional PDI-vapor layer. Its formula is source-bound to admitted SWAP-009, including the corrected signed pressure head in the Kelvin relative-humidity term. The provider receives an immutable temperature frame copied from the current trial-start soil-temperature state. It does not own or advance temperature. The first production scope remains K0/`SWKIMPL=0` and excludes frost, macropore, snow and drainage-response composition.

## TABLE is not F-TAB02

The old `SWSOPHY=1` route accepts externally supplied table values and evaluates them through TSPACK. That is not the same capability as F-TAB02.

F-TAB02 is an internally generated, immutable, default-MvG-equivalent K0 representation with bounded production qualification. Its records explicitly exclude generic user tables and legacy `SWSOPHY=1`. Therefore F-TAB02 evidence may inform interpolation architecture, but it cannot close SW431-HYD-TABLE.

The legacy `SWSOPHY=-1` route is different again. It reads precomputed intercept/slope arrays and dispatches direct linear segments with the legacy head-bin indexing. That route is now implemented as a small immutable typed linear-table owner; it is not conflated with TSPACK or generated K0 tables.

## HYST1/HYST2 state decomposition

`SWHYST=1` and `SWHYST=2` are one stateful hysteresis family with different initial branch:

- HYST1 starts on the main wetting curve, branch index `+1`;
- HYST2 starts on the main drying curve, branch index `-1`.

Legacy reversal logic is historical-state dependent. For each node it compares previous accepted head `hm1` with the new head `h`. A reversal is eligible when

`(hm1-h)/branch_index > tau`

and the new head lies strictly between `-1000 cm` and `-10 cm`.

On reversal the branch index changes sign and the active scanning-curve parameters are reconstructed. Wetting reversals use the wetting alpha and solve a scanning residual water content; drying reversals use the drying alpha and solve a scanning saturated water content. Bounds corrections can trigger an inverse pressure-head reconstruction, after which capacity is recomputed.

Therefore hysteresis cannot be migrated as a stateless selector or parameter choice.

The implemented target owner persists, per active hysteretic node:

- current wetting/drying branch index;
- current scanning-curve residual/saturated water-content state or an equivalent lossless parameterization;
- the accepted head/theta state needed to decide reversal at the next accepted endpoint.

The update belongs at accepted-step transition, not during an uncommitted Newton trial. Rejected trials must not advance branch/scanning state. Restart must serialize the same hysteretic continuation state, and replay from restart must reproduce branch decisions.

## Current claim ceiling

Implemented on this work branch, pending persisted integrated qualification of the current code postimage:

- MODEL2;
- MODEL3;
- MODEL5;
- MODEL6;
- MODEL7;
- MODEL8, including the shared PDI-vapor option;
- MODEL9, including the shared PDI-vapor option;
- MODEL10, including the shared PDI-vapor option;
- MODEL11, including the shared PDI-vapor option;
- POWER on default-MvG K0;
- LINEAR-TABLE (`SWSOPHY=-1`);
- HYST1 and HYST2 through one stateful accepted-step owner, explicit optional-state layout and restart roundtrip.

The HYST production gate additionally contains a post-solver rejection/rollback test for both initial modes. That test is part of the current queued integrated qualification and must pass before admission.

Still open as distinct capability families:

- MODEL12/RIA;
- RIA VAPOR;
- generic TSPACK TABLE (`SWSOPHY=1`).

No claim is made for `SWKIMPL=1`, generic external tables or RIA. PDI vapor is bounded to the SWAP-009-corrected models 8-11 K0 route with the existing soil-temperature state as temperature authority.

## Source-recovery boundary for remaining families

The public historical `sptabulated.f90` lineage is not byte-identical to the B0 member pinned by this project: B0 is 198627 bytes with SHA-256 `bd7c58107c866580b0a30fd4ff2fa9aa022ab9aa970e87ce6886ba99e44a94b9`, while the inspected public historical blob materializes as 198714 bytes and hashes to `cf79c406d67b8ced8bb55bb5de2d3893fc58f24bb30266366969374a9cb15862`. It therefore cannot be promoted to the exact B1.11 TABLE oracle.

MODEL12 remains similarly fail-closed until the exact corrected `MOD_RIA.f90` body associated with B1.11 target SHA-256 `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a` is materialized. The RIA literature or a separately maintained fitter is scientific background, not a substitute source oracle.

SWAP-009 is admitted reference authority and is included in B1.11. It corrects the PDI vapor call from `Kvap_func(WC,abs(h),Temp)` to `Kvap_func(WC,h,Temp)`. The branch implementation uses that corrected signed-head Kelvin term through one shared models 8-11 owner. Local GNU Fortran 14.2 execution is O0/O2 byte-identical; persisted integrated production qualification remains pending.
