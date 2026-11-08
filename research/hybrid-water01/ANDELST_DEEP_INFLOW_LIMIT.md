# Andelst deep saturated inflow limit

Four-day day-453 replay, March 30 to April 2, 1999. See
[accepted exchange components](ANDELST_SATURATED_EXCHANGE_SPLIT.md).
Both models reproduced their established outputs with read-only
instrumentation. The V9 comparison used 4,010 accepted observations
matched by step duration, two stock endpoints, rapid outflow and
signed net exchange. The 12,423 B0 records paired the last potential
evaluation and accepted flux by clock and step duration.

| Node | B0 potential mm | B0 accepted mm | V9 potential and accepted mm | B0 mean driving head cm | V9 mean driving head cm |
|---|---:|---:|---:|---:|---:|
| 90 | 16.32787 | 0.00610 | 1.77149 | 11.40174 | 1.23703 |
| 91 | 16.44296 | 0.00661 | 2.46672 | 11.88495 | 1.78295 |
| 92 | 16.54498 | 0.00726 | 3.41526 | 12.37103 | 2.55366 |

The conductance at each node agreed to the printed precision.
The reconstructed Darcy potential agreed with every logged amount
within 1.1e-18 cm. B0 has the larger driving head and potential,
but accepts only 0.037–0.044% of that potential. V9 accepts it all.

For instantaneous bypass, legacy MacroRate B.1 substitutes pore
volume below the matrix groundwater level for the total domain
capacity when significant inflow comes exclusively from the true
saturated matrix (rate threshold 1e-7). The V9 standard rate adapter
uses total domain capacity for this inflow calculation.

A read-only counterfactual applied the legacy conditions and
storage deadband on each accepted V9 state, using cell-face volume
below its matrix groundwater level and the V9 potential inflows and
outflows. Main-domain stock exceeded that capacity by
0.01406–0.01922 cm. The counterfactual accepted zero deep inflow
on all 4,010 states, against 7.65347 mm in V9. V9 output and final
restart were byte-identical to the control. This establishes the
impact of the missing conditional capacity on frozen states. It
does not predict the closed-loop trajectory after changing the
limiter. A conservative native implementation should keep the
conditional inflow capacity distinct from total capacity and use
the same limited rates in the solver and accepted water ledger.
