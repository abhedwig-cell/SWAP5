# PPA-WU05-A4 adversarial real-Richards coupling characterization

Date: 2026-09-30

Status: `QUALIFIED_NEGATIVE_AND_MIXED_RESEARCH_RESULT`

Workflow run: `36766001665`

Head: `e77db3e7dba332173e11ca69bbb282d115fc0604`

## Purpose

Challenge the outer macropore/Richards fixed-point coupling using a small set of adversarial regimes selected from the 4,800-case local reduced sweep.

The harness deliberately records non-convergence rather than treating every research regime as a required pass.

## Cases

All use B01 hydraulics, high research sorptivity scale `SorpMax=2`, `dt=0.1 d`, and ample macropore water.

### Wet/fresh — h = -20 cm

Predictor theta at the exchange node:

`0.3287605`.

Initial exchange rate:

`2.3660 cm d-1`.

The first Richards corrector did **not** converge:

- solver status: `RETRY_ADVISED`;
- nonlinear iterations: 64;
- backtracking attempts: 1116.

This is a real solver/coupling stiffness limit, not an assertion artifact.

### Mid/fresh — h = -50 cm

The solver converged for all six outer iterations.

Exchange sequence:

`2.7991 -> 2.1960 -> 2.3213 -> 2.2951 -> 2.3006 -> 2.29945 cm d-1`.

Relative changes:

- 21.5%;
- 5.71%;
- 1.13%;
- 0.238%;
- 0.0496%.

The fixed point is convergent but materially slower than the earlier mild fresh case.

### Dry/fresh — h = -200 cm

The solver converged for each individual frozen-exchange corrector, but the undamped outer iteration produced a period-two oscillation:

`3.9382 -> 0 -> 3.9382 -> 0 -> ... cm d-1`.

The high-exchange corrector saturates the exchange node; recomputing sorptivity then gives zero. The zero-exchange corrector restores the dry state and therefore restores the full sorptivity demand.

This is a genuine outer-coupling oscillation.

### Wet/aged — h = -20 cm

All six correctors converged.

Exchange sequence:

`0.603948 -> 0.586217 -> 0.586721 -> 0.586706 -> 0.586707 -> 0.586707 cm d-1`.

Convergence is rapid after the first correction.

## Conclusions

The coupling cannot be represented by one unconditional fixed corrector count across all regimes.

Three distinct regimes are now source/solver-observed:

1. weak, rapidly convergent coupling;
2. strong but convergent coupling;
3. non-convergent or oscillatory coupling.

There is still no evidence that exchange must be embedded inside the Newton Jacobian. Two cheaper stabilization mechanisms should be tested first:

- timestep reduction when a frozen-exchange Richards corrector itself requests retry;
- bounded under-relaxation when the outer exchange map oscillates.

## Architectural implication

The macropore/Richards coupling controller belongs outside the Richards solver:

- Richards reports convergence/retry;
- the outer coupling controller may damp exchange or reduce the physical timestep;
- rejected attempts must leave both matrix and macropore committed state unchanged.

This aligns with existing SWAP5 transaction ownership.

## Next step

Run one focused stabilization characterization:

1. wet/fresh timestep sweep to identify the first convergent step duration;
2. dry/fresh under-relaxed Picard test, starting with relaxation factor 0.5.

No production policy is selected yet.
