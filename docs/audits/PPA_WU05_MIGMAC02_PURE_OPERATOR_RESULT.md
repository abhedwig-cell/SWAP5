# PPA-WU05-MIGMAC02 pure operator result

Date: 2026-10-02
Status: EXACT_B111_CLAY_OPTION1_OPERATOR_QUALIFIED_INTEGRATION_NEXT
Branch head: a0903b329ddaea3b0faa32edb88b66740e3976f3
Run: https://github.com/abhedwig-cell/SWAP5/actions/runs/37002806237

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

The exact 88,138-byte donor macropore.f90 was reconstructed from the
archive/swap431-wofost81-qualified-donor GitHub branch. Its SHA-256 is
1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0.

Exact source semantics are now implemented and tested:

- SHRINKPAR(1): ShrParA/B/C are Alfa/Beta/Gamma and ShrParD is computed as
  -log((Gamma-1)/(Alfa*Beta))/Beta;
- SHRINK: solid fraction = 1-ThetaS and MoisR = Theta/solid fraction;
- above ShrParD, VoidR=MoisR;
- below ShrParD, VoidR=Alfa*exp(-Beta*MoisR)+Gamma*MoisR with Alfa floor;
- relative shrinkage = ThetaS - VoidR*solid fraction.

The earlier theory-derived theta/(1-theta) implementation was falsified by the
actual source and removed before production integration.

## Qualification

O0: PASS
O2: PASS
E4 hysteresis: PASS
Exact local/neighbour history symmetry: PASS

## Boundary before integration

Do not yet wire this module into ppa_wu05a16_inner_macropore_provider_t.

The source-conversion blocker is closed. The next integration seam is explicit:
ppa_wu05a16_inner_macropore_provider_t must receive accepted previous-step matrix
theta plus immutable shrinkage configuration, construct trial-local candidate
dynamic geometry during each active rate refresh, and publish only the candidate
associated with the accepted receipt.

Implemented: TRUE
Persisted: TRUE
Pure operator tested: TRUE
Pure operator qualified: TRUE
Exact B1.11 clay option-1 source parity: TRUE
Production integrated: FALSE
Source-backed E2E: FALSE
Canonically admitted: FALSE
