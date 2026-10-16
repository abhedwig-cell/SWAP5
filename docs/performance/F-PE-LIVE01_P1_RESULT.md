# F-PE-LIVE01 P1 result — exact-trial directional cost bound

Date: 2026-09-27

Status: `PASS_DIRECTIONAL_COST_BELOW_ADVANCEMENT_GATE`

PR:
`#656 — F-PE-LIVE01: required live-trial cost rebaseline`

Qualified workflow run:
`36303215923 — F-PE-LIVE01 required live-trial rebaseline`

Job:
`p1-directional-cost`

## Scope

P1 measures the marginal wall-clock cost of accepted-direction / response-tangent production on the exact live head population.

For each of the 12 difficult live groups:

1. the production-shaped live MODFLOW6 coupling generates the prescribed-head sequence;
2. an identical dynamic SWAP origin is recreated;
3. those exact heads are replayed with normal fresh accepted-direction production (FULL);
4. another identical origin replays the same heads with accepted-direction production suppressed only in the copied research participant (QONLY);
5. every replay candidate is discarded.

No production source is modified.

## Physical-path identity

FULL and QONLY are physically identical on the measured replay population:

- q_swap identity: exact in all groups;
- same prescribed heads;
- same transaction calls;
- same accepted substeps;
- same total attempts;
- same temporal retries/rejections;
- same solver rejections;
- same nonlinear iteration counts;
- same Jacobian-build counts;
- same headcalc counts;
- same backtracking counts.

The intentional difference is the directional linear work.

QONLY removes the extra linear solves required by accepted-direction propagation while leaving the base nonlinear solve path unchanged.

## Aggregate timing

Paired sum of per-group median exact-trial times:

- FULL: `924,603 ns`;
- QONLY: `741,804 ns`.

Thus:

`R_dir = T_FULL / T_QONLY = 1.246424932`

and:

`F_dir = (T_FULL - T_QONLY) / T_FULL = 0.197705394`.

Measured accepted-direction marginal fraction:

`19.7705%`.

Median group directional fraction:

`19.6077%`.

## Group range

Measured directional fractions range from approximately:

- 16.14% for B01 mid, negative history;
- to 21.96% for B01 wet, negative history.

Several groups individually exceed 20%, but the preregistered aggregate gate is authoritative.

## Directional linear work

The directional path adds linear solves without changing the nonlinear trajectory.

Examples:

- 2-head, no-retry groups:
  - FULL linear solves: typically 10;
  - QONLY: 8;
  - directional delta: 2.
- B01 wet:
  - FULL: 60;
  - QONLY: 48;
  - delta: 12.
- O05 wet:
  - FULL: 68;
  - QONLY: 56;
  - delta: 12.
- O14 wet:
  - FULL: 34;
  - QONLY: 28;
  - delta: 6.

This directly ties the measured wall-clock increment to directional linear-system work rather than to a changed physical solve path.

## Gate disposition

Preregistered directional successor gate:

`F_dir >= 20%`.

Observed:

`F_dir = 19.7705%`.

Decision:

`DO_NOT_ADVANCE_DIRECTIONAL_AS_PRIMARY_SUCCESSOR`.

The result is close to the threshold and shows that tangent production is not negligible. It does not justify making it the next primary performance workunit under the frozen rule.

## Interpretation

Approximately 80.2% of the measured exact-trial time remains after accepted-direction production is removed.

Therefore the dominant next question is the cost structure of the base q/state Richards solve itself.

P0 also showed that the current c=0.65 live matrix contains:

- 20 temporal retries;
- zero solver rejections;
- zero internal retries;
- 236 nonlinear/Jacobian events;
- 380 FULL linear solves.

P1 narrows the next target to the base solve rather than the directional response service.

## Decision

`ADVANCE_BASE_Q_STATE_DECOMPOSITION`

Do not open a standalone tangent optimization from LIVE01 P1.

No production source change or admission is authorized by P1.
