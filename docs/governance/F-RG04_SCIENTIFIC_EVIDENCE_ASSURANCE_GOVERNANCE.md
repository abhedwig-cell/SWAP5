# F-RG04 Scientific Evidence, Qualification, Admission, Composition & Assurance Governance

Workunit: `F-RG04`

Branch: `regie/f-rg04-scientific-evidence-assurance-governance`

Authoring base: `integration/f-ci-canonical@e79b0272edb544ec4c8000a4d6869274f1ab3ae5`, tree `44e904cd2c57a76ee6c7453a6782049b230a8f8d`.

Scope: governance only. F-RG04 changes no production source, physics, solver semantics, transaction semantics, mass semantics, restart semantics, groundwater semantics, numerical acceptance policy, completion denominator, completion weight, Status-A claim, RB1 authority, RossFast production status or energy-balance production status. It does not modify `integration/f-ci-canonical` and performs no F-CI admission or F-VQ qualification.

## 1. Relationship to existing SWAP5 regie

F-RG04 is an additive consolidation layer, not a replacement governance universe.

It preserves without reinterpretation:

- F-RG01: program baseline/rebaseline authority and architectural invariants.
- F-RG01A: semantic-contract ownership determines safe parallelism; research maturity remains `RESEARCH_ISOLATED -> CONTRACT_COMPATIBLE -> INTEGRATION_CANDIDATE -> PRODUCTION_ADMITTED`.
- F-RG01B: a workunit is defined by scientific/architectural cohesion rather than one chat/runtime; durable checkpoints support resumption and moving authorities are selectively rechecked.
- F-RG01C: `SWAP5_V1_COMPLETION_MODEL_V1` remains the only frozen v1 denominator/weight model. F-RG04 provides no completion credit and creates no hard ceiling.
- F-RG01D: module manifests are compact contract capsules and authority indexes, never a second source of technical truth.
- F-RG03: `rebaseline -> parallel execute -> qualify/admit -> rebaseline`; parallel work is allowed only where contract ownership is disjoint; shared canonical authority is serialized.

F-RG04 adds one epistemic authority chain:

`evidence -> bounded claim -> qualification -> assurance -> composition -> admission -> preservation`

Each arrow is fail-closed. A downstream state may consume upstream evidence, but never silently inherits a stronger authority than has actually been proved.

## 2. Evidence is not authority

Evidence is an input to an authority decision. It is not itself an authority merely because it is reproducible, numerically green, historically sourced, independently generated, or stored in a testbank.

Every evidence item used for a material claim should identify its class, source/candidate identity, scope, provenance strength, claim it supports, limitations, and consuming authority. When a conclusion depends on exact source, candidate, testcase, build, workflow or replay identity, those identities are pinned by immutable commit/tree/blob/hash/run identifiers as applicable.

F-RG04 defines evidence classes in `integration/f-rg/F-RG04_EVIDENCE_CLASSIFICATION.json`. The classes classify evidence strength and purpose. They do not create parallel technical authorities.

## 3. Qualification is not admission

The normal production-facing chain is:

1. evidence is assembled and pinned;
2. a bounded qualification object and claim are declared;
3. owner verification/qualification is completed where applicable;
4. any required independent F-VQ or other mandated assurance is completed;
5. the exact candidate head is immutable for the applicable review;
6. F-CI reconciles the candidate against the then-current canonical and performs serialized admission;
7. postimage/preservation evidence is established where required.

A local PASS cannot call itself production authority unless the existing SWAP5 admission rules already grant that authority. `OWNER_QUALIFIED`, `INDEPENDENTLY_QUALIFIED`, `CANONICAL_ADMITTED` and `PRESERVED_REGRESSION_PROTECTED` remain distinct maturity states under F-RG01C.

A stale qualification remains valid evidence at its pinned scope and source identity, but cannot be admitted to a newer canonical without the applicable current-canonical reconciliation.

## 4. Bounded qualification objects

Every material qualification names exactly what it qualifies. Object kinds include equation/process-law claims, process contracts, solver behavior, boundary conditions, state variables, transaction properties, conservation properties, coupling properties, module/sub-capabilities, composed capabilities and complete v1 domains.

The bounded object records:

