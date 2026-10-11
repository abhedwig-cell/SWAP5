# F-PE-NLGLOB03 closeout — residual-floor structure

Date: 2026-09-29

Final status:

`NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@ad1c4b9193238a46dff95bd30e251adfc0426302`

Qualification authority:

- run `36538655668`;
- job `109308627200`;
- SUCCESS.

## Closure

NLGLOB03 rules out final total-residual summation as the explanation for the NLGLOB02 near-floor stagnation.

The poor-model near-floor subset is mixed:

- total balance dominates about 65.8%;
- compartment balance dominates about 34.2%.

But compensated summation changes neither the median total residual nor the pass/fail side of the existing total-balance tolerance:

- >=25% total-ratio movement: 0%;
- naive-above / compensated-at-or-below floor crossings: 0%;
- route-mode family summation signal: 0/6.

The floor therefore arises before the final total summation.

## Preserved authority

NLGLOB02 remains valid:

`NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`.

NLGLOB03 refines that conclusion by excluding ordinary total-vector summation error.

BALTOL02 remains unchanged production authority.

TIMEINT17 remains blocked by endpoint globalization.

## Direct successor

Open:

`F-PE-NLGLOB04 — residual-term cancellation and attainable local precision attribution`.

The successor must remain observational first.

It should decompose each active compartment residual into at least:

1. storage-rate term;
2. upper/interface flux contribution;
3. lower/interface flux contribution;
4. source/sink contribution where active;
5. dynamic-top surface contribution for the top node.

For each term, record magnitude, signed sum, local cancellation ratio and residual remainder.

The first question is whether near-floor residuals are the small difference of much larger O(1) terms, and whether that cancellation structure differs between poor- and adequate-model subsets.

No convergence-contract candidate is authorized until that decomposition is known.

## Production boundary

No production source change.

No tolerance or mass-gate change.

No solver-policy change.

`LEGACY_NUMERICS` remains default.
