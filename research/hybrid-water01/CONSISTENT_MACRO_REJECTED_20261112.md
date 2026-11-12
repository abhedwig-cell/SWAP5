# Consistent macro trial-state candidates rejected at the short prerequisite

Baseline canonical: `173a3e8e1c231108ddd048c593170f9096e5bf4a`, after PR1655.
The confirmed day438 cached/fresh coupled-residual discrepancy remains unresolved.
Two directed numerical repairs were implemented and actually compiled and run.
Neither passes the bounded fresh4 prerequisite. Neither is admissible modelcode.
The public builder and canonical physical model remain unchanged.

## Changes and invariant boundaries

The first candidate captures the existing native macro state envelope explicitly
per HeadCalc invocation. Active domains/nodes are copied; original cumulative
wall integration remains outside the Newton loop. Each trial restores that same
origin before boundary/macro evaluation. Original MACRORATE task2 computes both
the rates and their derivatives in one call; Jacobian assembly consumes the same
derivative rather than mutating the rates again. All original equations,
backtracking, iteration limits, local1e-6/total1e-5 criteria and daily1e-6 mass
guard are retained. The existing S5MAC006 native format is unchanged. The new
policy has its own build identity and is opt-in; no historical checkpoint rebind.

This addresses state accumulation but the original macro Jacobian is diagonal
despite nonlocal changes in groundwater classification and geometry. The second
candidate adds an inverse rank-one secant direction for the actual112-node
coupled residual, initialized from the original tridiagonal direction. Its state
is local to the invocation and discarded with the step. Original backtracking
and acceptance criteria remain in force. It is a distinct numerical attempt,
not another end-of-iteration refresh/polishing campaign.

## Actual bounded outcomes

Windows GNU16.2 frozen original object closure; original donor-O2/kernel-O2.
The source/compiler/object/input checks are active. No original reference is
modified and no accepted tolerance is enlarged.

| Variant | Exact source | Compile/link wall | Actual model/controller wall | Accepted days | Censored while requesting |
| --- | --- | --- | --- | --- | --- |
| Explicit origin, original diagonal |5168d4004e4ae3c49c18c00a8e86c6cb278451f5|16.999s|20.016s|1,2,3|4|
| Explicit origin, inverse secant |95970bb884b1f88fb4061f12454215a7859c8c88|6.688s|20.019s|1,2|3|

All completed days satisfy the existing daily balance guard. The maximum residual
is3.02802910546302e-7cm for the first candidate,7.653930241653065e-8cm for the
second. Their completed prefixes have156/177 mass-step retries respectively.
These censored prefixes do not qualify the fourth day, restart, full physical
accuracy or runtime parity. The cap does not prove that a mathematical solution
does not exist; it fails the selected practical qualification boundary.

Model/controller cost totals40.035seconds. The second direction makes no material
progress and reaches fewer accepted days. Therefore the two-attempt stop rule
applies. No longer cap, third related patch, Linux campaign or full481 run follows.
O0 and own2to4 are **NOT RUN** because their actual O2 fresh4 prerequisite failed;
they are not inherited as PASS for changed modelcode. Scientific status remains
NOT QUALIFIED. Failed code stays in its explicitly rejected research branch.

## Reproduction and preserved evidence

`consistent-macro-rejected-evidence.zip`,2806772bytes, SHA256
`0c0263821542f2606464890c88e677c0f4b503d6a5a1b6861407b5c2462908c6`,
preserves both actually executed generator revisions, compiled binaries,
generated owners, exact BUILD.json/compiler/object hashes and commands, inputs,
accepted native packages, journals and terminal errors. The immutable frozen
Windows provider is already preserved by the original-macro qualification.
No hosted artifact expiry is needed to retain these negative outcomes.

Each variant was built with its exact generator's
`build_bundle(original_S5MAC006_build, frozen_reference, new_build)`.
The actual short command was:

```sh
python -B research/hybrid-water01/probe_original_macro_block.py --bundle NEW_BUILD --reference FROZEN_REFERENCE --output NEW_FRESH --cap-seconds 20
```

BUILD.json and CONSISTENT_BUILD.json preserve the exact paths/flags/commands.
The O0/restart loop stopped at the first failed O2 prerequisite. To verify the
preserved result without another model:

```sh
python -B research/hybrid-water01/verify_consistent_macro_rejection.py
```

This checks the whole archive/member digests, actual executable/source/build
identity, bounded failures, every retained physical day and complete own native
package binding. It must report failed-candidate evidence, not model qualification.

## Consequence and next safe step

The defect is real, but explicit state plus either original diagonal or inverse
secant direction is not a practical demonstrated repair. Do not merge either
experimental model or claim the branch solves day438. The next solver work must
first establish a defensible coupled derivative/state map on a fixed live step,
including the moving saturated interface. A bounded full-residual directional/
Jacobian control can select a different formulation before another time march.
Do not repeat the rejected paired-rate, convergence-refresh or present secant
campaigns. All complete original project evidence and their distinct public
profiles remain available; whole scientific, energy and runtime acceptance remain
separate open work.
