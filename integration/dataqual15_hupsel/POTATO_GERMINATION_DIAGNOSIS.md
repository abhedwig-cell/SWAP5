# Original Hupsel potato emergence diagnosis

The instrumented original SWAP4.3.1 application completed all1096 days. Its1097 CSV data rows and header, after the generated-at metadata, are byte-identical to the existing original high-precision scalar reference. Added Fortran statements write diagnostic fields only; no model-state assignment or physical input is changed. The original standalone selected source is used because its existing preprocessing removes inactive Intel multiswap branches.

`tests/dataqual15_hupsel/diagnose_donor_germination.py` recompiles only the original cropdevelopment module and links the existing original application provider objects. The unmodified1096-day original inputs come from `dq15-hupsel-reference-highprec-scalar`. gfortran13 O2 compile/link and complete original model execution took2.54s; normal original exit100 and `swap.ok` were observed.

The native comparison is the existing diagnostic continuation from the qualified old494-day prefix, `dq15-hupsel-potato-original-diag-c-O2/crop.csv`. It is not evidence for the subsequently integrated reactive-prefix candidate. No extra native historical model day is claimed by this diagnosis.

## Calendar reconciliation

SWAP5 accepted clock522 is the end of June6; the following morning clock522 is June7. Its first active crop output is labelled523. Original SWAP4.3.1 germination crosses255 on June7, then cropemergence promotes it on June8, original output day524. The active-to-active difference is therefore **one day**, not two. Comparing a native morning clock with an original end-of-day row produces the misleading two-day difference.

Both routes start germination on May10. Original source order is TimeControl(2), Meteo(2), croprotation(2), before the day's water calculation. Original `cropemergence` first checks previous-day flags, then evaluates this day's germination. Native `day_begin` checks previously committed germination and samples accepted morning pressure; `day_end` commits this day's temperature-sum increment. The phase timing agrees for this comparison.

## Measured original fields and existing native sums

| Date | Native output day | Original Havg cm | Original sum | Native sum | Difference |
| --- | ---: | ---: | ---: | ---: | ---: |
| May10 |495|-68.0824340443|7.45862113856|7.46034961739|0.00172847883|
| May17 |502|-65.9086178901|52.9110144988|53.0934531256|0.18243862682|
| May21 |506|-1|81.0891545977|82.1657805910|1.07662599331|
| May30 |515|-65.0241002488|164.858529471|166.519286116|1.66075664505|
| June4 |520|-64.3923104679|230.191114425|239.340178742|9.14906431683|
| June6 |522|-56.9512943324|252.206598715|264.363873310|12.1572745957|
| June7 |523|-66.0312899856|265.324296785|already germinated|—|

Literal original parameters are TSUMEMEOPT255, TBASEM3, TEFFMX18, HDRYGERM−500cm, HWETGERM−100cm and AGERM203. Both existing source routines implement the same pF-weighted pressure sampler and the same wet/dry germination law. Under identical weather, inverting native accepted sum increments predicts Havg−3.0044608493cm on May21 and−80.2339517597cm on June6; the former original donor average is clipped−1cm. These inferred native heads are **not measurements** and must be checked against the read-only native pressure output before conclusively attributing the difference to hydraulic feedback. Native pressure/Tav logging has been requested from the owner of the ongoing actual continuation.

This establishes the calendar correction and original donor observations. It does not establish full scientific equivalence, identify the upstream water-state cause, or authorize a solver/physics change to force equal emergence dates.

## Concrete original-input binding defect found

The existing actual native `diag-d` budgets show matching rainfall to roundoff, but excessive soil evaporation: native minus original EACT is+0.3188740261cm on May30,+0.2604880600cm on June2,+0.2661520741cm on June4 and+0.2107671524cm on June6. Native total water storage differs by−1.3084023047cm on June6. The rapid later germination is therefore accompanied by materially drier actual hydraulic states.

The combined Rutter/Black backend explicitly selects wetting resets using `net_rain + net_surface_irrigation > forcing%black_evaporation%significant_wetting_cm`. That field defaults to0; the application never assigned it from the already parsed original `black_rsigni=0.5`. Earlier standalone Black forcing used a separately bound Boolean and did not expose this omission. Under composition, every positive small rain therefore resets Black drying. In the observed defective run, EACT equals EPOT on May30 (rain0.08cm), June2 (0.34), June3 (0.07), June4/5 (0.25); the donor correctly retains the dry-period reduction for these subthreshold rains.

The parent and crop owner have been notified to bind the existing field to the original RSIGNI and rerun the actual continuation from494. This is an identified input-binding implementation defect, requiring no new physical law or solver tolerance. Its quantitative contribution remains pending the corrected native trajectory; measured next-run pressure/Tav will distinguish any residual discrepancy.

## Corrected actual continuation, measured native pressure

The crop owner bound the original0.5cm/day threshold in source `fac0d3d`, then executed the original native continuation again (`dq15-hupsel-potato-original-diag-e-O2`, compiled bundle `dq15-hupsel-rotation-current-i-O2`). All29 actual germination days May10–June7 now have measured native pressure and Tav. Tav is identical to the donor on every day. Re-evaluating the source germination increment using each route's own measured pressure and the literal original parameters gives maximum residual2.67e−14°Cd for native and1.43e−14°Cd for donor, i.e. operation-order roundoff.

On June6, corrected native Havg is−56.9515911538cm versus original−56.9512943324cm; native sum is252.433168267 versus original252.206598715 (difference0.226569553, previously12.157274596). On June7, native sum265.555656931 and original265.324296785 both cross255. The corrected native first positive LAI appears on output day524, June8, exactly the original emergence date. This confirms that the missing Black threshold binding caused the premature emergence in the prior composed route. The small residual accumulated sum difference follows remaining measured hydraulic differences, especially near saturation; it is not a weather or germination increment-law error.

The corrected diagnostic continuation completed through537 before its next failure, return1 in43.32s, with maximum water residual1.77e−14cm and solute residual1.09e−13mg/cm². This is a diagnostic continuation from the older494-day prefix, not same-build restart qualification. The owner is independently executing the current full original project from day1. No closure beyond the actual achieved537-day diagnostic is claimed here. The archived source-bound `RESULT.json` and raw crop/budget series retain the subsequent failure and actual observations.

`compare_germination_trajectory.py` produces the measured29-day table and manifest directly from the original and native observation files, reading all germination parameters from the original potato input. It does not introduce a synthetic forcing or alternative physical calculation into either application.
