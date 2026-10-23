# MC-NUT01 exact zero receiving-pool turnover rates

The bounded successor implements the regular organic ODE limit at exactly
`ratecon_bio = ratecon_hum = 0`. Fresh organic matter can still decay and transfer
material into stable biomass and humus. The all-zero organic-rate case retains
all pools exactly and produces zero organic carbon dissimilation and organic N
transfer. This does not change competition or exhaustion allocation.

The owning contract `integration/mc-nut01/zero_pool_rates/CONTRACT.md` and
`integration/mc-nut01/zero_pool_rates/STATUS.json` bind the two production modules,
source preimages, assertions and immutable raw capsule. The numerical helper
uses the continuous loss and interval-average limits, including exact zero and
cancellation-safe small arguments. Nonzero-rate production execution is retained.

## Qualification

Each O0/O2 direct execution covers168 formerly rejected zero-pool cases against
an independent seven-state DOP853 integration and carbon balance. Maximum error
is1.78e-14; maximum carbon residual is5.56e-16. Twenty-four nonzero cases remain
byte exact to the canonical preimage. Thirteen helper boundary/invalid inputs per
optimization include zero, tiny rates, the series boundary, large rates, NaN and
infinity; four invalid production inputs remain rejected.

The complete original HIST assertion recipe runs against current providers:
48 changed/transitive compiles,606 source/flags/module-closure-verified object
reuses,78 fresh native processes and56 fresh process restarts. Every historical
result is exact to the previous admitted result. One obsolete rejection fixture
used both rates zero; it now uses only biomass rate zero with positive humus
rate. Every original rejection and rollback assertion remains unchanged. Its
original failure and raw diagnostic are retained rather than labelled PASS.

Ten actual eight-day water/crop/N runs and20 separate process restarts cover the
three incumbent profiles plus zero receiving-pool rates with net immobilisation
and the all-zero organic-rate profile. All three incumbent profiles are byte
exact. Native persistent states survive exhaustion, stale and water rejection
without changes; restart endpoints and journals are byte exact at both
optimizations. Two prior-production probes reject the new profile atomically.

The predecessor's52 corruption controls remain unchanged through explicit
historical reads for the two organic modules and the obsolete fixture. Fresh
current evidence has separate source, raw result, endpoint, restart and rollback
controls. Historical binary receipts are never called current executions.

## Limits

Only both exactly zero receiving-pool rates are added. Single-zero receiving
rates, other eigenvalue resonances and exhausting selected mineral solutions
retain their existing unsupported guards. Automatic snow/persistent surface N,
general historical activation and full MC-NUT01 closure remain open. No master
row or frozen Status-A denominator is promoted. The concurrent PR1401 transport
research has no overlapping production or executed inputs; its source-bound
owner is verified on the combined tree.