- unique object id and kind;
- claim text and explicit non-claims;
- parent/child relation if any;
- source/candidate identity;
- semantic contracts owned/consumed;
- scientific, numerical, conservation, state/restart, transaction, coupling and runtime surfaces that are in scope or explicitly not applicable;
- evidence references and uncertainty labels;
- required assurance and admission route.

Evidence or qualification for a smaller object cannot be promoted to a larger object by naming convention, aggregation, branch ancestry or shared implementation alone.

## 5. Parent, child and composition governance

The following implications are forbidden unless separately proved:

`child-qualified -> parent-qualified`

`all-children-qualified -> parent-qualified`

`parent-qualified -> whole-domain-complete`

`domain-complete -> whole-program-complete`

A composition authority must explicitly evaluate at least:

- coverage and missing children;
- overlap and double counting;
- contradictory semantics;
- shared-state interactions;
- water/mass/conservation interactions;
- temporal ordering and interval interactions;
- failure/retry/rollback/commit interactions;
- restart/persistence interactions;
- runtime/coupler composition;
- numerical-policy interactions where relevant;
- production blast radius and unresolved uncertainty.

All children may PASS while composition FAILS or remains unproved. A composition PASS has only the scope of the declared composed object and does not imply complete domain or program readiness.

## 6. Negative qualification is first-class

A scientifically valid workunit need not end in positive implementation or admission. F-RG04 recognizes bounded outcomes including:

- `QUALIFIED_POSITIVE`;
- `QUALIFIED_NEGATIVE`;
- `BLOCKED_BY_EVIDENCE`;
- `NOT_SCIENTIFICALLY_DEFENSIBLE`;
- `HISTORICAL_BEHAVIOR_UNKNOWN`;
- `OUTSIDE_CURRENT_SCOPE`.

A negative result is closed knowledge when its claim, evidence and assurance are adequate. It may reject a hypothesis, close an invalid proposed process law, establish that historical behavior is not reconstructable from available evidence, or block/reroute downstream work. It never fabricates a production capability and never changes a F-RG01C completion fraction unless a separate completion-model authority explicitly defines such credit.

No weak physics, synthetic historical story or under-supported correction may be introduced merely to obtain a green workunit.

ANIMO SQ06 and SQ07 are evidence that a negative scientific workunit can close cleanly; their TCD naming and B3 lifecycle are not imported into SWAP5.

## 7. Scientific uncertainty labels

F-RG04 uses a compact orthogonal vocabulary rather than replacing existing maturity labels:

- `KNOWN_FROM_FROZEN_SOURCE`: directly pinned to immutable source.
- `CONFIRMED_BY_REFERENCE_BEHAVIOR`: observed in qualified reference behavior at the declared scope.
- `RECONSTRUCTED_NOT_HISTORICAL`: reconstructed evidence is useful but does not establish historical truth.
- `SCIENTIFICALLY_QUALIFIED`: scientific claim passed its declared scientific qualification route.
- `NUMERICALLY_QUALIFIED`: numerical behavior passed its declared numerical qualification route.
- `HISTORICAL_BEHAVIOR_UNKNOWN`: available evidence does not justify a historical behavior claim.
- `PROCESS_SEMANTICS_UNRESOLVED`: bounded process semantics remain unresolved.
- `RESEARCH_ONLY`: evidence/claim is confined to research authority.
- `PRODUCTION_ADMITTED`: only when an existing F-CI/canonical admission authority actually establishes that fact.

These labels describe epistemic state. They do not replace F-RG01C maturity or F-RG01A research maturity.

## 8. Review assurance and independence

Assurance is machine-readable and must be stated honestly. F-RG04 distinguishes:

- `OWNER_VERIFIED`;
- `PROCESS_SELF_REVIEWED_NOT_INDEPENDENT`;
- `ADVERSARIALLY_SELF_REVIEWED_NOT_INDEPENDENT`;
- `INDEPENDENTLY_QUALIFIED`.

A same-agent or same-context review is never called independent. ANIMO GOV05 is adopted only for the immutable adversarial-review discipline and explicit reduced-assurance labeling. It does not weaken SWAP5 F-VQ.

Where an existing SWAP5 rule requires independent F-VQ, F-VQ remains mandatory. Same-agent adversarial review can be additional assurance but cannot satisfy that gate. Low-risk governance/documentation-only changes may use self-review when no independent gate is already mandated and the change cannot alter production semantics, scientific equations/process laws, solver/numerical policy, state/restart semantics, transaction/mass semantics, coupling semantics or production admission.

