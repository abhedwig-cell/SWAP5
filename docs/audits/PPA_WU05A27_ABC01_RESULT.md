# PPA-WU05-A27 ABC01 result — production RFM versus standard macropore

Date: 2026-10-02  
Status: QUALIFIED_RESEARCH_RESULT_WITH_SHARED_REPAIR_CANDIDATES  
Qualified branch postimage: `586cb21a44ff24385718f160adf9d5a6e65e409e`  
Qualification run: 36991992438 — SUCCESS  
Evidence artifact: 11220220713  
Artifact digest: `sha256:a71255570a77cfb3ed111cf030529cec8506dca4838f92d192fff21fad732063`

## Executive result

The preregistered production A/B/C screen is now executable after three source-backed shared-backend defects were exposed and repaired branch-locally.

For the primary B/C question:

- standard macropore B completed 29/32 cases;
- admitted RFM C completed 30/32 cases;
- all 29 cases completed by both B and C classify **E1** under the preregistered thresholds;
- no completed pair required post-hoc E2 attribution and none classified E3;
- the only two remaining C failures are B01/R3 near-saturated storm cases, for both geometries; B also fails those same two cases at step 1;
- B has one additional failure, O05/G2/R1 at step 13, where C completes.

This is strong evidence that the repaired production RFM route is hydrologically close to the standard macropore comparator over the bounded ABC01 screen. It is not evidence of exact mechanistic identity.

## Performance result

RFM is **not faster** in the current production implementation.

Five-repeat fresh-state timing medians on the four preregistered cases:

| Case | B median s | C median s | B/C |
| --- | ---: | ---: | ---: |
| R2/G1/B01 | 0.002953 | 0.013227 | 0.223 |
| R4/G2/B01 | 0.003051 | 0.016080 | 0.190 |
| R5/G1/O05 | 0.002830 | 0.013696 | 0.207 |
| R6/G2/O05 | 0.002773 | 0.012027 | 0.231 |

Equivalently, C took about 4.3–5.3 times B wall time on this CI runner.

The nonlinear-iteration counts are almost identical in these timing cases. Therefore the observed slowdown is not explained by extra Richards nonlinear work. It points primarily to RFM trial-preparation/composition overhead and associated repeated constitutive work. This attribution is a performance hypothesis supported by the counters, not yet a profiler-level decomposition.

CI timing is machine-specific and is not a portable speed guarantee.

## Hydrologic screen

The 29 completed B/C pairs all satisfy E1:
- final total-storage and total-drainage differences remain within the preregistered 0.05 cm / 5% envelope;
- representative theta differences remain <= 0.02;
- mass accounting remains within the preregistered bound.

The continuous R4/R6 cases already passed after DEP02. DEP03 then removed the artificial event-cessation failure and extended successful C execution across the short, repeated and deep-loading event cases.

## Shared defects exposed by ABC01

### DEP01 — unreachable RFM live carrier

`state_matches_numerical_continuation_layout()` had no exact `fmr_b110_rfm_state_t` branch. The dedicated RFM carrier therefore failed state-profile admission before the first transaction.

Branch-local repair: explicit RFM no-continuation layout case.

### DEP02 — impossible nontrivial temporal acceptance

The RFM full/half temporal function returned zero only for bit-identical full and half states and `huge()` otherwise. Since RFM has no model-certificate route, nontrivial live evolution was structurally rejected.

Branch-local repair: dimensional full/half metric over matrix head, ponding, groundwater, theta×dz, MB storage and endpoint storage. History variables with non-length dimensions were not mixed into this centimetre-scale norm.

### DEP03 — dry continuation blocked

The activation layer already supported zero source, but surface composition converted `supply <= 0` to REFERENCE_REQUIRED. RFM therefore failed exactly when a rainfall event ended, preventing continued release of accepted IC storage.

Branch-local repair: zero supply is a valid zero surface receipt; negative supply remains outside the RFM route.

All three repairs preserve the bounded A26 first-order accepted-state-frozen split. They do not add monolithic coupling or pressure-aware A27 research physics.

## Matrix-only A arm

A did not complete because the generic base-state temporal function still uses exact full/half identity semantics. That is an existing broader Reference transaction limitation and is not required to answer the primary B/C A27 question. It is not repaired here.

Consequently ABC01 does not provide a valid matrix-only wall-time baseline. No RFM-versus-matrix speed claim is made.

## Interpretation

The earlier concern that production RFM was not doing what it should was justified, but the dominant initial failures were integration/admission defects rather than evidence that the reduced physical concept itself was unusable.

After repairing those defects, the bounded hydrologic behavior is much better than the pre-repair runtime suggested: 29/29 jointly completed cases are E1.

The current performance proposition, however, fails. RFM as presently composed is substantially slower than the standard macropore route in the preregistered timing sample. A27 should therefore continue as a performance-attribution problem, not as further hydrologic tuning.

## Governance

DEP01, DEP02 and DEP03 are qualified branch-local shared-backend repair candidates. They are **not canonical-admitted by A27**. Central SWAP5 regie owns canonical admission.

The A27 pressure-aware signed research seam remains excluded from comparator C and from these repairs.
