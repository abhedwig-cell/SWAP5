# MC-CROP01: historical germination preflight arithmetic order

Canonical base: `92815e6783741bc16ee3cf39c4a6a74dde294f53`.

## Source and discrepancy

Retained exact B1.11 `reference/swap-4.3.1/b1_11_frost_source/SWAP/MOD_cropdevelopment.f90`, Git blob `6f587310c7b9e9ba5e79f22d988bddd5feead133`, germination task 3 lines 755-766 evaluates `(tsumemeopt / tsumemesub) * (tav - tbasem)` (or effective max-temperature analogue). Existing current `src/crop/mod_crop_germination_preflight.f90` instead evaluates `increment*optimal_sum/needed_sum` when `needed_sum>=0.1`. Associativity differs under floating point. A SWGERM=2 dry-head witness uses `optimal_sum=10`, `water_response_a=7.3`, `dry_head=-1000`, `wet_head=-10`, `average_pressure_head=-10000`, `base_temperature=5.3`, `air_temperature=13.27`, `max_effective_temperature=20`. Its two expression orders yield different binary64 results.

## Bounded repair

Change only the multiplication order for the existing positive effective-`needed_sum` branch in the existing read-only crop germination preflight; preserve all state and caller interfaces. Add `tests/fmig431/test_crop_b111_preflight_source_order.f90` and its O0/O2 runner, which require exact bitwise source-expression behavior and also verify that the old expression is distinguishable. There is no weather-origin certificate, no event publication, no F-KT state mutation, and no new shared source owner.

## Evidence ceiling and next action

Local standalone regression on reconstructed equivalent source at gfortran O0/O2: new source-order witness PASS and existing five-case preflight PASS, including `-fcheck=all -ffpe-trap=invalid,zero,overflow -Werror`. This is preliminary **not exact-Git-blob** local evidence. The source, test and runner are persisted remotely; exact Git-blob verification and full integration F-CI/MC-CROP owner preservation must still pass before admission. No manually dispatched Actions.

Status: IMPLEMENTED YES; PERSISTED YES; PRELIMINARY TESTED YES; EXACT POSTIMAGE QUALIFIED NO; PRESERVED NO; CANONICALLY_ADMITTED NO.
