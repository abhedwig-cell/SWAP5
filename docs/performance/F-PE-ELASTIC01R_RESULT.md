# F-PE-ELASTIC01R — bracket refinement result

Date: 2026-09-29

Status: REFINEMENT_RECORDED_SOIL_DEPENDENCE_CONFIRMED_NO_RULE_YET

Workflow: `36518210316`
Job: `109245145701`
Conclusion: PASS

## Scope

Refinement on six saturated or near-saturated screening cases only. The four frozen BOFEK holdout cases remained unopened.

Coefficients:
`2e-7, 5e-7, 7.5e-7, 1e-6, 1.5e-6, 2e-6, 5e-6`.

## Main result

The response to ELAS is strongly material- and regime-dependent.

### B01/WET

Physical response is smooth and approximately monotone.

- no deterministic work reduction across the tested bracket;
- bottom-head shift grows from about `-4.88e-4 cm` at `2e-7` to `-1.21e-2 cm` at `5e-6`;
- runoff and ponding remain unchanged in this fixture.

This is primarily a physical saturated-storage response, not a performance opportunity.

### B01/POND

Response is smooth and strongly monotone in physical storage/runoff partitioning.

At `2e-7`:
- runoff delta `-1.8427e-3 cm`;
- storage delta `+1.8427e-3 cm`;
- work `313 -> 212`, about 32.27% reduction.

At `1e-6`:
- runoff delta `-1.07074e-2 cm`;
- storage delta `+1.07074e-2 cm`;
- work `313 -> 212`, about 32.27% reduction.

At `5e-6`:
- runoff delta `-5.4342e-2 cm`;
- storage delta `+5.4342e-2 cm`;
- work reduction about 36.10%.

The performance response cannot be separated from a real physical redistribution of water. No speed-only interpretation is valid.

### B12/MOIST and B12/WET

Both show smooth, approximately linear ELAS sensitivity.

B12/MOIST:
- top-head delta grows from about `+3.89e-4 cm` at `2e-7` to `+9.55e-3 cm` at `5e-6`;
- work is unchanged.

B12/WET:
- top-head delta grows from about `-5.10e-4 cm` at `2e-7` to `-1.28e-2 cm` at `5e-6`;
- work is unchanged.

Again, this is mainly a physical response, not a numerical acceleration mechanism.

### O05/WET

No effect in this fixture over the entire tested bracket because the simulated state does not activate positive-head ELAS storage at the evaluated nodes.

### O05/POND

The numerical response is distinctly non-monotone.

Observed:
- `2e-7`: nonconvergence at dtmin;
- `5e-7`: nonconvergence at dtmin;
- `7.5e-7`: converged, work 308 -> 336, about 9.1% worse;
- `1e-6`: nonconvergence at dtmin;
- `1.5e-6`: nonconvergence at dtmin;
- `2e-6`: converged, work 308 -> 336, about 9.1% worse;
- `5e-6`: converged, work 308 -> 148, about 51.95% less.

The O05/POND surface therefore contains solver-path transitions or resonance-like interaction with timestep/nonlinear policy. It cannot support a monotone ELAS-to-robustness rule.

## Conclusions

1. ELAS response is materially soil dependent.
2. A single global value such as `1e-6` is not supported as a transparent default by this screening bank.
3. B01 shows a potential performance benefit under ponding, but it is inseparable from real added saturated storage.
4. B12 shows physical sensitivity with essentially no solver benefit.
5. O05 shows non-monotone solver behaviour under ponding and requires mechanistic characterization before any parameter rule.
6. The evidence supports treating ELAS as a soil-hydraulic constitutive property whose numerical consequences must be qualified, not as a solver tuning parameter.

## Next step

Before fitting any soil-driven relation:

- derive material descriptors from the existing MvG parameters;
- characterize near-saturation capacity and conductivity shape for B01, B12 and O05;
- identify which descriptor distinguishes the monotone B01/B12 behaviour from O05's non-monotone ponding response;
- do not inspect holdout cases until a candidate rule and coefficients are frozen.

No production rule is selected here.
