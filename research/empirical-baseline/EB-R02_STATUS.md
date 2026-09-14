# EB-R02 status: current-canonical forcing span observation

Decision: **CLOSED_EMPIRICAL_OBSERVATION_SLICE**

This status closes only EB-R02 inside the continuing `research/swap431-empirical-baseline` capability.

## Evidence identity

- final observation head: `78cde00a687c394622ba91c6267ead84f64606b4`
- capability canonical start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- historical F-MR23 tested head: `3965b15ad0432b46134513eb13ec02a17f7d6b17`
- current/historical-identical forcing binding blob: `8c679f911c9a82c498258224d83f5fce3cb09163`
- restricted reference-ET process blob: `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`
- GitHub Actions run: `34872273089`
- EB-R02 workflow job: `104070825783`
- EB-R01 regression job in same run: `104070825981`
- EB-R02 observation SHA-256: `87c027090a6f40eee46ab52a844b2c74936b2713eb782002fda10ab446230c12`
- historical F-MR23 output SHA-256 replayed on current canonical: `443f03b0fcc30a8e669c2db690eb94d2bd095606cbff11f75d82aa9cd88730d5`

## Results

All final gates passed:

- inherited F-MR23 binding blob identity: PASS
- restricted reference-ET process blob identity: PASS
- `-O0` versus `-O2` EB-R02 observation identity: PASS
- current-canonical replay of the historical F-MR23 output digest: PASS
- independent forcing-span anchor falsification: PASS
- EB-R01 regression in the same workflow run: PASS

Observed values are rates in cm/day; interval duration is in the canonical time coordinate used by the runtime.

| case | binding status | process status | duration | process called | result | PTRA | PEVA | EPOND |
| --- | ---: | ---: | ---: | :---: | :---: | ---: | ---: | ---: |
| contained_quarter | 0 | 0 | 0.25 | yes | yes | 0.33462 | 0.182 | 0.2184 |
| contained_late | 0 | 0 | 0.349999999999909051 | yes | yes | 0.33462 | 0.182 | 0.2184 |
| left_not_covered | 3 | 0 | 0.199999999999818101 | no | no | 0.0 | 0.0 | 0.0 |
| invalid_zero_span | 2 | 0 | 0.100000000000363798 | no | no | 0.0 | 0.0 | 0.0 |
| negative_et | 4 | 1 | 0.100000000000363798 | yes | no | 0.0 | 0.0 | 0.0 |
| nonemerged_cover | 0 | 0 | 0.199999999999818101 | yes | yes | 0.0 | 0.364 | 0.4368 |

## Empirical interpretation

Within this bounded forcing-span seam, a contained subinterval receives the same reference-ET rate regardless of subinterval duration. The binding does not silently integrate a daily rate over the requested interval.

Coverage and validity are fail-closed before process execution: an invalid forcing span or an interval outside the forcing span does not call the ET process. A negative reference-ET value passes the span checks, reaches the ET process, is rejected there, and is propagated as binding status `PROCESS_REJECTED` with no result.

The non-emerged case reproduces EB-R01 semantics: crop-specific transpiration factors are not used, PTRA is zero, while vegetation cover still partitions the soil and pond evaporation demand.

## Harness findings during qualification

Two red intermediate runs were diagnosed as harness issues rather than model discrepancies:

1. `mod_transaction_reference.f90` contains a pre-existing exact REAL equality comparison. The generic strict warning policy promoted that unrelated support warning to an error before EB-R02 executed. The final workflow keeps warnings enabled but uses `-Wno-error=compare-reals` only for that support dependency. Relevant forcing and ET modules remain under `-Werror`.
2. Direct subtraction of time coordinates near day 2700 produces the expected floating-point cancellation in durations such as `2700.3 - 2700.2`. The final independent check therefore uses a bounded tolerance of two ULPs at the time-coordinate scale. ET and flux outputs retain their separate strict numerical tolerance.

Neither harness change modifies production source or relaxes the forcing/ET semantic checks.

## Evidence inheritance

EB-R02 remains reusable only while these dependencies and semantics remain unchanged:

- `src/runtime/mod_fmr_reference_et_demand_binding.f90` blob `8c679f911c9a82c498258224d83f5fce3cb09163`;
- `src/process/mod_reference_et_demand_process.f90` blob `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`;
- the EB-R02 observer at final observation head `78cde00a687c394622ba91c6267ead84f64606b4`;
- forcing-span validation and coverage semantics represented by F-MR23.

A relevant dependency change requires re-observation. Unrelated changes do not invalidate this immutable evidence.

## Hard nonclaims

EB-R02 does not claim:

- full meteorological input acquisition or file parsing equivalence;
- complete effective-forcing selection across all serialized or MultiSWAP execution paths;
- equivalence to running the complete supplied SWAP 4.3.1 binary distribution;
- coverage of precipitation, interception, irrigation, snow or other meteorological transformations not represented by this reference-ET forcing span;
- any new production or scientific qualification.

## Next empirical slice

Continue on this same capability branch with current-canonical effective-forcing selection in the serialized runtime. Historical F-MR38/F-VQ55 evidence can guide the oracle, but must not be inherited wholesale because `mod_fmr_serialized_multiswap_runtime.f90` has changed since that qualification. EB-R03 therefore requires a true current-canonical replay and observation of selected forcing identity and values.
