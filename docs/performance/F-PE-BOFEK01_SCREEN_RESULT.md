# F-PE-BOFEK01 screening result — numerical-policy sensitivity on corrected wet Reference

Date: 2026-09-28

Status: `SCREENING_COMPLETE_NO_ADVANCING_CANDIDATE`

Authority:

- canonical: `integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`;
- branch head exercised: `60f68c0a5ecf9da0926a33c485c8cb832826e62a`;
- Actions run: `36413271282`;
- job: `108898281322`;
- conclusion: SUCCESS.

## Scope

The screening uses the BOFEK00-corrected fixed-K dynamic-top, `SWKIMPL=0` Reference route.

The current repository does not contain a complete BOFEK profile catalogue or BOFEK-ID-to-hydraulic-parameter mapping. Therefore the 20-case bank is a repository-backed hydraulic/regime bank using the previously exercised B01, B12, O05 and O14 material parameterizations. It supports numerical-policy screening, but not a BOFEK-ID-specific production claim.

Sixteen cases were used for screening. Four preregistered cases remained untouched holdouts.

## Frozen advancement rule

A parameter family could advance only if:

1. median deterministic solver-work reduction was at least 8%; and
2. all strict physical/numerical gates passed.

The deterministic work index was:

`nonlinear iterations + backtracks + Jacobian builds + linear solves`.

Wall-clock was secondary during screening.

## Main result

No tested candidate satisfied both conditions.

### Timestep envelope

- `DTMAX x4` reached 8.33% median work reduction among the single strict-passing case, but passed only 1/16 cases. Ten cases failed the terminal-head gate and five failed runoff.
- `DT0 = 0.5*DTMAX` reached 8.57% median work reduction across its passing subset, but passed only 6/16 cases.
- `DT0 = DTMAX` reduced work by 19.44% in its single passing case, but passed only 1/16.
- `DTMAX x2` passed 0/16 strict gates.
- smaller/larger `DTMIN` did not produce a qualifying work reduction and caused trajectory failures in multiple cases.

Interpretation: larger initial/envelope timesteps can substantially reduce solve work, but under the strict Reference equivalence gates the changed accepted-dt trajectory is too influential to qualify as a Reference policy change.

### Timestep adaptation

- `NUMBIT_CRIT=5` and 6 preserved most cases, but median work reduction was 0%.
- `NUMBIT_CRIT=2` materially increased work.
- growth factors 1.25, 1.5 and 3.0 did not qualify; the latter two showed apparently favorable one-shot wall ratios on a tiny passing subset while deterministic work was worse. These timing values are therefore not evidence of a speed gain.
- accepted-step decrease and failure-reduction variants had 0% median work reduction.

Interpretation: adaptation thresholds/factors are not a material lever in this bank once the corrected wet solver is used.

### Nonlinear solve effort

- `MAXIT` 5, 6, 10 and 12 had 0% median work reduction; lower caps also introduced failures.
- `max_backtracking` 2, 4 and 6 passed all 16 screening cases but changed work by 0%.
- head-tolerance x10 gave 3.03% median work reduction and passed 15/16;
- head-tolerance x100 gave 6.16% median work reduction and passed 14/16.

Neither head-tolerance arm reached the preregistered 8% advancement threshold, and both lost at least one strict runoff case.

Balance tolerance was not reopened because BALTOL02 is existing production authority.

## Negative result

No parameter independently advanced.

Therefore the preregistered interaction stage is not entered. In particular there is no authority to run or optimize:

- `DTMAX x NUMBIT_CRIT`;
- `MAXIT x failure-reduction`;
- hydraulic-class-specific numerical sets;
- regime-aware numerical sets.

Doing so after seeing this screen would violate the preregistered advancement rule.

## Timing interpretation

Single-process wall-clock measurements in this screen are too short for direct production timing claims. The deterministic solver-work metric is the decision metric at this phase.

Where the deterministic work did not improve, apparently faster individual wall measurements are treated as runner noise rather than as performance evidence.

## Decision

`NO_ADVANCING_NUMERICAL_POLICY_CANDIDATE`

No production numerical default or policy mapping is justified from this screening.

The BOFEK00 wet correctness route remains preserved.

