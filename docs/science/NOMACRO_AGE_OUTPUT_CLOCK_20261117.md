# Original age subdaily output clock and annual-only schedule

**Implementation contract; no qualification or admission yet.**
Baseline is actual canonicalb6dc588ef after PR1717/1718 schedule004 admission.
The actual metadata parents/tree and detached root owner passed, in107.24seconds.
Historical closure remains PARTIAL, whole science NOT_QUALIFIED and RC3 unchanged.

First execute the unchanged public baseline for NPRINTDAY2/3, annual-only
PERIOD0/SWMONTH0/SWODAT0, and representative omission of inactive monthly
selectors. Inspect actual primary/age file cadences and interval resets; do not
assume every original file is written at every water output time.

Separate the original output epoch from the later physical TSTART used by a cold
restart. Original TimeControl uses TSTART in its output trigger and two print-event
cap expressions. Preserve their operation order and global print counter, using
the bound original output epoch for those three output expressions only. Physical
TSTART, original numerical-policy/event logic and all physical age/water equations
remain unchanged. Select nonbinary NPRINTDAY3 as well as2, because counter-origin
reassociation can change floating-point event caps at a cold restart.

Reuse the literal admitted regular003/monthly004 renderers, complete defined
calendar state and actual-increment receipt provider. A separate clock adapter
may specialize print-counter/flag domains and select annual-only output. Use a
distinct S5AGE005 with strict old-format refusal; do not convert or rebind old
checkpoints. Test complete native/output equality, not only age offsets. Keep
the prior helpers, process providers and ordinary routes literal.

Monthly ReadSwap does not read inactive PERIOD/SWRES/SWODAT entries. Correct the
generic preflight branch that can demand PERIOD when SWMONTH1 and SWODAT0 remain
present, and qualify actual reader/native behavior for omitted inactive entries.
Do not synthesize missing active entries or rewrite output dates or frequency.

Local O0/O2 actual baseline and short clock/state controls precede complete model,
month/year/crop/terminal continuation, discard/replay/recovery, instance isolation,
invalid native/input controls and selected Windows/Ubuntu qualification. Existing
daily002, regular003, monthly/explicit004 and age-off routes require exact emitted,
provider/input and targeted physical/output/native preservation. Inherit unchanged
component/reference closures only with explicit source/executable identity.

Water remains1e-10cm; chemical mass remains1e-10mg/cm2. Age retains the accepted
8192*epsilon*max(1,actual inventory,actual fluxes) cm day policy. Preserve the
original-water and age-profile limitations; qualify any newly demonstrated
output defect separately. No active macro, snow/aquifer-age, source-valued age
forcing, new solver, general MODFLOW or performance campaign is selected here.
