# Coupling semantics impact audit and repair slices

Date: 2026-09-20

Canonical preimage: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`.

## Defect classification

The audit finds a combination, not one isolated bug.

| Class | Finding |
| --- | --- |
| interpretation defect | **CONFIRMED**. A temporary lower-face Dirichlet realization has been described as if it were the coupled application's groundwater semantics. |
| authority-binding defect | **CONFIRMED**. `bottom_mode==5` is used as production groundwater-profile authority although F-GC17's actual scientific invariant is head consistency at the coupling boundary. |
| implementation defect | **CONFIRMED, bounded**. The production bootstrap/materializer leak the legacy selector into coupled application admission and thereby reject process combinations for the wrong authority reason. The prepared-solve iteration itself is not shown defective. |
| architecture/design defect | **CONFIRMED**. The application contract lacks explicit vertical head-transfer, drainage ownership and storage-domain partition. These omissions prevent a general production coupling claim. |

The architecture defect is not “mode 5 is numerically wrong”. Mode 5 remains a plausible internal realization of a head-driven corrector.

## F-GC evidence impact

| Evidence family | Disposition | Reason |
| --- | --- | --- |
| F-GC17 head/datum invariant | **SEMANTIC_REINTERPRETATION_REQUIRED** | Preserve lower-face head/datum conversion. Remove application-level implication that the coupled profile is intrinsically SWBOTB=5. |
| F-GC21 concrete FMR forcing adapter | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED** | Numerical conversion may remain, but the `bottom_mode==5` admission key must move behind coupled-interface authority. |
| F-GC23 predictor tangent | **UNAFFECTED numerically** | Prescribed-`qbot` predictor/tangent identity is independent of application mode-5 identity. |
| F-GC25/F-GC31 active-drainage response work | **NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED** | Evidence remains useful; its separation from the mode-5 corrector is an implementation envelope, not proof of physical incompatibility. |
| F-GC30 predictor response | **UNAFFECTED numerically; storage interpretation bounded** | `u/q_u` algebra remains. Broad physical storage ownership requires explicit partition authority. |
| F-GC33 affine MODFLOW response | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED for realistic production** | Algebra is valid; physical combination with MODFLOW STO needs non-overlap authority. |
| F-GC38/F-GC39 prepared-solve iteration | **UNAFFECTED** | Accepted `XOLD` versus trial `X` ownership remains correct. |
| F-GC40 N:1 aggregation | **UNAFFECTED as composition evidence** | Does not establish physical aggregation or storage partition. |
| F-GC41 transaction/publication | **UNAFFECTED** | Trial versus accepted authority and exactly-once publication remain valid. |
| F-GC43/F-GC44 real participant/end-to-end | **NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED** | They qualify one restricted internal realization, not general application-level mode-5 groundwater semantics. |
| F-GC45-F-GC48 scaling/topology tests | **UNAFFECTED as software-composition evidence** | No new physical topology claim follows. |
| F-GC49 application service | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED** | Iteration can remain, but application profile, head transfer, storage and process ownership must be rebound. |
| F-GC50 iMOD product composition | **GOVERNANCE_RECONCILIATION_REQUIRED** | Product orchestration may remain in iMOD Coupler while the inner prepared-solve algorithm stays below it; wording must make this layering explicit. |

## PUB-GC E1-E7 impact

| Experiment | Disposition | Exact consequence |
| --- | --- | --- |
| E1 | **NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED** | Transaction, sign/unit and accepted-transfer identities remain evidence. Do not describe mode 5 as application groundwater authority. Zero-storage-change case still does not resolve storage partition. |
| E2 | **UNAFFECTED** | Rejected-trial and publication-authority evidence is independent of the disputed boundary interpretation. |
| E3 | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED** | Numerical convergence under the tested identity head map remains observed. Hydrological interpretation is conditional on head-transfer and storage assumptions. |
| E4 | **UNAFFECTED for response identity; semantic wording required** | The distinction among `u_A`, `u_FD`, `J_S`, `J_R` remains useful and in fact supports the corrected contract. Do not promote `u` to a universal physical storage coefficient. |
| E5 | **UNAFFECTED as algorithmic response experiment** | It studies derivative information after a response map is supplied; it does not establish application storage ownership. |
| E6 | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED** | The negative stop remains historical evidence about the then-admitted component intersection. It is not evidence that drainage and head-driven correctors are physically incompatible. |
| E7 | **COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED** | Preserve frozen Hupsel dates and stop evidence. Supersede `REALISTIC_COMPONENT_DOMAIN_LIMIT` as a physical/application-envelope conclusion with `DIAGNOSTIC_EVIDENCE_UNDER_SEMANTIC_REVIEW`. Do not rerun until corrected authority exists. |

No E1-E7 artifact is deleted. None may be silently relabelled as if it had been generated under the corrected contract.

## PUB-GC claim impact

Claims about transactional state authority, rejected trials, exactly-once publication and the numerical value of strong iteration in the restricted experiments remain supportable.

Claims that require revision or suspension include:

- language identifying production groundwater coupling with a prescribed-head SWBOTB=5 application profile;
- interpretation of E6/E7 as a fundamental drainage-versus-groundwater-head application boundary;
- broad hydrological claims that assume the identity MODFLOW-node-to-SWAP-bottom head map without naming that assumption;
- realistic coupled-storage claims until SWAP-response storage versus MODFLOW STO ownership is explicit.

The manuscript must not move to final submission authority while these points remain unresolved.

## Repair slices

### GC-SEM-R1: semantic application profile

Introduce a coupled-groundwater application profile independent of the legacy lower-boundary selector.

Acceptance:

- external application configuration does not require `bottom_mode=5` to express MODFLOW coupling;
- current mode-5 materialization can remain internal;
- no physics widening.

### GC-SEM-R2: head-transfer authority

Add explicit topology/application metadata for:

- SWAP lower-face datum;
- selected MODFLOW head location;
- identity or non-identity head-transfer law.

Acceptance:

- identity transfer is a named assumption, not an implicit equality;
- diagnostic SWAP groundwater level remains distinct.

### GC-SEM-R3: storage partition authority

Before broad production admission, define and qualify the physical storage partition behind:

- SWAP-derived `u`;
- MODFLOW STO;
- any overlap correction.

Acceptance:

- one water volume cannot contribute twice to the coupled storage equation;
- a nonzero-storage-change qualification demonstrates the chosen partition.

This slice requires scientific/architectural authority and is the present blocker for full closeout.

### GC-SEM-R4: drainage ownership

Add an application-level drainage-owner declaration and double-booking guards.

Acceptance:

- each physical drain path has one owner;
- SWAP-owned drainage can participate in predictor/corrector trials when separately admitted;
- MODFLOW-owned drainage is not duplicated in SWAP.

### GC-SEM-R5: root/process composition

Replace blanket mode-5 groundwater-profile process exclusions with capability-based admission.

Acceptance:

- root uptake remains SWAP-owned;
- response/tangent requirements are separately qualified;
- process support is not inferred merely from standalone support.

### GC-SEM-R6: production requalification

Requalify affected F-GC21/F-GC33/F-GC43/F-GC44/F-GC49 surfaces under the corrected contract.

Preserve F-GC38/F-GC41 transaction authority unless implementation changes cross those boundaries.

### GC-SEM-R7: PUB-GC re-adjudication

After R1-R6 authority is sufficient:

- reclassify E1-E7 against the corrected contract;
- decide prospectively whether E6/E7 should be rerun;
- update manuscript claims;
- never overwrite the original preregistered evidence.

## Stop condition

Do not implement R3 by assumption.

The repository does not yet contain sufficient scientific authority to decide the realistic SWAP-response-storage versus MODFLOW-STO partition for general applications. That decision must be established explicitly before a broad coupled application can be admitted.
