# Rejected coherent macropore candidate, 12 November 2026

Status: reproducible short-probe blocker, **not admitted**. Canonical base
`a22754decc0ec4e69304d1495c48bae7cdcdabec` and its complete application results
remain unchanged. No full-period trajectory was rerun. This branch is an isolated
research implementation for review, not a request to merge failing model code.

The candidate calls original MACROPORE task3 once per residual candidate and
consumes that candidate's original analytic derivative in the Jacobian. Original
MACRORATE task2 computes both rates and derivatives. The candidate removes the
dated macro-refresh and pond-feedback triggers and enables existing mass retry
from the first day. Original MACROSTATE, numerical/physical tolerances, forcing,
daily kernel and rollback code are unchanged. Public build defaults do not import
or activate this helper. Retained original objects, generated sources, compiler,
commands, inputs and executables have distinct build/checkpoint identities.

## Decision and evidence

The unchanged same-machine O2 baseline completes days1–4 in **2.842s**. The new
policy accepts days1–3 but does not return day4 within the short cap. Its own
day2 checkpoint restores stocks/pressure exactly and reproduces day3 stocks,
pressure and external flux exactly; day4 again hits the **20.013s** model cap.
The same macro policy with the original early-budget schedule also stops on
day4 at **20.014s**. Thus early activation of mass retry alone does not explain
the failure. These are censored completion times, not measured full runtimes.
The first fresh controller's elapsed output was not retained; its three accepted
day diagnostics and pending fourth request are retained. The two later measured
probes establish the reproducible blocker independently.

Maximum reported accepted fresh guard residual:6.216544880776115e-7cm, below the
unchanged1e-6cm limit. Own replay day3 independent residual:-1.023538684452141e-7cm.
No claim is made for day4 balance, complete2→4 restart, complete rollback,
scientific equivalence or performance portability. O0/Linux/admission campaigns
were not selected after this minimal O2 failure. No tolerance was increased.
The diagnostic that retains the early-budget calendar is explicitly named and
does not meet the target generic policy contract.

`GENERIC_MACRO_POLICY_RESULT_20261112.json` records the comparison. The adjacent
`generic-macro-policy-evidence.zip` retains generated Fortran, exact builds/link
commands, original candidate generator, raw host/donor logs, native accepted
checkpoints, replay receipts and baseline result. Original native/auxiliary
checkpoint packages are never rebound to another build. The runner's
`initial_state_exact` field is meaningful as a receipt comparison only in its
checkpoint mode; fresh runs have no prior receipt to compare.

## Reproduction

Use the preserved Windows original-block capsule
`hybrid-hupsel-windows-20261111.tar.xz`, SHA256
`678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1`.
Extract it to a fresh directory `$base`; it supplies `reference` and `andelst-O2`.
Use its exact GNU16.2 compiler and providers, verified by the helper. Put
`C:\msys64\ucrt64\bin` on PATH. From the repository root, set `$probe` to a fresh
output directory, create that parent, then build:

```powershell
$env:PYTHONPATH = "$PWD/app/hybrid_water"
python -B -c "from generic_macro_policy import build_bundle; build_bundle(r'$base/andelst-O2', r'$base/reference', r'$probe/build')"
python -B research/hybrid-water01/probe_generic_macro_restart.py --bundle "$probe/build" --reference "$base/reference" --output "$probe/fresh" --cap-seconds 20
python -B research/hybrid-water01/probe_generic_macro_restart.py --bundle "$probe/build" --reference "$base/reference" --checkpoint "$probe/fresh/accepted-column-1-day-2.zip" --output "$probe/restart" --cap-seconds 20
```

Exit2 with `MODEL_CAP_REACHED` is the retained failed result, not PASS. Results are
written after every accepted day and again after timeout; owned workers are
killed and reaped. To isolate early-budget activation, build a separate directory
with `retain_early_budget_schedule=True` and run its fresh probe. For the unchanged
control, use `$base/andelst-O2` directly as `--bundle` in a fresh output directory.
All runs retain the host's unchanged daily1e-6cm acceptance gate.

## Next implementation decision

Do not extend time caps or run481 days with this candidate. Prior provisional
convergence-refresh attempts also failed and must not be repeated. Reassess the
larger original coupled nonlinear/macropore accepted-step block rather than add
more calendar patches. The short gate for a successor is termination through
day4 at unchanged tolerance, then exact own2→4 and rejected-state rollback,
before selecting a late retained-state event. Non-smooth macro rates versus
suitability of the original analytic Jacobian remain unseparated hypotheses.

Functional coverage stays three previously admitted complete applications.
Reliability gained here is exact own2→3 plus a repeatable failure boundary;
whole generic-macro reliability remains open. Development yield is a rejected
replacement using two20s distinguishing/recovery probes and a2.842s control,
with zero full runs and no new reference family.
