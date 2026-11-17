# Original young-water fixed irrigation and age

**Implementation contract; qualification and admission pending.** Baseline is
canonical17834a639, after the verified PR1711/1712 age admission. Historical
completion remains PARTIAL and whole scientific equivalence NOT_QUALIFIED.

Extend the original SWSOLU2 adapter to fixed young-water irrigation, preserving
the original sprinkler, surface and distributed subsurface water owners. The
age boundary is explicitly zero days, consistent with the original age model's
zero-input boundary contract. Nonzero IRCONC in this bounded route is refused
by the actual original-reader extension; it is not interpreted as chemical mass
or silently discarded. More general age-valued inflows remain separate work.

Reuse the accepted soil-age, surface-age and effluent providers without changing
their equations or interfaces. Subsurface zero-age water dilutes concentration
through the actual changed soil water content; its external age amount is zero.
There is no fabricated age amount at the subsurface water source. Existing
midpoint water-content age production and evaporation retention policies remain
explicit and unchanged. Actual source/reference ledgers must establish this
composition before qualification.

The already complete original irrigation and crop context is part of the managed
S5AGE002 stream. Add no persistent fields or codec version for this input-only
extension. Real active own restarts, external discard/recovery, foreign-input
refusal and independent origins must prove preservation. No old checkpoint is
rebound to the extended source or different input.

Select local O0/O2 short active native controls first. Then select complete
sprinkler/surface/subsurface-point/subsurface-interval periods with initial100day
water, corresponding unchanged corrected-original reference executions and
Windows/Ubuntu native windows. Compare file/inline input paths over an active
prefix with the real generated/provider closure and complete native payload.
Initial0day controls remain separately labeled. Preserve the admitted inactive
age and age-off routes through exact emitted closure/native comparisons.

Water retains1e-10cm and chemical mass1e-10mg/cm2. Age retains the already accepted
8192*epsilon*max(1,actual inventory,actual age fluxes) cm day bound. No clipping,
fitted tolerance, copied physical equation, active macropore execution, new
solver or broad performance/F-CI campaign is selected.
