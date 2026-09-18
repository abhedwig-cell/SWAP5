# PUB-GC E1/E2 preregistration — interface identity and transaction authority

## Status

**PREREGISTERED BEFORE PUBLICATION-EVIDENCE RUN**

Date: 2026-09-18.

Canonical baseline at workunit start: `integration/f-ci-canonical` @ `c42db098cc246e3da06472a34979bdf24cfa81cb`.

Publication line: PUB-GC / COUPLE.

This workunit adds no production physics and changes no coupling semantics. It consolidates publication evidence from the admitted F-GC41/F-GC44 route and adds qualification-only diagnostics to the existing F-GC44 support bridge.

## Questions

### E1 — interface identity and conservation

Can the real SWAP predictor/corrector route expose a self-consistent, unrounded record of:

- predictor native lower-boundary flux `q_bot`;
- MODFLOW-facing predictor exchange `q_u`;
- response coefficient `u`;
- start/end storage and storage change;
- total interval inflow/outflow;
- mass residual;
- final accepted whole-window bottom exchange;
- accepted interface ledger amount?

### E2 — transaction and mass authority

Do real SWAP trial calculations and prepared-but-aborted publication states leave committed SWAP state and authoritative interface mass unchanged, and does successful coupled publication advance authority exactly once in the required order?

## Frozen execution envelope

The first E1/E2 run deliberately reuses the already bounded F-GC44 end-to-end envelope:

- real FMR/SWAP reference Richards route;
- one SWAP column;
- one live MODFLOW6 6.8.0 cell;
- coupling window `1.0e-4 day`;
- near-equilibrium forcing/profile;
- active processes restricted exactly as in F-GC44;
- analytic accepted-trajectory response;
- no N:1 scientific aggregation claim.

This is an evidence-consolidation experiment, not an envelope-expansion experiment.

## E1 predeclared identities

Let the canonical predictor response expose:

```text
q_bot
q_u
u
H_start
H_end
DeltaT
```

The historical F-GC30 response algebra must reproduce:

```text
q_u =
    u * (H_end - H_start) * 100 / DeltaT_day
    - q_bot
```

in native `cm/day` units, within floating-point representation tolerance.

The canonical mass record must satisfy:

```text
storage_change = storage_end - storage_start

mass_residual =
    storage_change - (total_in - total_out)
```

The run must report complete mass accounting.

For the final accepted real corrector:

```text
ledger_exchange_m =
    final_bottom_outward_exchange_native_cm * 0.01
```

The public corrector rate and native integrated bottom amount use opposite sign conventions in the current adapter chain; therefore the expected cross-convention identity is:

```text
q_swap_public_m_per_s * DeltaT_s
    + ledger_exchange_m
    = 0
```

This sign test is intentionally preregistered because a failure would identify a scientifically relevant interface-accounting inconsistency rather than a reason to redefine the expected sign after observing the result.

## E1 numerical tolerances

The experiment uses representation-scale checks for algebraic identities, not hydrological calibration tolerances.

- storage identity: `64 * eps * scale`;
- mass-residual identity: `64 * eps * scale`;
- q_u reconstruction: `128 * eps * scale`;
- final ledger amount identity: `64 * eps * scale`;
- cross-sign rate/amount identity: `256 * eps * scale`.

The existing F-GC44 coupled flux convergence tolerance remains unchanged at `1e-15 m/s`.

## E2 predeclared authority states

At accepted origin:

```text
SWAP revision = 0
SWAP committed time = 0
ledger committed count = 0
ledger committed exchange = 0
```

The following operations must leave this tuple unchanged:

1. a real SWAP corrector trial before discard;
2. discard of that trial;
3. preparation of a real SWAP candidate plus prepared ledger;
4. abort before the publication point;
5. every non-final coupled corrector before discard;
6. discard of every non-final corrector;
7. final SWAP/ledger/MODFLOW preflights.

After the publication point, authority must advance in this order:

```text
MODFLOW finalize_time_step:
    SWAP revision still 0
    ledger count still 0

SWAP commit:
    SWAP revision = 1
    SWAP committed time = DeltaT
    ledger count still 0

ledger commit:
    SWAP revision = 1
    ledger committed count = 1
    ledger amount = final accepted bottom exchange
```

A second MODFLOW timestep finalization must be rejected by the existing one-shot lifecycle.

## Deterministic failure injection

The existing F-GC41 deterministic tests are part of E2 and must remain green. They cover:

- SWAP preflight failure;
- MODFLOW preflight failure;
- ledger preflight failure;
- invalid window identity;
- failure after the publication point not being misclassified as rollback-safe retry;
- non-mutating MODFLOW timestep readiness;
- one-shot MODFLOW finalization.

For each preflight failure the test requires zero participant publication and a fresh retry request.

## Interpretation rules

A PASS establishes these identities only inside the frozen F-GC44 envelope.

It does not establish:

- broad hydrological transferability;
- large head-jump admissibility;
- N:1 physical aggregation validity;
- active drainage/root uptake/macropore/snow/temperature coverage;
- ACCELERATE performance value.

A failure of an E1 sign or balance identity is a scientific blocker for the current PUB-GC coupling claim and must be investigated before E3 convergence experiments proceed.

A failure of an E2 authority rule is a transaction/mass-publication blocker and must not be bypassed by weakening publication wording.
