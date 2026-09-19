# PPA-LOW02-TIME canonical closeout

Date: 2026-09-19

Status: `CANONICAL_ADMITTED_CLOSED`

## Scope closed

PPA-LOW02-TIME closes the typed application semantics that PPA-WU02-A
deliberately left open for legacy SWBOTB=2:

- SW2=1: the B1.11 sinus law
  `qbot = SINAVE + SINAMP*cos((2*pi/365)*(t-SINMAX))`;
- SW2=2: the B1.11 DATE2/QBOT2-equivalent AFGEN law with linear interpolation
  and endpoint clamping;
- the exact strict oven-dry guard `h_bottom < -1.0e7 cm`;
- internal effective selector `-2` using the already admitted free-drainage
  equation `qbot=-K_bottom`;
- re-entry to mode 2 when the next trial-start bottom pressure head is no
  longer below the dry threshold.

The capability is admitted only for the homogeneous typed mode-2 application
surface and the serialized Reference backend. It adds no new residual,
Jacobian, constitutive, timestep, retry, mass or commit owner.

## Authority

The normative corrected-reference authority remains SWAP 4.3.1 B1.11:

- member manifest SHA-256:
  `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`;
- `SWAP/boundbottom.f90` SHA-256:
  `5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`;
- `SWAP/readswap.f90` SHA-256:
  `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`;
- `SWAP/headcalc.f90` SHA-256:
  `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

The lower-level prescribed-qbot and free-drainage science remains inherited
from F-SI38/F-MR44R/F-VQ75/F-CI62/F-CI62P and F-SI13. PPA-LOW02-TIME changes
application reachability and timing/state binding, not lower-boundary physics.

## Production binding

The final production delta is one file:

`src/runtime/mod_fmr_serialized_reference_backend.f90`

Admitted blob SHA:

`80c7ca618ea228e31ac43ae493f16dd6eccc5991`

The control is carried by typed forcing and copied into interval-local backend
configuration. During each physical advance the runtime:

1. reads the current trial-start bottom pressure head;
2. derives effective mode 2 or internal -2 without mutating the configured
   selector;
3. evaluates the sine law at legacy calendar-relative substep-start time, or
   the table law at legacy t1900 substep-end time;
4. passes the derived mode/flux into the existing admitted Richards request;
5. leaves candidate/commit/rollback and mass accounting to the existing
   F-KT/F-MR transaction owner.

The initially separate application-control module was removed after broad CI
showed that established backend source lists compile the serialized backend
directly. Co-locating the immutable control with its forcing carrier preserved
the semantics while avoiding a new historical build-order dependency.

## Qualification

Live-canonical base:

`e473afc2d378a2567a59cc0db1577b4c724feeb2`

Qualified head:

`8d238bb46c9d4d77e38802e75458d99f59794d11`

PPA-LOW02-TIME workflow run `35426047814`:

- owner job `105852054740`: PASS;
- independent job `105852181968`: PASS.

The owner gate proves exact source-law oracles, calendar reset, AFGEN
interpolation/clamping, strict dry threshold, stateless re-entry, production
identity for sine and table controls, identity of the dry route with admitted
free drainage, hard mass closure, fail-closed non-mode2 attachment and O0/O2
output identity.

Independent qualification locks the B1.11 identities and independently checks
the sine and table laws, dry/re-entry behavior, A-B-A purity, time-coverage and
invalid-control failure, and absence of persistent selector mutation.

Shared-backend successor preservation on the reconciled postimage also passed:

- F-ROSS12 production wiring run `35426047903`;
- F-CI96 F-ROSS12 postimage preservation run `35426047828`;
- F-GC42 live whole-window run `35426047891`;
- F-GC44 participant run `35426047827`;
- F-GC44 end-to-end run `35426047766`;
- F-VQ116 run `35426047859`.

Historical gates that freeze an earlier backend blob can report red after this
intentional backend successor. F-SI39 likewise rejects any production delta
outside its own historical slice. F-KT22 currently has a separate pre-existing
compile-list defect involving `mod_b110_smooth_freatic_projection`. These are
not used as positive PPA-LOW02 evidence and do not override the direct owner,
independent and successor-preservation results above. The PPA-WU02 closeout
replay on PR #362 likewise rejects the accumulated current production delta
against its frozen pre-WU02 base; that historical admission assertion is not a
current semantic-preservation oracle for the admitted PPA-LOW02 successor.

## Canonical admission

Functional PR: #360

Canonical merge:

`6c63b8d0e340669d9722bc5e3d947d42d2b467a5`

The work unit is therefore closed as `CANONICAL_ADMITTED_CLOSED`.

## Explicit nonclaims

This closeout does not claim:

- general SWAP `.SWP`/`.BBC` parser migration;
- raw DATE2 calendar-string ingestion;
- internal mode -2 as a normal user selector;
- mixed bottom-mode production profiles;
- RossFast execution of the legacy SWBOTB=2 application control;
- new groundwater-coupling semantics;
- SWBOTB=1, 3, 4, 5 or 8 migration;
- ROM changes.

## Remaining lower-boundary migration slices

The remaining source-bound application work is now selector-specific:

1. PPA-LOW05-APP: ordinary non-groundwater-owned DATE5/HBOT5 application;
2. PPA-LOW04: q(gwl) state/timing law;
3. PPA-LOW01: prescribed-groundwater-level hybrid boundary/state machine;
4. PPA-LOW03: deep-aquifer Cauchy explicit/implicit boundary;
5. PPA-LOW08: lysimeter active-set continuation.

Internal mode 9 remains non-normal, and internal -2 remains continuation-only.
