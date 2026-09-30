# PPA-WU05-A3 E3 local event-memory result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / H6_SUPPORTED_NOT_YET_QUALIFIED`

## Question

Does the B1.11 sorptivity-history triplet represent real process memory, or can it be reconstructed/discarded when the current matrix and macropore water stores are identical?

This is a direct research test of H6.

## Method

A conservative two-reservoir reduction was used:

- macropore storage loses absorbed water;
- matrix storage gains exactly the same amount;
- matrix water content is updated from that gain;
- top input enters only the macropore reservoir;
- rapid drainage is held at zero;
- absorption and event-history evolution use the source-bound SWABS=1 equations from B1.11.

Two states were constructed with identical current physical stores:

- macropore storage = `0.7 cm`;
- matrix `theta = 0.16`;
- same geometry, parameters, forcing and step duration.

Only sorptivity event history differed.

### Fresh event

- `TimAbsCum = 0`;
- no existing sorptivity-event state.

### Aged event

- `TimAbsCum = 0.5 d`;
- event sorptivity initialized consistently with the same current moisture deficit;
- `ThtSrpRef = 0.47`.

## Result

For the next identical `0.1 d` step with top macropore input `0.2 cm d-1`:

Fresh event:

- absorption rate: `1.02318 cm d-1`;
- next matrix theta: `0.17112`;
- next macropore storage: `0.61768 cm`.

Aged event:

- absorption rate: `0.22577 cm d-1`;
- next matrix theta: `0.16245`;
- next macropore storage: `0.69742 cm`.

The fresh event absorbs more than four times as fast even though the two experiments begin with the same current matrix moisture and macropore storage.

Whole two-reservoir water balance residuals are about `1e-16 cm`.

## Interpretation

The event-history state is not redundant bookkeeping.

The B1.11 source formulation is explicitly non-Markovian with respect to current matrix water content and macropore storage alone. At minimum, the sorptivity-history variables materially affect the next physical flux.

This strongly supports the A1/A2 decision to persist:

- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`.

Dropping or reconstructing these solely from current water stores would change the model physics.

## H6 disposition

`SUPPORTED_BY_FIRST_CONSERVATIVE_TWO_RESERVOIR_FALSIFICATION_ATTEMPT`

Not yet qualified because:

- the experiment is reduced and synthetic;
- Darcy absorption is not yet active;
- full B1.11 domain geometry is not yet represented;
- coupled Richards feedback is intentionally excluded.

## Next step

Proceed to E4 crack-history isolation, then E5 rapid drainage. The E3 result should be preserved as a regression property of any later R1/R2 implementation.
