# Andelst spring 1999 drainage comparison

Canonical evidence pin: `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
V9 inputs and outputs are from `integration/dataqual15/V9_FULL481_EVIDENCE_20261107.zip`,
member directory `s5-upper-support-final-original481-O2`. The original SWAP
archive SHA-256 is `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.
B0 observations are GNU Fortran 13.3 O2 with the previously qualified
day-365 sidecar and original physics. The daily published rows through
April 26 exactly match the continuous B0 series. Its reported DRN is
ordinary plus rapid drainage. The sign convention for net bottom exchange
is positive into the column in both models.

## March 1 through April 26

| Daily totals aggregated to mm | B0 | V9 | V9 minus B0 |
|---|---:|---:|---:|
| Ordinary drainage | 3.4135 | 3.6536 | 0.2401 |
| Rapid drainage | 119.4745 | 142.1059 | 22.6314 |
| Net bottom inflow | 57.0992 | 82.4735 | 25.3743 |

The B0 printed matrix and main/remaining macropore stocks changed by
-7.8003, -2.0276 and -0.5676 mm respectively. Surface pond storage
was unchanged between the endpoints. The V9 archive does not provide
the two target endpoint stocks at matching dates. Do not infer a
stock difference by subtracting just the drainage and bottom fluxes.

## Dry March 30 through April 2

There was zero rain, zero ordinary drainage and zero direct or pond-fed
macropore supply in the V9 budget. V9 continued rapid drainage by
5.8476 mm while B0 recorded zero. Net bottom inflow was 11.8552 mm in
V9 and 5.0600 mm in B0.

The B0 worker logged the most recent domain-1 RAPIDDRAIN potential at
each accepted MacroIntegral call, matched by identical clock and step
size. All 12,423 matched accepted calls had zero potential and zero
accepted rapid drain. The domain water level ranged between -84.09
and -82.91 cm. The drain bottom was -85 cm. This rules out an
absence of positive level difference as the sole B0 explanation.

The original RAPIDDRAIN calls VOLUNDR with the domain bottom minus
another half cell. The SWAP5 geometry integral uses actual cell
faces. A separate B0 counterfactual removed only that extra half cell
in RAPIDDRAIN. It completed from the same year checkpoint to April
26. Rapid drainage in the dry window increased by 0.2770 mm, just
4.7% of the V9 gap. Across the full spring it increased by 0.8111 mm
against a 22.6314 mm gap. This source difference contributes but
does not explain most of the seasonal result. The existing
`run_ppa_wu05a10_rapid_drain.sh` oracle, transaction and replay checks
passed O0/O2.

## Next discriminating comparison

Compare the upstream water supply and accepted macro state, with
rapid outflow split into potential, capacity cap and accepted outflow.
Export the lower-boundary head, bottom matrix head and conductivity,
main-domain water stock and level, and available volume above the
drain from a native V9 replay through March 30 to April 2. Compare
these at matched times against the B0 trace, and evaluate both rapid
laws on an identical saved state. This separates different input
state from different rate/limiter behavior. The simultaneous excess
bottom inflow warrants investigation but the window budgets alone
do not establish its direction of causality.
