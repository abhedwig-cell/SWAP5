# HYDRO-MEMORY DYN02-VIEW01 preregistration

DYN02 run 35460379501 failed during first-window recomposition before MODFLOW execution. Source reconciliation shows a narrow type-admission mismatch.

`fmr_b110_temporal_indicator_state_t` extends `fmr_b110_physical_state_t`, but `fmr_build_committed_process_hydraulic_view` currently uses an exact `TYPE IS (fmr_b110_physical_state_t)` branch. F-CI31 therefore cannot obtain the hydraulic view from the temporal-history carrier required by the governed Reference-Richards route.

The repair is deliberately narrow. It may add an explicit `TYPE IS (fmr_b110_temporal_indicator_state_t)` branch and extract only the inherited hydraulic fields. It must **not** replace the selector by a broad `CLASS IS`, because that would also admit unrelated physical-state extensions such as fixed-weir and evaporation continuation carriers without authority.

Qualification requires bit-identical hydraulic views from a plain physical carrier and a temporal-history carrier initialized from the same physical state, no committed-state mutation, rejection of an unrelated transaction carrier, and O0/O2 identity.

No DYN02 scientific or numerical criterion is changed.
