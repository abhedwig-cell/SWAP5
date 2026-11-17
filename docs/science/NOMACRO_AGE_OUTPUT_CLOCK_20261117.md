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

Original TimeControl1 runs before the native calendar is applied. Its counter is
still local at that point, so initialization must use physical TSTART while
retaining the persisted DT proposal. Activate the bound global output epoch for
the dynamic tasks after restoration; do not cap DT against a restored epoch and
an unrestored counter. This initialization boundary is part of the clock owner.

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

The NP2 complete pilot rejected day364: independent residual
1.0023688476468173e-10cm, while the accumulated per-step hydraulic guard was
-9.987989763998158e-11cm. These are different floating-point ledgers. The new
subdaily005 owner therefore additionally projects its actual daily receipt at
terminal Newton convergence. It clones the receipt, extracts the original
Integral increment expressions/branches from its pinned source, and uses the
original Watstor soil and Integral canopy operations. No accepted frame or
physical state changes. The existing hydraulic and external strict guards stay
active and unchanged; a failed projected receipt requests another original
Newton iteration. This is an additional acceptance condition for this new scope,
not a tolerance relaxation or water correction.

Both NP3 full trajectories committed1096days, then the validator refused an
original primary timestamp such as07:59:60. Original Swap CSV delegates to TTUTIL
dtdpst; its formatter rounds seconds without carrying. Retain original bytes,
interpret the emitted components with an explicit60-second carry only in the
validator, and report the inherited formatting limitation. Require exact file
bytes across restarts. This does not establish valid ISO timestamp formatting.
Annual371day O0/O2 pilots and four exact restart windows each passed.

The terminal-only trial condition still rejected day364. The original minimum-step
nonconvergence continuation bypassed the convergence branch on that day; the
accepted-terminal diagnostic was absent. Therefore project the actual receipt at
each candidate and apply the same elapsed-day-scaled1e-10 bound alongside the
existing per-step hydraulic guard. Prevent accumulated ledger error before the
saturated terminal/minimum step, instead of relying on a terminal polish. Original
minimum-step behavior and the external strict refusal remain unchanged.

All16Windows short/full005 profiles and six native/transaction control contexts
passed. Original reference execution then exposed a separate cadence discrepancy:
NP3 plain O0 emits3290primary rows instead of3289, with an extra2003-01-03
00:00:17 row. All nominal timestamps remain present and strictly ordered. Record
this actual original cadence as NOT_QUALIFIED, independently from the already
retained seconds60 formatting limitation and water/scientific limitations. Do not
invent a missing migrated event or alter005 timestamps to match this extra row.
The three completed exact-input/original-executable reference executions are
reused with their per-file hashes; the fourth validator failure is retained.
