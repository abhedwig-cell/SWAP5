# F-CI19 first convergence admission plan

Status: `PLAN_PERSISTED_NOT_YET_COMPOSITION_QUALIFIED`.

## 1. What CI19 has established

The currently inspected production source lines are not a set of peer branches that should be merged together.

There is an ordered source lineage:

1. F-CI18 canonical baseline closeout `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`;
2. F-MQ24-qualified snow source under test `ffab7d705928170db3e76a5d346caafeb560e605`;
3. F-MR15 production postimage `af04ee6a2079569db9f1fde6ff3ac63076b22586`, independently admitted by F-VQ27;
4. F-KT09 qualified code head `4a792636ef73d25c671c5e0953cefd11978cd0ec`;
5. F-SI22 evidence head `1ac759b39ee743bfa0992d6b9da09f2cfeda38b9`, which adds no production source delta relative to the F-KT09 qualified code head.

Therefore the first convergence question is not how to merge F-MQ24, F-MR15, F-VQ27, F-KT09 and F-SI22. It is whether the latest inspected source postimage `4a792636...` still satisfies all earlier qualified claims that CI19 intends to preserve.

## 2. Candidate A

Candidate A is the exact F-KT09 qualified code postimage:

`4a792636ef73d25c671c5e0953cefd11978cd0ec`

Candidate A may preserve only claims that pass on that exact postimage.

Candidate A does not, by itself, admit a production Richards model-owned temporal certificate. F-KT09 explicitly leaves Richards estimator, normalization and threshold selection outside its qualified scope, and F-SI22 hands that numerical question downstream. The current F-VQ29 lineage is not qualified for release.

## 3. Required replay matrix on Candidate A

Before Candidate A can be proposed as a canonical admission postimage, run all of the following on the exact Candidate A tree.

### A. F-MR15 / F-VQ27 preservation

Replay the independent F-VQ27 gate without changing its scientific scope.

Minimum preserved properties:

- exact restricted serialized prescribed-bottom-head route;
- both accepted qbot signs;
- bottom-head authority;
- bottom-flux seed irrelevance;
- qbot authoritative mass exactly once;
- rejected-trial discard isolation;
- A/B/A replay;
- zero-tolerance stationary temporal acceptance;
- F-SI19 reference linear-solver behavior;
- O0/O2 output and diagnostic identity.

Failure means Candidate A cannot inherit the F-VQ27 admission.

### B. F-MQ24 snow preservation

Replay the full F-MQ24 gate on Candidate A because later runtime/backend changes occurred after the snow source postimage was qualified.

Keep all F-MQ24 holds unless a separate workunit expands them:

- exactly one-call duration 1.0 for active snow;
- subdaily, multiday and arbitrary-duration snow not admitted;
- real physical execution serialized;
- restricted equilibrium Richards scope only;
- no balanced, throughput or fallback policy;
- no 100k-column performance claim.

Failure means Candidate A cannot inherit the F-MQ24 snow admission.

### C. F-KT09 preservation

Replay the F-KT09 gate on Candidate A itself, or verify by exact tested-tree identity if Candidate A is exactly the original F-KT09 qualified code tree.

Required properties include:

- explicit opt-in model certificate mode;
- existing full-versus-two-half mode remains default;
- invalid or unavailable certificate fails closed;
- hard mass gate independent from temporal certificate;
- retry restores exact attempt checkpoint;
- accepted private substeps are not externally published before the requested interval completes;
- committed state mutates only through explicit candidate commit;
- no Richards-specific logic in F-KT;
- no calendar-specific logic.

### D. CI-level regression

Run the applicable canonical transaction, mass, source-lock and invariant gates against Candidate A. The exact replay list must be recorded with workflow run IDs and artifact digests.

## 4. Admission decision after replay

Only two valid outcomes exist.

`QUALIFIED_CANDIDATE_A_FOR_RESTRICTED_CANONICAL_ADMISSION`

This requires every mandatory replay to pass on the exact postimage and records the union of qualified scopes without broadening any hold.

or

`BLOCKED_CANDIDATE_A_COMPOSITION_REGRESSION`

Any failed mandatory replay blocks admission. CI19 must identify the first violated owner or invariant rather than weakening the earlier gate.

## 5. Lines deliberately excluded from Candidate A

The following are not folded into Candidate A merely because they are newer or locally qualified:

- F-VQ29 Richards fixed-horizon numerical policy, currently not qualified for release;
- F-GC02 groundwater predictor-corrector seam, currently owner-blocked;
- F-WOF34 accepted-window runtime lineage, because it diverges from the current F-KT line and still has actual physical binding and multi-day equivalence holds;
- F-LMFP09, which remains alternative-solver characterization;
- F-VZAA02, which is reservation/evidence work;
- F-TA03, which is fixture-fidelity/test infrastructure evidence;
- F-PM05 root-water-uptake readiness, which is blocked;
- F-PE05 temporal acceptance line, which records an owner blocker.

These lines remain nodes in the convergence graph and can join only through separately qualified composition postimages.

## 6. WOFOST convergence rule

F-WOF34 must not be merged directly into Candidate A.

Its branch diverges from the F-KT09 source lineage, and its own contract does not qualify the actual Richards/root-uptake/ET production binding or full historical multi-day trajectory equivalence.

The correct future route is:

1. start from a qualified canonical postimage that already contains the authoritative F-KT transaction semantics;
2. rematerialize the WOFOST owner-state/rate/runtime seam on that postimage;
3. bind accepted physical substeps through explicit runtime interfaces;
4. qualify transaction lineage, process coupling, crop-event exactly-once delivery and historical equivalence there;
5. admit only the exact scope that passes.

## 7. Groundwater convergence rule

F-GC02 cannot be pulled forward independently of the Richards owner line.

The coupling seam depends on correct and qualified lower-boundary temporal/runtime semantics. Until the active F-SI/F-VQ owner blocker is closed, groundwater coupling remains a graph dependency, not a canonical admission candidate.

## 8. Provenance rule for duplicate workunit labels

The repository currently contains multiple `F-SI21` branches with different purposes and conclusions. CI19 therefore treats `(branch, SHA)` as the minimum node identity. A workunit number alone is never sufficient authority for composition.

## 9. Next CI19 action

Materialize a qualification-only replay branch from exact Candidate A, add no production source changes, run the mandatory F-VQ27, F-MQ24 and F-KT09 preservation gates plus CI-level transaction/mass regressions, and persist the exact workflow evidence.

Do not advance `integration/f-ci-canonical` before that replay succeeds.