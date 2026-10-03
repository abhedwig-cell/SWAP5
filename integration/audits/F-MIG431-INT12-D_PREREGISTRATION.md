# F-MIG431-INT12-D preregistration

Date: 2026-10-03

Status: SOURCE CONTRACT RECOVERED; B1.11 exact-oracle binding pending
Branch: `work/ppa-wu06-interception-gash`
Pinned canonical base: `b0d2cc0ac749e1fa60ba4f5f610d01fc0b3b6ad9`

## Identity and scope

This is the already frozen PPA-WU04-D implementation slice for SWINTER=2/Gash. The provisional PPA-WU06-INTER01 record is superseded and retained only as reconciliation history.

The capability is SWAP 4.3.1 SWINTER=2 Gash source-window aggregate interception. It must reuse the canonically admitted F-MIG431-INT12-P0 source-window provenance/progress/restart seam. It must not introduce canopy physical storage: PPA-WU04 proves persistent physical state is empty for SWINTER=2.

Excluded: SWINTER=0/1/3 changes, Rutter storage, TOP03/SCV, RFM, Ribasim, macropores, solver/timestep/retry policy, broad meteorological parser migration, and event-weighted generalization not explicitly qualified here.

## Authority

Controlling authority:
- merged PPA-WU04 PR #333;
- `integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json`;
- corrected B1.11 `SWAP/MOD_meteo.f90`, SHA-256 `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`;
- F-PM06 source trace, `interception_daily()` lines 2055-2092.

Corroborating public source trace, also used by F-MIG431-INT12-C:
`SWAP-model/SWAP@07d74a82e9ba0465ec81a74e4d82b3dc03d856d9`, `src/atmosphere/interception.f90`.

The corroborating source is not allowed to replace B1.11 as admission authority. Production implementation waits until the exact B1.11 equation/table semantics are checked against it.

## Recovered Gash equation contract

For one immutable source window:

- intercepted supply `rpd = grai + gird` when `isua=0`; otherwise `rpd = grai`;
- time-dependent parameters are obtained by legacy AFGEN semantics at source time `t`:
  `pfree = afgen(pfreetb,t)`,
  `pstem = afgen(pstemtb,t)`,
  `cGash = 1-pfree-pstem`,
  `scanopy = afgen(scanopytb,t)/cGash`,
  `avprec = afgen(avprectb,t)`,
  `avevap = afgen(avevaptb,t)/cGash`;
- canopy-saturation precipitation:
  when `1-avevap/avprec > 1e-4`,
  `psatcan = -avprec*scanopy/avevap * log(1-avevap/avprec)`;
  otherwise `psatcan = avprec*scanopy/avevap`;
- if legacy gross rain `grai < psatcan`, `aintc = cGash*rpd`;
- otherwise `aintc = cGash*(psatcan + avevap*cGash/avprec*(rpd-psatcan))`.

The comparison uses `grai`, not `rpd`, in the saturation branch condition. Do not silently 'correct' this asymmetry without defect qualification.

## Ownership and transaction contract

`aintc` is a frozen source-window aggregate, not canopy storage. P0 owns accepted progress and restart provenance. Numerical retry subdivision may only apportion the already frozen aggregate. It may not reevaluate Gash on each retry span.

Rejected trials advance neither progress nor interception mass. Mid-window restart must preserve source-window identity, frozen aggregate and accepted amount exactly. Gross precipitation/irrigation and net surface supply are one transfer identity; they must not both be booked as independent accepted input.

## Before production implementation

Recover and pin from exact B1.11:
1. the exact `interception_daily` Gash body and branch ordering;
2. AFGEN interpolation semantics at table knots and outside-table bounds;
3. input table units and admissible domains for `pfreetb,pstemtb,scanopytb,avprectb,avevaptb`;
4. treatment of zero/near-zero `cGash,avprec,avevap`;
5. exact downstream `ProcessMeteoDT` apportionment into `aintcdt,nraidt,wfrac,ptra`;
6. rain/irrigation split and snow interaction on the qualified route.

Do not invent guards absent from legacy semantics. Invalid-domain fail-closed behavior may be added only outside the valid legacy envelope and must be independently tested.

## Qualification gates

- independent exact B1.11 Gash source-window oracle, including both saturation branches and threshold vicinity;
- AFGEN knot/interpolation/boundary vectors;
- zero rain, small rain, large rain, varying table parameters, and irrigation selector cases;
- exact or preregistered-tolerance downstream `aintcdt,nraidt,wfrac,ptra`;
- unequal numerical subspan conservation and final aggregate closure;
- rejected-trial immutability and failed-then-accepted retry from identical accepted progress;
- mid-window restart without duplicate/lost aggregate;
- A/B/A and O0/O2 identity;
- hard accepted mass closure;
- preservation of PPA-WU01, PPA-WU03, PPA-WU04-A/B, F-MIG431-INT12-P0, F-MIG431-INT12-C protected surfaces, and SWINTER=3 Rutter.

## Current gate

Production implementation is HELD until the exact B1.11 Gash body plus AFGEN/table semantics are materialized or otherwise independently oracle-bound. The equation shape is recovered; the exact admission oracle is not yet complete.
