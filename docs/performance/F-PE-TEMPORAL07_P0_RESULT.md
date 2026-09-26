# F-PE-TEMPORAL07 P0 result

Date: 2026-09-26

Status: `PASS_SAME_POLICY_LINEAR_RESPONSE`

Preregistration:

`docs/performance/F-PE-TEMPORAL07_PREREGISTRATION.md`

Harness:

`tests/fpe/run_fpe_temporal07_p0_linear_response.sh`

## Result

The frozen c=0.65 policy was evaluated on 10 difficult dynamic origin/history groups:

- B01 wet, +/-10% history;
- B12 wet, +/-10%;
- O05 wet, +/-10%;
- O14 wet, +/-10%;
- O14 mid, +/-10%.

For each group, the fresh accepted-trajectory tangent at the center head was used to predict q at:

- +/-0.001 cm;
- +/-0.01 cm;
- +/-0.05 cm;
- +/-0.10 cm.

All center and probe candidates completed.

Solver rejections:

`0`

Maximum relative q-linearization errors:

- |delta H| = 0.01 cm: `1.20277135053985114e-06`;
- |delta H| = 0.05 cm: `4.83999642543446202e-03`;
- |delta H| = 0.10 cm: `1.01380407741323685e-02` characterization only.

Frozen P0 gates:

- <=1% at +/-0.01 cm: PASS;
- <=2% at +/-0.05 cm: PASS.

Twelve +/-0.05 or +/-0.10 probes crossed a temporal path boundary and changed retry/substep count. Those path changes were reported rather than hidden; all frozen admission perturbation gates still pass.

## Decision

P0 passes.

The c=0.65 accepted-trajectory tangent provides a bounded MODFLOW-facing local linearization of the c=0.65 response map over the preregistered admission range.
