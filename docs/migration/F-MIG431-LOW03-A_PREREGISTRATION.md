# F-MIG431-LOW03-A: ordinary implicit deep-aquifer Cauchy application

Status: central preregistration and sole branch issuance; not implementation, qualification or admission.
Baseline: `82351099a8c5c77ce111f8ace6648b8b5ffa7167`, after LOW03-P0 admission via PR#975.
Official branch: `work/f-mig431-low03-a-implicit-cauchy-application`.
Owner: central F-MIG431 lower-boundary regie.

## Bounded feasible seam

Initial slice is ordinary non-groundwater-owned SWBOTB3 with SwBotb3Impl=1, Reference SWKIMPL0, homogeneous bare/nonmacropore profile, SHAPE_3=1. Reuse admitted typed bottom_mode3 physics and existing proposal/trial/commit/restart owners. Supply immutable trial external total head, RIMLAY, half-cell flag and independent extra native qbot. This is an application law/binding, not a new solver/aquifer component or MODFLOW datum/storage owner. No public C ABI or persistent restart-state expansion is authorized.

Explicit3 (SwBotb3Impl=0) is deliberately not included: it needs committed groundwater level, SHAPE_3/HDrain and saturated-profile resistance. Current smooth projection is restricted to prescribed-qbot/in-profile water table and cannot be silently generalized or replaced by a fixed groundwater value. That variant remains open for a separate source-bound reconcile after this bounded slice; it is not declared migrated/obsolete/falsified. This branch is not a sibling repair/admission branch.

## Exact B1.11 source and laws

Authority: lossless corrected SWAP4.3.1 B1.11 carrier `integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json`. Readswap SHA256 e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c; BoundBottom5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e; HeadCalcdb667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5; functionsb32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527. Existing source is recovered; no re-upload.

Readswap:899-946: SwBotb3Impl0/1; SHAPE_3[0,1], HDrain[-10000,0]cm, RIMLAY[0,100000]days, SwBotb3ResVert0/1. SW3=1 supplies AQAVE[-10000,1000]cm, AQAMP[0,1000]cm, AQTMAX[0,366]days and AQPER[0,366]days; SW3=2 supplies DATE3/HAQUIF with heads[-10000,1000]cm. Optional SW4=1 supplies DATE4/QBOT4[-100,100]cm/day. Typed adapter uses resolved serial-day dates, not raw SWP/BBC parsing. Implicit SHAPE_3!=1 is warned against by legacy and stays outside this initial bounded slice.

BoundBottom:75-82: sine Haq=AQAVE+AQAMP*cos(2*pi/AQPER*(t-AQTMAX)), where t is current elapsed calendar-year time, NOT t1900+dt. Table Haq=AFGEN(DATE3/HAQUIF,t1900+original_proposed_dt). Swap:430-457 calls BoundBottom once BEFORE the retry loop. Therefore aquifer head is frozen for that original proposal, through retries/sibling trial staging, with calendar-origin/restart metadata matching the existing immutable proposal carrier discipline. Units are cm total head in soil-profile z coordinates, not HBOT5 pressure at the lower face and not external MODFLOW datum.

HeadCalc:580-588 evaluates q=(Haq-(hN+zN))/(d/Kb+RIMLAY), or denominator RIMLAY only when ResVert=1. Crucial separate timing: optional extra Q4=AFGEN(DATE4/QBOT4,t1900+CURRENT_trial_dt) is evaluated inside HeadCalc, so a reduced retry changes its sample even while Haq is frozen. Bind Q4 per actual trial endpoint (advance t1), not the original proposal endpoint; it is immutable during that solve/backtracking. Both temporal authorities must be separately observable and qualified. For linear examples, head sampled at proposed0.5day remains unchanged when trial shortens to0.125day, but an extra flux rising0 to0.02cm/day over one day samples0.0025, not0.01cm/day.

AFGEN functions:86-105: endpoint extension is constant, interior interpolation uses legacy arithmetic grouping and exact knot behavior. Strict finite increasing typed dates and finite matching value arrays are required; duplicates/sentinel ambiguity fail closed rather than emulate undefined division. DATE3 and DATE4 may have independent knots/endpoints. Preserve source table arithmetic and sine phase/calendar reset without performance claims.

## Domain and ownership contract

AQPER=0 is parser-accepted but singular in the law: fail closed, no regularization. RIMLAY=0 is valid only when half-cell participates with positive finite K/d; no-half-cell requires R>0. Preserve typed P0 external head[-10000,1000] and extra flux[-100,100], resistance bounds; valid sine parameters whose evaluated head leaves the bounded domain are rejected, not clipped. Nonfinite calendar/head/flux, invalid geometry/provider, unresolved proposal history, unsupported solver/profile/mixed/GW ownership fail closed before candidate authority.

Do not route ordinary3 through groundwater-owned fixed-interface5 or claim its implicit conductance from a fixed HBOT5 transformation. Extra Q4 is part of the single physical candidate qbot; do not account it a second time. Existing runtime alone commits accepted qbot*accepted duration and integrated equation balance. Resistance and forcing configuration are immutable application authority, not hydraulic persistent state. Retry/replay may rebuild scratch but never mutate committed soil/groundwater/ledger state. Restart preserves committed state and reattaches the same immutable configuration and original proposal metadata through the admitted mechanism; no new restart format.

## Mandatory application gates

Persist concrete application config/binding design and tested postimage before production implementation/build. Frozen-source DATE3/HAQUIF, sine/calendar and DATE4/QBOT4 oracles; exact endpoint/knot extension, independent-table grids and changed trial endpoint with fixed proposal head. Exercise coarse/fine siblings, forced reject/replay, original-proposal retries and same-call accepted private progress. Prove external head is frozen while Q4 tracks actual trial time. Source-independent compartment/whole unrounded mass and exactly-once accepted physical qbot amount; no storage-closure qbot overwrite. Full opaque kernel accept/commit/rollback and committed production restart with fresh backend/changed forcing must pass. A/B/A isolation, O0/O2 and independent fixed-head/physical bottom-law limits. Preserve admitted2/internal-2,4,ordinary5/GW5,6,7, P0 typed3 and DEP01 shared RossFast bindings through actual dependency evidence. Actions only for necessary persisted final qualification/admission; local work first.

Allowed surface: new application provider/config and binding; existing serialized backend/production bootstrap/ordinary profile admission only where explicitly reconciled. Solver residual/Jacobian/common typed boundary stay admitted and unchanged. If ABI/datum/GW ownership/transaction/proposal/restart shared authority must change, register the central prerequisite FIRST; do not implement silently. No new branch beyond the sole issued unit without central evidence.

## Recovery and claim ceiling

Read `integration/audits/F-MIG431-LOW03-A_STATUS.json` first. No LOW03-A production source has yet changed. The safe next phase is source-law oracle and concrete application binding design. Mode1 parked; explicit3/implicit3 application and8 remain open until their exact bounded admissions. Internal-2 and9 remain internal/special routes, not ordinary application migration claims.
