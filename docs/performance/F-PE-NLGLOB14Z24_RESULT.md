# F-PE-NLGLOB14Z24 result — groundwater coupling-surface relevance of moving-interface chatter

Date: 2026-09-30

Status:

`QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED`

Qualification authority:

- workflow run: `36722000431`;
- contract-audit job: `109909196397`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z24-coupling-surface-relevance@3393a5ef9357946c28389fce60a6385d6eca72bd`

## Frozen questions and answers

### Q1 — external gateway payload

Result:

`INTERNAL_OWNERSHIP_NOT_EXTERNAL_SURFACE`.

The admitted external groundwater gateway exposes:

- cell identity;
- coupling window `t0/t1`;
- groundwater flux;
- groundwater head;
- candidate/prepared publication tokens.

It exposes no:

- saturated-tail index;
- moving split face;
- upper/lower ownership identifier;
- ownership direction;
- ownership-change event;
- chatter event.

### Q2 — scientific interface quantities

Confirmed.

The admitted scientific groundwater boundary is expressed through hydraulic head and whole-window water exchange / paired interface flux.

Internal moving-interface ownership is not an exchanged groundwater quantity.

### Q3 — mass/publication authority

Confirmed.

Accepted groundwater publication is tied to:

- accepted SWAP candidate;
- prepared groundwater state/timestep;
- whole-window interface mass ledger;
- coupling-window identity and lineage.

The mass ledger stages and commits whole-window exchange. It does not stage moving-interface ownership events.

### Q4 — temporal mapping

Result:

`TIMEINT_TO_COUPLING_WINDOW_MAPPING_NOT_ESTABLISHED`.

No frozen authority explicitly states that one fine TIMEINT17/NLGLOB research interval equals one external groundwater coupling window.

That equivalence therefore may not be inferred.

## Qualification result

The frozen aggregate classification is:

`QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED`.

No contradiction was found between the audited production code and owning documentation.

## Scientific and architectural interpretation

The repeated bidirectional chatter established by Z20-Z22 is real internal SWAP behavior.

However, under the current admitted groundwater coupling contract, it is not an external groundwater event stream.

This matters because Z23 demonstrated that event coalescing can clean up ownership publication, but Z24 shows that the current groundwater interface has no such ownership publication channel to clean up.

Therefore:

- chatter remains relevant to internal solver/runtime behavior;
- it may matter for diagnostics and future APIs;
- it may have execution cost;
- it does not currently require a groundwater coupling API change.

The Z23 settled-event publication mechanism should not be promoted into the groundwater coupling contract merely because it works on the internal event sequence.

## Qualified claim boundary

Qualified:

- moving-interface ownership is absent from the current external groundwater gateway;
- moving-interface ownership is absent from the public groundwater coupling contract;
- whole-window exchange and hydraulic head are the coupling quantities;
- mass publication is ledger/window based;
- fine TIMEINT interval to coupling-window equivalence is not established.

Not qualified:

- chatter has zero runtime cost;
- chatter has zero effect on internal diagnostics;
- future coupling APIs will never expose ownership;
- a future temporal-ownership production mode can ignore chatter;
- disappearance semantics;
- production mode-7 temporal ownership admission.

## Consequence

The next safe work should return to the internal temporal-ownership problem.

Priority should be:

1. quantify the computational cost of repeated internal ownership chatter;
2. determine whether chatter changes any internal accepted physical output beyond event bookkeeping;
3. only if material cost or internal diagnostic pollution is demonstrated, evaluate an internal implementation strategy that preserves exact accepted-state ownership.

Do not change the groundwater coupling contract for this issue under current authority.

## Production boundary

Research/audit only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
