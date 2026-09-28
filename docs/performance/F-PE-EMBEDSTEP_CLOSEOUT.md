# F-PE-EMBEDSTEP01-02 closeout — dynamic-top selective temporal control

Date: 2026-09-28

Final status:

`CLOSED_NO_SELECTIVE_TEMPORAL_CONTROL_GAIN`

Canonical base:

`integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`

## EMBEDSTEP01

A selective full-versus-two-half guard was triggered only when the normalized state-aware controller requested dt above the current Reference DTMAX.

Result:

- 14/16 P-C1 pass;
- about 20.8% median work regression;
- embedded guard was rarely selective;
- one important B12/MOIST failure happened with zero guard checks.

Conclusion:

The trigger came too late and the speculative full+half cost was too high.

## EMBEDSTEP02

The architecture was changed before exposure:

- historical Reference-TimeControl owns all intervals within the current envelope;
- state-aware logic may only request larger intervals;
- large intervals are executed as two sequential half steps;
- no speculative full-step solve.

Result:

- 15/16 P-C1 pass;
- all WET/POND cases pass;
- median deterministic work reduction about 5.7%;
- required threshold 15%;
- one B12/TRANSITION nonconvergence remains.

## Final technical conclusion

The sequence of BOFEK, STATESTEP and EMBEDSTEP studies now isolates the problem more tightly.

There is substantial theoretical gain from taking larger intervals, but cheap static or one-step-history logic does not know early enough when a large interval is safe.

When robustness is restored by selective temporal refinement, the added solve effort removes most of the gain.

Therefore the next useful research target is not another timestep heuristic.

It is a **dynamic-top-compatible cheap temporal error estimator or predictor** that can discriminate safe large steps without executing two additional nonlinear solves.

Relevant directions include:

1. extending the existing Reference temporal-defect indicator to the dynamic-top boundary while preserving the BOFEK00 Jacobian/runoff semantics;
2. deriving a pre-solve surface-boundary transition predictor from the dynamic-top flux/runoff equation;
3. using a low-cost tangent/predictor estimate to decide whether the expensive temporal check is needed;
4. evaluating such an estimator first as a classifier of safe versus unsafe large-step attempts before granting it timestep authority.

## Production boundary

No production `src/**` changes are authorized.

Existing Reference TimeControl remains the recommended default.

Final classification:

`CLOSED_NO_SELECTIVE_TEMPORAL_CONTROL_GAIN`.
