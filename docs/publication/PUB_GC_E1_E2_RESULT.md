# PUB-GC E1/E2 result — interface identity and transaction authority

## Status

**SUPPORTED_RESTRICTED — first publication evidence block passed**

Date: 2026-09-18.

Source branch:

`work/pub-gc-e1-e2-interface-transaction-evidence`

Qualified source head:

`0022e854000afe5a050303d9a0709f72b7dae518`

Canonical baseline at workunit start:

`integration/f-ci-canonical@c42db098cc246e3da06472a34979bdf24cfa81cb`

Primary evidence runs:

- push workflow run `35342311228` — **PASS**;
- pull-request workflow run `35342313248` — **PASS**;
- existing F-GC44 real SWAP + live MODFLOW6 qualification on the same head — **PASS**;
- F-VQ116 independent F-GC44 qualification on the same head — **PASS**;
- F-GC42 whole-window service qualification on the same head — **PASS**.

The two PUB-GC evidence runs produced identical numerical E1 values.

## Envelope

The result applies only to the deliberately restricted F-GC44 publication-evidence envelope:

- one real FMR/SWAP reference-Richards column;
- one live MODFLOW6 6.8.0 cell;
- coupling window `DeltaT = 1.0e-4 day = 8.64 s`;
- near-equilibrium state and forcing;
- admitted accepted-trajectory analytic predictor response;
- drainage, root extraction, macropore flow, snow and soil temperature inactive;
- no physical N:1 aggregation claim.

This is an identity and authority result, not a broad hydrological-regime result.

## E1 — interface identity and conservation

### Predictor response

The real SWAP predictor produced:

| quantity | value |
| --- | ---: |
| predictor `q_bot` | `1.0000000000000000e-6 cm d-1` |
| predictor `q_u` | `-9.658852120479678e-7 cm d-1` |
| response coefficient `u` | `3.402936037279093e-5` |
| canonical storage start | `1.0430631535459627` native column-depth units |
| canonical storage end | `1.0430631535459627` native column-depth units |
| storage change | `0` |
| total inflow | `1.0e-10` native column-depth units |
| total outflow | `1.0e-10` native column-depth units |
| canonical mass residual | `0` |

For this restricted FMR route, the storage implementation is `sum(dz * water_content) + ponding`; `dz` is in centimetres, so the native mass carrier corresponds to centimetres of water-equivalent column depth.

The preregistered storage identities closed:

```text
storage_end - storage_start = storage_change

storage_change - (total_in - total_out) = mass_residual
```

with exact zero residual in the reported double-precision result.

The F-GC30 predictor algebra also closed within representation tolerance:

```text
q_u =
    u * (H_end - H_start) * 100 / DeltaT_day
    - q_bot
```

This establishes internal consistency of `q_bot`, `q_u`, `u` and the predictor head change in this envelope. It does **not** yet establish that `u` equals the actual finite-window head-to-exchange derivative `J_R`; that remains E4.

### Accepted corrector and interface ledger

The coupled real SWAP + MODFLOW6 solve converged in two outer iterations.

Final values:

| quantity | value |
| --- | ---: |
| accepted MODFLOW head | `-0.71499996773317653 m` |
| accepted SWAP interface rate | `-1.2708557527755854e-13 m s-1` |
| realized MODFLOW interface rate | `-1.2708580747683645e-13 m s-1` |
| final rate residual | `2.3219927791065243e-19 m s-1` |
| accepted SWAP native bottom amount | `-1.0980193703981059e-10 cm` |
| same amount in metres | `-1.0980193703981059e-12 m` |
| public rate integrated over 8.64 s | `-1.0980193703981057e-12 m` |
| committed ledger exchange | `-1.0980193703981059e-12 m` |

The accepted public rate therefore integrates to the same outward exchange booked by the ledger to within floating-point representation:

```text
q_swap_public * DeltaT_s
    = ledger_exchange_m
```

within the preregistered representation-scale tolerance.

This is the first publication-oriented evidence tying the real corrector rate directly to the exactly-once committed interface amount.

## Sign-hypothesis falsification and adjudication

The first E1/E2 execution, workflow run `35342179045`, **failed** a preregistered sign hypothesis.

The original preregistration expected:

```text
q_swap_public * DeltaT_s
    + ledger_exchange_m
    = 0
```

The failure was not removed or reclassified as numerical noise.

Code-trace adjudication showed that the hypothesis had omitted one sign transformation:

