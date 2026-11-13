# Daily nominal step and Hupsel pressure reproducibility

## Proposed numerical successor, 13 November 2026

Owner: `integration/f-ci/HUPSEL_PRESSURE_STABILITY01.json`.
PR1672 arithmetic baseline remains valid for its recorded sources. The owner
explicitly reopened the residual pressure investigation and requires the
half-hour resumption safety net to remain active while the end goal is open.

The matched GNU15 full record shows 12.203962749731431 cm maximum Hupsel pressure
spread at day636/node8. The first large amplification precedes oxygen584.
Read-only native traces through567 preserve every original public head, stock,
flow and uptake record on both platforms (run43411875844). The last-step
remainder difference grows from about6.33e-15day at562 to2.57e-5day at567 before
the first divergent iteration count. Original TimeControl(2) inherits that
clipped remainder as the next day's nominal step. The integer number of steps
and repeated event clipping amplify its phase.

Private EOD-only separation is informative but not selected: generic day1
activation reduces day636 spread to0.4158157500842776cm, but leaves a1.2509267cm
maximum through637 and requires extra transient controller state. The window562
variant is only a causal discriminator, never a configuration-specific policy.
Run43413278227 completed all six native637 models with unchanged guards; its
final harness incorrectly assumed200 rather than Hupsel's34 compartments.
That failure is preserved; corrected analysis reused existing frames without
rerunning models and does not relabel the CI run as successful.

## Selected implementation and invariant boundary

The simpler `configured-dtmax-daily-v1` policy starts each day from the existing
configured DTMAX, before the original event cap. Every original event limit,
Newton/convergence criterion, NUMBIT feedback, rejected-step reduction and
physical process remains. DTMIN/DTMAX and all balance/scientific tolerances are
unchanged. Original input bytes are not edited. This intentionally changes the
numerical daily seed, not a physical option or its input selector.

Only the generated no-macro TimeControl(2) seed changes. The original source
provider, original reference default and active-macro builds retain their code.
No new saved state or codec is required: the deterministic daily seed is applied
by the same original start-of-day call for cold and own native continuation.
The source/build/checkpoint binding names the policy and generated source; old
or private checkpoints are never rebound. Unknown policy builds refuse before
output. The selected implementation must prove its actual day-state/rollback
contracts; it cannot inherit a private observation as production qualification.

Matched GNU15 private run43414625320 gives day636 pressure spread
6.906475391588174e-12cm and maximum1.7962520360015333e-11cm through637; theta spread
is3.219646771412954e-15 and oxygen584 spread6.938893903907228e-18cm. Native models
cost1.90s Windows and1.42s Ubuntu. All original1e-10 water/solute guards pass.
The real SWAP5 daily host on the laptop separately passes exact365-to637 own
physical continuation and terminal native/auxiliary bytes for the private
candidate. These are discriminators, not full application admission.

## Required qualification

Fresh registered Grassgrowth1827/Hupsel1096/SaltFarm1461 complete O2 periods,
kernel O0 short controls (original donor O2), exact full own continuations,
unchanged water/kernel/solute guards, twelve build/toolchain/policy/source refusals and
six external accept/discard/instance/restart controls are selected Windows/Linux
and laptop. The generic numerical seed also affects experimental cases: select
current canonical blocksA/B/C in independent Ubuntu jobs, preserving original
failed comparisons and any actual refused trajectory. No moving full F-CI,
active macro or retired highest-low-air campaign is selected.

There is no new fitted pressure acceptance tolerance. Cross-platform spreads
are measured; original oxygen reference FAILs and independent reference limits
remain separate. Whole-model scientific equivalence and unmeasured physical
energy are not promoted by reproducibility. Frozen RC1 is unchanged. Actual
admission requires a PR and verified canonical postimage. The broader owner
end goal stays open until its actual remaining criteria are resolved.

The derived undrained Hupsel case remains a full-period FAIL. With the selected
policy it accepts211 days and refuses212 at independent1.0015015206032984e-10cm
(kernel -1.0014078455355957e-10cm), beyond the unchanged1e-10cm guard. The earlier
canonical day51 refusal is retained as historical evidence, not overwritten.
The current preservation fixture selects exact210-to212 own refusal/rollback;
no rejected day or terminal checkpoint may be published. This is distinct from
the complete original drained Hupsel1096 application and is not silently fixed.

## Qualification boundary after actual process-family findings

The first broad candidate run43416327365 passes both complete public cohorts
and basic options but fails the other two experimental jobs. Under the new
seed, undrained Hupsel refuses117 on Ubuntu (212 on the laptop), and the
previously complete snow+hysteresis case refuses26 because kernel water residual
-1.00006225522975e-10cm exceeds1e-10 (independent9.999651280623301e-11cm).
These actual findings are preserved, not relabelled as passing tests.

The numerical execution policy is therefore explicit project metadata, separate
from physical selectors. Registered user-release profiles select
`configured-dtmax-daily-v1`. General experimental projects keep their already
qualified `original-adaptive-day-seed-v1` default. An explicit experimental policy
option may select the new seed as a research execution, whose observed failures
remain failures. There is no automatic fallback, input-option suppression,
extra physics kernel or changed guard. Both policies use the same original
Richards/process implementation and differ only in the daily initial proposal.
The selected project policy and generator source are bound in every build and
checkpoint, and a different policy is refused before output. This boundary
preserves current process-family capability while fixing the original named
Hupsel application; it does not assert universal qualification of the new
numerical policy for every option mix.
