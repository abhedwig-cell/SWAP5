# F-WOF-EXT01: actual PCSE direct restart dependency inventory (2026-10-17)

Research-only finding, **not direct restart admission**.

At PCSE research commit `1ba81d4abdf26a8ad8bf0b33b424864d0fcaabd9`, targeted [Actions 39060824746](https://github.com/abhedwig-cell/pcse/actions/runs/39060824746) job `117478239940` completed SUCCESS. Test instantiates **real** crop-only PCSE-WOFOST81 engines twice at each day 10, 30, 45 and compares their reproducible component/trait inventory. Corresponding date and timer day counters are consistent with 11, 31 and 46 output observations.

The actual crop has stateful components beyond the leaf codec: phenology (DVS, STAGE, TSUM, TSUME, relevant dates), allocation, root, stem, storage-organ, crop N and leaf cohorts. The rate-state layer includes current leaf growth, age, death and N stress, transpiration, root/stem growth, phenology and crop N rates. The engine also retains timer current_date/day_counter/first_call, saved outputs, agromanagement, kiosk registrations/values and dispatcher callbacks. These cannot be substituted with only saved LAI/DVS and leaf-cohort arrays.

**PASS:** deterministic introspection of active continuation dependency surface; demonstrates that a fresh day-zero engine is not a day-30 checkpoint. **NOT TESTED/PASSED:** applying state from a stored image into a fresh engine, direct continuation without historical replay, full state codec, detached dispatch/signal registration, accepted event atomicity or exact crop transaction restore.

The next meaningful implementation gate is a versioned *complete crop continuation* format that can be loaded into a new engine without replay and then match 60-day crop observables AND internal continuation state. Any partial codec must continue to fail closed. Preserve the existing production route and previous replay/Fortran scientific evidence.
