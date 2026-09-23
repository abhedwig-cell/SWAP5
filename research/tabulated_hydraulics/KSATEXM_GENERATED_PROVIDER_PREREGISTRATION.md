# TAB-HYD KSATEXM generated-provider preregistration

Date: 2026-09-23

Status: **RESEARCH PREREGISTERED — NO PRODUCTION AUTHORITY**

Branch: `research/tabulated-hydraulics-ksatexm-characterization`

Source postimage:

- qualified F-TAB02 branch: `work/f-tab02-generated-k0-provider@a309bdf527e75f084806c3c15bf1071948c8b66f`;
- live canonical authority at branch creation: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- F-TAB02-F blocker: exact whole-Hupsel M1-C3 profile requires admitted F-SI39 KSATEXM semantics that are deliberately outside F-TAB02.

## Research question

Can the already qualified generated raw-head400 K0 representation preserve the **admitted F-SI39 KSATEXM conductivity extension** without changing theta/C physics, solver policy, K0 semantics, or the existing constitutive-provider ABI?

This is not a request to widen F-TAB02 in place. It is a falsification/qualification study that may create authority for a later, separately preregistered production slice.

## Controlling F-SI39 semantics

When the default-MvG provider is initialized with `enable_ksatexm_extension=.true.` and `cofgen(10)>cofgen(3)`:

- theta(h) and C(h) remain the existing default-MvG functions;
- below the stored relative-saturation threshold `cofgen(11)`, K(h) is exactly the default route;
- above that threshold, K is the admitted B1.11 linear interpolation in relative saturation from `cofgen(12)` to `cofgen(10)`;
- saturated K equals `cofgen(10)`;
- production scope remains `SWKIMPL=0`; derivative admission is out of scope.

The exact Hupsel whole-application profile uses KSATEXM = 10 × KSATFIT in both hydraulic layers.

## Frozen candidate

Do not change the already qualified representation except where the saturated-conductivity branch authority itself differs:

- 400 rows;
- pressure-head knots uniform in `log10(-h)`;
- raw physical h as runtime interpolation coordinate;
- theta ordinate unchanged;
- ln(K) ordinate;
- TSPACK preprocessing;
- explicit wet theta/C branch;
- constant dry extension;
- bounds-safe lookup;
- immutable preprocessing outside trial/nonlinear hot loops.

For a KSATEXM-enabled node, the generated continuous K branch is sampled from the **admitted analytical provider with F-SI39 enabled** and terminates immediately below the admitted saturated KSATEXM endpoint. The saturated endpoint/plateau is `cofgen(10)`, not `cofgen(3)`.

No hand-written alternative KSATEXM equation may replace the admitted provider during generation.

## Phase A — exact Hupsel two-layer constitutive falsification

Use the exact M1-C3 Hupsel B1.11 hydraulic rows recorded in F-TAB02-F.

Compare analytical F-SI39 provider versus generated provider over a dense head sweep and explicit branch probes.

Predeclared acceptance limits:

- theta max abs <= `1e-4`;
- C max abs <= `1e-4`;
- log10(K) max abs <= `5e-4`;
- K0 derivative output remains exactly zero;
- saturated K agrees with KSATEXM;
- the disabled-extension default route remains unchanged;
- generation is deterministic;
- H_ENPR remains fail closed.

These are the existing F-TAB02-B constitutive limits; they may not be relaxed after observing results.

## Phase B — bounded solver/runtime qualification

Only if Phase A passes.

Use the existing F-TAB02 Reference-Richards and serialized-runtime harnesses with the exact two Hupsel material parameter rows and F-SI39 enabled.

Required:

- same nonlinear iteration counts where the analytical control converges;
- same retry/accept semantics;
- hard mass gate;
- no hidden fallback to analytical K within a generated trial;
- persistent immutable generated state;
- no change to transaction tolerances.

Performance is characterization only, not a scientific pass condition.

## Phase C — exact whole-Hupsel authority

Only if A and B pass.

Re-enter the existing exact M1-C3 whole-Hupsel gate using the already verified archive authority:

`SHA256 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.

The test must preserve the exact M1-C3 application profile, including F-SI39. No synthetic or alternate Hupsel substitute is allowed.

## Stop conditions

Stop and classify rather than repair the result if:

- the frozen 400-row representation exceeds the predeclared constitutive limits;
- preserving F-SI39 requires a new solver/provider ABI;
- K0 trajectory/transaction semantics diverge beyond the existing F-TAB02 gate;
- generated state must become mutable physical state;
- support would require K1 or generic external tables.

A failed 400-row KSATEXM representation may motivate a new research candidate, but it cannot be silently tuned and called the same preregistered candidate.

## Nonclaims

This line does not admit:

- KSATEXM generated provider in production;
- generic SWSOPHY=1;
- arbitrary external tables;
- SWKIMPL=1;
- a whole-SWAP speedup percentage;
- F-TAB02-F closure before the exact whole-application gate passes.