## 9. Immutable adversarial review boundary

For work requiring adversarial self-review, the sequence is:

`authoring complete -> persist -> freeze immutable review head -> exact-head CI of authoring package -> adversarial inspection -> findings -> remediation if required -> new immutable head after substantive change -> re-run affected/full review -> final exact-head CI`.

The review artifact identifies the reviewed head. After review, only non-substantive closeout metadata/review records may be added without invalidating that reviewed head. Any change to policy semantics, schemas, authority mappings, validator logic that guards substantive semantics, or claim scope creates a new review head and requires re-review of affected gates. This prevents a green review from being reused after the object has changed.

## 10. SWAP-specific risk-tiered review

Risk tier allocates review intensity. It never overrides existing hard gates or independent qualification requirements. The strictest applicable trigger wins.

- `R0_GOVERNANCE_DOCUMENTATION`: documentation/governance metadata only, no production semantics, denominator, authority promotion or Status-A claim. Owner verification plus exact-head CI and adversarial self-review may suffice unless another authority requires more.
- `R1_BOUNDED_NONPRODUCTION`: research-only or bounded nonproduction evidence/contract work with no production semantic mutation. Owner qualification plus adversarial review; independent review is required whenever existing solver/research contract governance says so.
- `R2_PRODUCTION_LOCAL`: bounded production behavior or local physical/numerical change. Existing owner qualification and applicable independent F-VQ remain mandatory before admission.
- `R3_STATE_CONSERVATION_TRANSACTION`: state/restart, hard conservation, transaction lifecycle, solver/numerical acceptance or failure-policy changes. Full fail-closed independent qualification is mandatory; targeted reuse only with immutable compatible pins.
- `R4_COMPOSITION_COUPLING_PRODUCTION`: cross-module composition, groundwater/coupler composition, production-scale runtime policy, whole-domain claims or production-bound multi-capability composition. Requires composition qualification, applicable independent qualification, serialized F-CI admission and postimage/preservation evidence.

A low tier cannot waive a gate imposed by the nature of the object. A change that crosses a higher-risk trigger escalates automatically.

## 11. Review failure and remediation

Findings are classified as:

- `SCIENTIFIC_FALSIFICATION`;
- `EVIDENCE_INSUFFICIENCY`;
- `PROVENANCE_INSUFFICIENCY`;
- `TOOLING_VALIDATOR_FAILURE`;
- `SCOPE_AMBIGUITY`;
- `COMPOSITION_FAILURE`;
- `AUTHORITY_PROMOTION_FAILURE`.

Scientific falsification, changed claim scope, changed process semantics or changed composition semantics require substantive reassessment. Evidence/provenance/tooling defects may use targeted remediation only if reused PASS gates remain immutable, scope-compatible and unsuperseded. A validator PASS confirms the encoded governance contract; it never by itself proves the scientific claim.

## 12. Provenance and replay

Provenance/replay classes are defined in `F-RG04_PROVENANCE_REPLAY_RULES.json`:

- `SOURCE_PROVENANCE`;
- `BEHAVIORAL_REPLAY`;
- `RECONSTRUCTED_REPLAY`;
- `SYNTHETIC_ORACLE`;
- `PRODUCTION_REGRESSION`.

`RECONSTRUCTED_REPLAY` cannot be described as historical truth without an independent historical source that supports that promotion. Synthetic/oracle evidence establishes only the declared invariant, causality or boundary behavior. Production regression proves preservation against its pinned baseline/oracle, not universal scientific validity.

Evidence reuse follows `VERIFY_AND_REUSE`: verify immutable identity, unchanged scope and absence of superseding contradiction before reuse. Reuse preserves evidence strength and cannot promote reconstructed to historical, research to production, owner verification to independent qualification, or local qualification to composition authority.

## 13. Admission serialization

Scientific, implementation and evidence work may proceed in parallel where F-RG01A says contract ownership is disjoint. Shared program/canonical authority is serialized:

- F-CI admissions are serialized against then-current canonical.
- Required postimage and moving-current preservation/reconciliation are serialized.
- A candidate qualified against an older canonical must reconcile before admission.
- Parallel work cannot reserve future canonical authority.
- Admission is atomic for the bounded object; aggregate reporting or program rebaseline happens later under F-RG03 unless the admission changes a program gate that requires immediate rebaseline.

