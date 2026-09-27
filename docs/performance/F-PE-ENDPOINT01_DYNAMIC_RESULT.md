# F-PE-ENDPOINT01 dynamic authority result

Date: 2026-09-26

Status: `PASS_DIRECT_Q_SPACE_AUTHORITY`

Preregistration:

`docs/performance/F-PE-ENDPOINT01_PREREGISTRATION.md`

P0 amendment:

`docs/performance/F-PE-ENDPOINT01_P0_CONVERGENCE_AMENDMENT.md`

Primary harness:

`tests/fpe/run_fpe_endpoint01_dynamic.sh`

Historical preservation harness:

`tests/fpe/run_fpe_endpoint01_historical_preservation.sh`

## Trigger

TEMPORAL07 showed that both c=0.50 and c=0.65:

- converge in the live one-SWAP/one-MODFLOW-cell production architecture;
- close the production q_swap/q_groundwater residual to about 1e-22 m/s;
- satisfy the frozen endpoint-head gate;
- fail the inherited independent physical residual gate at approximately 2.735e-14 m/s.

The inherited authority used a three-point local q(H) fit based on constant-flux groundwater probes at:

- -2e-8 m/s;
- 0;
- +2e-8 m/s.

The dynamic production exchange is approximately +1e-7 m/s.

ENDPOINT01 therefore tested a direct constant-flux q-space authority without extrapolating that local q(H) fit.

## P0 — groundwater response characterization

The preregistered q ladder was attempted under unchanged one-cell MODFLOW6 solver controls.

Completed:

- -1.5e-7 m/s;
- -1.0e-7;
- -5.0e-8;
- -2.0e-8;
- 0;
- +2.0e-8;
- +5.0e-8;
- +1.0e-7.

The outer characterization point +1.5e-7 m/s did not converge and is recorded as:

`ORACLE_UNAVAILABLE`

It was not synthesized or used for fitting.

The historical three-point q(H) fit has a maximum absolute q error over the available ladder of:

`6.23468056361197083e-14 m/s`

This error is small in absolute terms but materially larger than the frozen physical residual gate:

`1e-15 m/s`

Therefore the historical local fit is not sufficiently accurate to serve as a dynamic-origin residual authority at the ~1e-7 m/s endpoint scale.

## P1/P2 — direct q-space endpoint authority

For each policy, the independent residual was defined as:

`R(q) = q_swap(H_gw(q)) - q`

where:

- `H_gw(q)` comes from a fresh constant-flux MODFLOW6 solve;
- `q_swap` comes from one non-committing SWAP corrector at that head;
- every SWAP probe starts from the same captured dynamic origin;
- no production HCOF/RHS path is used.

### c=0.50

Direct root:

- q = `9.97365892267873207e-08 m/s`;
- H = `-0.750000625864578163 m`;
- direct root residual = `-5.67482494681676331e-16 m/s`;
- root-search expansions = 0;
- bisection iterations = 24.

Production endpoint comparison:

- production H = `-0.750000625864606141 m`;
- direct H = `-0.750000625864578163 m`;
- head error = `-2.79776202205539448e-14 m`;
- direct q-space residual at production head =
  `1.75870006703782015e-16 m/s`;
- historical three-point-fit residual at the same production head =
  `2.73563604113793708e-14 m/s`.

Frozen gates:

- endpoint-head <= 5e-10 m: PASS;
- physical residual <= 1e-15 m/s: PASS.

### c=0.65

Direct root:

- q = `9.97104234605797337e-08 m/s`;
- H = `-0.750000627156418354 m`;
- direct root residual = `1.45082979579268766e-17 m/s`;
- root-search expansions = 0;
- bisection iterations = 25.

Production endpoint comparison:

- production H = `-0.750000627156418131 m`;
- direct H = `-0.750000627156418354 m`;
- head error = `2.22044604925031308e-16 m`;
- direct q-space residual at production head =
  `1.45082847230370757e-17 m/s`;
- historical three-point-fit residual at the same production head =
  `2.73512847384965168e-14 m/s`.

Frozen gates:

- endpoint-head <= 5e-10 m: PASS;
- physical residual <= 1e-15 m/s: PASS.

## Causal diagnosis

The TEMPORAL07 blocker is not a physical coupling failure.

It is not attributable to c=0.65.

It is caused by using the historical local three-point q(H) fit outside the scale where its residual accuracy is sufficient for the frozen 1e-15 m/s endpoint gate.

The direct q-space authority removes that extrapolation and shows that both c=0.50 and c=0.65 satisfy the unchanged physical endpoint gates.

## P3 — historical preservation

The historical canonical one-cell closeout fixture was rerun with both:

1. the original historical independent endpoint oracle;
2. the new direct q-space oracle.

Historical original endpoint:

- H = `-0.714999970005842145 m`;
- residual = `-3.78973439691400074e-17 m/s`;
- original local-fit error = `7.06032454722560487e-16 m/s`.

Direct q-space endpoint:

- q = `-1.18124926532745426e-13 m/s`;
- H = `-0.714999970005808949 m`;
- residual = `-9.47560877278753900e-18 m/s`.

Head difference:

`3.31956684362921806e-14 m`

Frozen historical preservation gate:

`<= 5e-10 m`

Result:

PASS.

Thus the direct q-space authority is compatible with the historical canonical closeout and is not a dynamic-origin special case that breaks prior evidence.

## Decision

ENDPOINT01 passes.

The historical three-probe q(H) fit remains useful inside its original closeout scale but is not a valid residual authority for the larger dynamic-origin exchange scale when the acceptance gate is 1e-15 m/s.

The qualified independent authority for dynamic-origin endpoint admission is the direct constant-flux q-space root:

`q -> fresh MODFLOW H(q) -> SWAP q_swap(H(q)) -> R(q)`

No production source or acceptance tolerance is changed.
