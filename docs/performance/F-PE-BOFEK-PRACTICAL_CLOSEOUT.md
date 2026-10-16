# F-PE-BOFEK practical numerical-policy closeout

Date: 2026-09-28

Final status:

`CLOSED_NO_PRACTICAL_POLICY_GAIN`

Canonical base:

`integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`

## Evidence chain

### PRACTICAL01 — global bounded policy

No global candidate qualified.

Best robust global candidate:

- `initial dt = 0.5*DTMAX`;
- 16/16 P-C1 pass;
- median deterministic work reduction about 12.3%;
- below frozen 15% practical advancement gate.

Aggressive `DTMAX x2/x4` produced 37–42% work reduction on passing cases but failed runoff-sensitive wet/ponding cases.

### PRACTICAL02 — regime-aware policy

New out-of-sample validation:

- 13/16 P-C1 pass;
- median work reduction about 20.6%;
- B12 and O14 exposed hydraulic-response sensitivity;
- WET/POND preservation failed.

No regime-only policy qualified.

### PRACTICAL03 — hydraulic-archetype + regime policy

Second new out-of-sample validation:

- 15/16 P-C1 pass;
- median work reduction about 14.7%;
- required threshold 20%;
- O14/WET3 failed terminal-head accuracy and showed a local work regression.

Per preregistration, no further rescue policy is permitted.

## Main technical conclusion

There is real exploitable timestep-policy performance structure:

- dry and transition cases can often tolerate much larger `DTMAX`;
- ponding cases can sometimes benefit strongly from a larger initial timestep;
- wet/ponding sensitivity depends materially on hydraulic response;
- a single global practical setting is too conservative to capture the gains;
- a simple regime split is too coarse;
- the tested archetype-aware refinement still does not provide enough robust median gain.

Therefore the current evidence does not justify adding numerical-policy complexity to production.

## Production recommendation

Keep the existing corrected Reference numerical policy as default.

Do not add:

- a global practical DTMAX increase;
- a global larger initial dt;
- a regime-only policy;
- a material/archetype lookup;
- looser head tolerance;
- MAXIT/backtracking tuning.

No production `src/**` change is authorized.

## What remains useful

The negative result narrows future work.

If this line is revisited, it should not repeat parameter screening. A new study would need one of:

1. an authoritative BOFEK profile catalogue and broad real-BOFEK workload distribution, allowing expected-throughput optimization rather than equal-weight synthetic strata;
2. a different temporal error estimator or controller that can take large steps where safe based on state/flux error rather than static soil/regime classes;
3. a coupling-level objective where local trajectory differences are assessed against end-to-end MODFLOW/MultiSWAP quantities rather than single-column state equivalence.

Those are new research questions, not unfinished parts of PRACTICAL01–03.

## Preserved authority

Unchanged:

- BOFEK00 correctness;
- fixed-K dynamic-top `SWKIMPL=0`;
- BALTOL02;
- TEMPORAL08 bounded groundwater policy;
- all production defaults.

## Final classification

`CLOSED_NO_PRACTICAL_POLICY_GAIN`

