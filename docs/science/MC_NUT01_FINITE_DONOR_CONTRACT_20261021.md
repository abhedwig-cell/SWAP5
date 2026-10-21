# MC-NUT01 finite-donor negative aggregate

Status: bounded ADMITTED through PR1350 at canonical
`30be55796107ea05d40aac0ea182f2218613af8b`. Baseline canonical
`437d96ff51ac8a5825b605caf788661848c88be5`. Owner: MC-NUT01.
The existing HIST-COMPLETE record remains the recovery/admission authority.

## Corrected reference and donor

The [isolated reference contract](https://github.com/abhedwig-cell/SWAP5/blob/work/nut-negative-reference-20261021/reference/swap-4.3.1/patches/SWAP-020/CONTRACT.md)
defines the finite aggregated soil-N donor, including original linear NH4
sorption. This bounded corrected-reference decision retains the historical
aggregate convention chosen by the programme owner. It does not give pond runoff
the soil concentration or add a pond-N inventory.

Original complete-caller O0/O2 executes14 native models and120 daily N steps.
Independent unrounded form and whole-N books give maximum whole-N residual
2.6020852139652106e-18kg/m2, relative9.173895969097472e-15. Eighty valid and four
invalid direct inputs per optimization cover all five analytical classes,
sorption, empty/depleted/ample donors and continuing sources. An independent
numerical ODE agrees within4.73e-15 in the observed fields. These are completed
local reference observations, sealed in the existing work-unit record. Published B1 snapshots
remain immutable; no unrestricted B1.13 is implied.

## Existing production interfaces

The existing transport module adds a bounded evaluation procedure. Existing
mineral/reactive owners, crop fallow entrypoint and direct joint application
accept an additive optional `finite_donor_top` argument, false by default. It
requires explicit negative `historical_top_water` and the existing atmospheric
opt-in at the joint boundary. The joint crop must be retired, without pending
residues or root extraction. Active demand and immobilisation are excluded.

The routine obtains exhaustion time from the analytical trajectory. Its
concentration integral covers the actual pre-exhaustion duration. Continuing
nonnegative production and positive boundary loading supply the constrained
extraction after exhaustion. Actual extraction enters external output; nominal
requested extraction and unmet amounts have separate per-form receipts. Unmet
extraction is a diagnostic, never a stock, source, debt or deferred removal.

Nitrification is debited from NH4 and credited to NO3 once. Denitrification and
transported outflow remain external sinks. Mineralisation cancels between
organic and mineral inventories. Units:kgN/m2, kgN/m3 and m/day.

No physical state, parameter vector, restart schema or solver interface is
added. The optional choice is interval forcing semantics, supplied again after
restart. Cumulative diagnostic receipts belong to the application's test journal
and are qualified separately from native physical restart. Existing absent/false
argument trajectories retain their calculations.

## Qualification and limits

The direct mineral owner O0/O2 gate passes against the corrected reference,
including explicit default rejection, independently known emptying, failure
atomicity and opaque reconstruction. Stable qualification selects the complete
existing HIST physical matrix because active/fallow chemistry consumers compile
the changed providers. All fourteen predecessor endpoints, previous transition
restarts and existing assertions remain requirements.

Additional actual Reference Richards/retired-crop/Soil-N runs use low/high
mineral stocks, wet/drying water steps, source pulses, negative extraction,
original reactions, whole-N closure, hydraulic/chemical rejection and fresh
process continuation after days1/6. The journal contains cumulative per-form
requested/actual/unmet extraction, internal conversions, gas loss and budgets.
The existing retained owner remains required. Full moving F-CI follows actual
compiled dependencies; no new RossFast/aquifer or SOL/PERF production changes.

Automatic persistent-pond/snow binding, active-crop allocation among negative
sinks, immobilisation and near-degenerate analytical coefficients remain
unsupported. Explicit historical aggregate forcing is not automatic pond
chemistry or full migration. Existing common water, solute, age, restart and
numerical contracts are read-only. Affected invariants:3,7,13,21,23,25,26,30.

## Fresh reproduction

Use separate, initially absent result directories; GNU Fortran13 and SciPy are
required. Run from the repository root with unlimited stack. The retained runner
uses its original literal hash, not the finite-donor reference's generated code.

```bash
ulimit -s unlimited
export OMP_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1
python -B reference/swap-4.3.1/patches/SWAP-020/run.py --output /tmp/nut020-reference
python -B integration/audits/run_nut_negative.py --reference-result /tmp/nut020-reference --output /tmp/nut020-production
REPRODUCTIVE_PROCESS_RESULT_DIR=/tmp/nut020-literal python -B tests/nut-crop/run_reproductive_process.py
CROP_N_RESULT_DIR=/tmp/nut020-retained REPRODUCTIVE_LITERAL_FILE=/tmp/nut020-literal/literal.f90 REPRODUCTIVE_LITERAL_SHA256=b64c01e310927bad85f40a467ac356c300c4f72a062d60cc113927f68ac76c14 python -B tests/nut-crop/run_b112_retained_joint.py
python -B integration/audits/verify_nut_negative.py
python -B integration/audits/verify_nut_negative.py --self-test
```

The last two commands independently verify the versioned raw capsule and current
source; they do not execute new numerical runs. Fresh qualification additionally
compares the newly generated raw results with the same owner assertions. Do not
use `--reuse-physical` across source/compiler/object changes. The recorded local
compiler was GNU13.3; custom installations must supply their own FC/PATH and
link search paths. No compiler packages or generated binaries are production.