## 14. Research maturity protection

F-RG04 does not alter F-RG01A research maturity. RossFast remains research-scoped until a separate production admission authority exists. Its research evidence, including qualified bounded sensitivities or adapters, cannot leak into production authority by being referenced from a production workunit.

Energy-balance research remains outside the frozen v1 denominator under the current F-RG01C model. Evidence may mature independently but contributes no v1 completion credit and receives no production admission through F-RG04.

## 15. F-RG01C completion-model protection

F-RG04 is deliberately orthogonal to completion scoring. It changes no denominator, domain weight, capability weight, maturity credit profile, completion fraction, special Status-A ratio or hard ceiling. Negative qualification is epistemic closure, not numerical program credit.

Any future change to completion scoring requires a separately qualified F-RG01C model-version authority. F-RG04 must not be cited as implicit authorization for a scoring change.

## 16. F-RG01D module-contract bridge

A schema-conforming module manifest may optionally index, where relevant:

- evidence classes consumed;
- scientific qualification authority;
- numerical qualification authority;
- assurance level;
- historical provenance/uncertainty labels;
- child capability authorities;
- composition authority;
- production admission authority;
- preservation evidence;
- unresolved uncertainty/findings.

The manifest is an index. Detailed equations live in theory/process authority, implementation truth lives in source/contracts, evidence truth lives in pinned evidence artifacts, qualification truth lives in qualification authorities, and production authority lives in admission/preservation authorities. The manifest must never manufacture or override any of them.

## 17. Documentation bridge

The governed chain is:

`theory <-> conceptual model <-> equations/process semantics <-> software contract <-> implementation <-> evidence <-> qualification <-> admission`.

Discrepancies are classified rather than papered over: documentation error, code/implementation error, historical deviation, provenance uncertainty, unresolved scientific semantics, numerical discrepancy or composition discrepancy. Documentation can describe and reconcile authority but cannot retrospectively create unproved physics or production authority.

## 18. Authority promotion rules

Authority promotion is explicit and bounded:

- evidence does not promote itself;
- owner PASS does not imply independent PASS;
- scientific PASS does not imply numerical PASS;
- numerical PASS does not imply scientific PASS;
- qualification does not imply admission;
- child PASS does not imply parent PASS;
- all children PASS does not imply composition PASS;
- local admission does not imply aggregate completeness;
- aggregate snapshot does not imply composition completeness;
- composition completeness does not imply production authority;
- production admission does not imply permanent preservation until the required preservation authority exists;
- research authority never promotes to production by reference alone.

## 19. Prospective application and legacy authorities

F-RG04 is prospective. Existing qualified SWAP5 authorities retain their original scope and strength. They are not downgraded merely because they predate F-RG04 or lack its metadata fields. When an old authority is consumed by new work, the consumer maps it to the F-RG04 vocabulary without rewriting historical records.

Contradictory new evidence must be handled explicitly and fail closed; it does not silently invalidate or silently override the prior authority.

## 20. Cross-project lessons disposition

Adopted/adapted ANIMO lessons are recorded in `F-RG04_ANIMO_LESSON_MAPPING.json`. ANIMO-specific lifecycle constructs such as B0-B4 gates, TCD numbering/class taxonomy and ANIMO central-RG batching mechanics are not imported. SWAP keeps F-RG, F-VQ, F-CI, F-TB, F-DOC, module-contract and current-canonical conventions.

## 21. Exit rule

F-RG04 may close as `QUALIFIED_SWAP5_SCIENTIFIC_EVIDENCE_QUALIFICATION_ADMISSION_COMPOSITION_AND_ASSURANCE_GOVERNANCE` only when:

- all machine-readable artifacts validate;
- F-RG01A/B/C/D and F-RG03 are preserved;
- the F-RG01C denominator and weights are unchanged;
- source/reference production trees are unchanged from the authoring base;
- no F-CI/F-VQ production authority is created by F-RG04;
- evidence/qualification/admission/composition distinctions are fail-closed;
- negative qualification is explicitly non-credit-bearing unless separately defined;
- same-agent review is labeled non-independent;
- the 15 adversarial counter-hypotheses are tested against an immutable authoring head;
- any substantive remediation creates a new reviewed head;
- exact-final-head CI is green.
