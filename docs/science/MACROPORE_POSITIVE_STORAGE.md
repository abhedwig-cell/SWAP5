# Positive macropore storage preservation

## Canonically admitted production correction

On baseline `db42f99e2de9cae43dfe04bbf291e8e214edd6f7`, the standard storage
normalizer applies a `1e-12 cm` packing quantum to ordinary domains. Positive
totals below that quantum become zero; nearly full cells can acquire water when
the quantum rounds their remaining stock upward. The earlier tapered-tip route
already avoids these operations for positive stocks.

The corrected normalizer uses that bounded bottom-up packing for every positive
stock and capacity. Each cell receives `min(remaining, capacity)`. Zero-capacity
tips below the water front retain the existing wet-wall convention; exactly empty
domains stay dry. No new parameter, persistent field, stream format or source
term is introduced. Mass, cell-flux, temporal and transaction acceptance limits
are unchanged. This corrects water loss or creation rather than reproducing the
old storage approximation.

The concrete witness occurs in the explicit joint Andelst research model at
43.33800000000041 to43.340000000000416, domain5 cell40. Both recorded cell stocks
are zero, yet its upper face carries `4.5278384241650544e-10 cm/day`, leaving a
`9.055676848341176e-13 cm` cell defect. The accepted-flux-trace guard correctly
refuses publication. Rutter preparation succeeds. A read-only replay with the
storage correction passes the unchanged cell and trace guards; its largest full
step cell defect falls to `4.4186876380135233e-17 cm`. This replay is not a
cross-executable restart qualification and leaves its diagnostic origin unchanged.

The real six-source component closure reproduces the baseline defect at O0/O2 and
passes with the correction, covering ordinary positive pockets, tapered tips,
small positive capacities, near-full cells, candidate construction, closed
terminal faces and negative-capacity refusal. The existing112-node/five-domain
original initialization driver also passes at O0/O2. Ordinary and explicit joint
day-one physical restart payloads are exact, with water residual
`1.1053441148489718e-15 cm`.

The [recovery and selection record](https://github.com/abhedwig-cell/SWAP5/blob/codex/andelst-empty-pocket-20261106/integration/dataqual15/EMPTY_POCKET_RECOVERY_20261106.json)
binds exact source hashes, raw negative and positive evidence and measured costs.
Reproduce the small contract with `python tests/dataqual15/run_empty_pocket_contract.py
--compiler <gfortran> --output <new-directory>`.

Full original-input continuation with the corrected contact research model is a
separate execution claim, recorded only after its terminal result. The storage
repair does not turn that contact law into historical equivalence, complete
original Andelst481 or qualify atmospheric/donor energy contributions.

## Admission and original-input continuation

PR1593 admits this bounded production correction at actual merge
`6545e21d12d23d7d22f53d7e2f20a43ad5276d61`, with parents
`db42f99e2de9cae43dfe04bbf291e8e214edd6f7` and
`1c1a5e50612fb6232b7e1962684be41f56a0e241`. Focused Linux O0/O2 contracts
and strict documentation pass. The corrected V2 original-input run then completes
65 days in700.372 seconds, with maximum daily water residual
`1.1061381684936018e-12 cm`. Its strict own day3-to4 continuation reproduces
all504 progress rows and the complete day4 checkpoint byte for byte.

The next failure is a distinct coupled groundwater/drainage transition at accepted
65.17299999999756, attempted65.17499999999755. Strict own day65 continuation
repeats all91 rows, including refusal, and the diagnostic committed state exactly.
This is not a storage-repair regression or a completed481-day result.
Authority: `integration/dataqual15/EMPTY_POCKET_RECOVERY_20261106.json` and
`integration/dataqual15/TRANSITION65_RECOVERY_20261106.json`.
