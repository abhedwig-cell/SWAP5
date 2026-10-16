# F-MIG431-LOW03-A shared prerequisite: temporal acceptance for implicit Cauchy trials

Status: OPEN CENTRAL PREREQUISITE. LOW03-A does not alter shared transaction or temporal-acceptance policy.

## Trigger evidence

After consuming the centrally admitted DEP01 serialized-context successor, LOW03-A qualification run `36988363611` at postimage `12dca0e38611d243a638a1f6e2caf035d497acd5` reaches and converges the Reference mode-3 solver.

Observed final attempt:

- application profile: ADMITTED;
- solver route: `legacy-reference-bound`;
- solver executed: true;
- nonlinear iterations per solve: 1;
- solver rejections: 0;
- mass rejections: 0;
- temporal rejections: 3;
- transaction result: retry exhausted after the configured two retries.

The fixture is an exact constant-flux equilibrium construction: homogeneous material, constant pressure head, top flux `-K`, Q4=0 and Haq chosen from the admitted LOW03-P0 law so the lower Cauchy flux is also `-K`. Increasing the nonlinear budget does not change the classification.

## Root cause

The ordinary serialized Reference model currently uses `fmr_serialized_temporal_identity` for external full/two-half temporal acceptance. For the non-macropore route it returns zero only when full and half candidate states are bit-identical; any difference returns `huge()`.

That policy is suitable only for routes whose qualified staging is exactly path-identical. The implicit mode-3 boundary evaluates a conductance containing the bottom-node conductivity `Kb`. Even when every individual solve converges and satisfies the admitted Cauchy law, the full solve and two sequential half solves need not materialize bit-identical floating-point candidates. The current temporal identity policy therefore rejects the route independently of the configured temporal tolerance.

This is downstream of the LOW03-A timing/application binding and upstream of commit. It cannot be repaired by increasing `temporal_tolerance`, because the temporal error is `huge()`, not a finite physical difference.

## Required central decision

Central transaction/numerical authority must choose and qualify a temporal acceptance contract for ordinary implicit Cauchy mode 3. Candidate routes include a bounded finite physical full/half norm under existing transaction ownership, or an already governed model-certificate route if its history/staging contract can be satisfied without inventing state.

LOW03-A must not silently:

- change `fmr_serialized_temporal_identity` for all Reference modes;
- weaken transaction acceptance;
- bypass full/half qualification;
- force-commit a converged full solve;
- invent temporal history or change Restart-v1;
- treat a huge temporal error as acceptable.

## Qualification required before LOW03-A resumes

The shared successor must prove existing modes 2/-2, 4, ordinary and groundwater-owned 5, 6 and 7 are preserved, mode 3 obtains a finite and physically interpretable temporal decision, reject/retry/rollback remains transactional, and restart/replay remains deterministic. The LOW03-A application must then rerun its complete timing, mass, A/B/A and preservation suite.

This prerequisite does not falsify LOW03-P0 physics. It identifies a missing application-level temporal acceptance contract.