```text
qbot_mean_cm_per_day =
    - bottom_outward_exchange_native / DeltaT_day

q_swap_public =
    - qbot_mean_cm_per_day * 0.01 / 86400
```

The two minus signs cancel. The public outward-from-SWAP rate and the ledger's SWAP-outward amount therefore have the same sign.

The corrected, physically consistent identity is:

```text
q_swap_public * DeltaT_s
    - ledger_exchange_m
    = 0
```

No production code or coupling semantics were changed. The preregistration was amended with an explicit erratum before the successful rerun.

This falsification is retained as part of the evidence trail because it demonstrates why the publication study must trace sign semantics explicitly rather than infer them from variable names.

## E2 — transaction and mass authority

### Deterministic failure injection

The existing F-GC41 acceptance/retry suite passed all seven tests.

It confirms for the deterministic acceptance contract that:

- SWAP preflight failure publishes nothing;
- MODFLOW preflight failure publishes nothing;
- ledger preflight failure publishes nothing;
- invalid window identity touches no participant;
- recoverable pre-publication failure requests a fresh retry;
- failure after the publication point is not mislabeled as rollback-safe;
- MODFLOW timestep readiness is non-mutating;
- MODFLOW timestep finalization is one-shot.

### Real SWAP participant authority

The real F-GC44 route additionally verified that the authoritative tuple

```text
(SWAP revision,
 SWAP committed time,
 ledger committed count,
 ledger committed exchange)
```

remained:

```text
(0, 0, 0, 0)
```

after:

1. a real prescribed-head SWAP corrector trial;
2. discard of that trial;
3. preparation of a real candidate plus prepared ledger;
4. abort before the publication point;
5. each non-final coupled corrector before discard;
6. each non-final corrector after discard;
7. final SWAP, MODFLOW and ledger preflights.

This directly supports the manuscript statement that computation does not imply hydrological acceptance.

### Publication ordering

After all preflights passed, authority advanced only in the preregistered sequence.

After MODFLOW `finalize_time_step`:

```text
SWAP revision = 0
ledger count  = 0
```

After SWAP commit:

```text
SWAP revision       = 1
SWAP committed time = 1.0e-4 day
ledger count        = 0
```

After ledger commit:

```text
SWAP revision = 1
ledger count  = 1
ledger amount = accepted SWAP bottom exchange
```

A second MODFLOW timestep finalization was rejected by the existing one-shot lifecycle.

The evidence therefore supports **exactly-once publication of the accepted interface transfer** inside the qualified F-GC44 envelope.

## Claim updates

The E1/E2 result changes the manuscript evidence state as follows:

- **GC-C05** — physical/interface distinction and accounting of coupling quantities: from `PLANNED_EXPERIMENT` to **SUPPORTED_RESTRICTED**, with the important limitation that the current equilibrium case has zero storage change and therefore does not yet exercise a non-trivial storage-mediated `q_bot` versus `q_u` case.
- **GC-C06** — rejected calculations contribute zero authoritative interface mass: **SUPPORTED_RESTRICTED**, now demonstrated with a real SWAP participant as well as deterministic acceptance tests.
- **GC-C07** — accepted interface mass is published exactly once after preflight: **SUPPORTED_RESTRICTED**, with direct rate-to-ledger amount identity in the real end-to-end route.

GC-C09 remains a hypothesis: E1 does not determine whether `u` represents `J_S`, `J_R`, or a bounded coupling approximation.

## Scientific limitations

The strongest limitation is also scientifically useful: the E1 state is intentionally near equilibrium.

Because:

```text
storage_change = 0
```

this experiment validates accounting identity and sign/unit semantics but does not yet probe the dynamic case in which storage response materially separates native boundary flux from groundwater-facing exchange.

Therefore E1 is not considered complete for the manuscript's broader hydrological interpretation. The next hydrological evidence block must include a deliberately non-zero storage-change case.

Likewise, E2 does not yet establish restart continuity after a process failure occurring after the irreversible publication point. It establishes pre-publication rejection/abort semantics and exactly-once successful publication. Durability/restart evidence remains a separate claim if the manuscript chooses to emphasize it.

## Decision

**E1/E2 first gate: PASS, restricted envelope.**

No production defect was identified.

One research-hypothesis sign error was identified, documented and corrected before rerun.

The evidence is sufficient to proceed to E3 controlled coupling-window/feedback characterization while retaining a targeted E1 extension for non-zero storage-change conditions.
