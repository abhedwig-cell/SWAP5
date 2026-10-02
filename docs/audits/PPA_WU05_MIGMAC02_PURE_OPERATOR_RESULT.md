# PPA-WU05-MIGMAC02 pure operator result

Date: 2026-10-02
Status: PURE_OPERATOR_QUALIFIED_INTEGRATION_NOT_STARTED
Branch head: a0903b329ddaea3b0faa32edb88b66740e3976f3
Run: https://github.com/abhedwig-cell/SWAP5/actions/runs/37001979568

## Implemented bounded slice

A pure typed dynamic-shrinkage module now separates:

1. the clay Kim option-1 shrinkage relation; and
2. the B1.11 MPVOLUME hysteretic crack-volume transition.

No production runtime/provider is changed yet.

The selected first input family is clay SWSOILSHR=1, SWSHRINP=1. The invalid
clay + SWSHRINP=3 combination remains excluded.

## E4 source-history falsification

The existing A3 E4 state pair is reproduced:

- theta = 0.35;
- theta_previous = 0.30;
- theta_s = 0.45;
- theta_crack = 0.30;
- dz = 10 cm;
- geometry factor = 3;
- matrix area fraction = 0.92;
- shrink fraction = 0.05.

Fresh history produces zero dynamic crack volume.

A prior local crack of 0.08 cm produces:
0.30928072600977707 cm.

A prior neighbouring crack of 0.08 cm produces the same result.

This confirms that the typed operator preserves the previously source-reconciled
hysteresis branch rather than deriving crack volume from current theta alone.

The older A3 report recorded only approximately 0.30928 cm. An initially used
longer decimal reference was rejected by the test and removed; it was unsupported
precision, not source authority.

## Kim relation

The module implements the documented direct-parameter clay relation:
e = alpha_K * exp(-beta_K * moisture_ratio) + gamma_K * moisture_ratio,
with moisture_ratio = theta/(1-theta), plus the documented e0 lower floor.

The current Kim test is an algebra/range test. It is not yet a B1.11 executable
parity test for SHRINKPAR-generated parameters.

## Qualification

O0: PASS
O2: PASS
E4 hysteresis: PASS
Exact local/neighbour history symmetry: PASS

## Boundary before integration

Do not yet wire this module into ppa_wu05a16_inner_macropore_provider_t.

Before production integration, recover or capture the exact B1.11 SHRINKPAR
parameter conversion and MPVOLUME shrinkage-fraction calculation for the selected
clay option-1 route. The theory equation supports the relation, but source parity
of all intermediate conversions has not yet been demonstrated.

Implemented: TRUE
Persisted: TRUE
Pure operator tested: TRUE
Pure operator qualified: TRUE
Production integrated: FALSE
Source-backed E2E: FALSE
Canonically admitted: FALSE
