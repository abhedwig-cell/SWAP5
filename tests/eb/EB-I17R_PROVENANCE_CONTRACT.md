# EB-I17R Candidate-Bound Energy Provenance Remediation Contract

## Authority and trigger

Base: `work/eb-i17-external-bottom-thermal-binding-implementation@b9517b136bc879c01ad1019a8f0e2e0be72370b6`.

EB-I17 is qualified for compact external donor-temperature storage and fail-closed evaluation, but explicitly does not prove that its caller-supplied binding token belongs to the completed thermal candidate.

This remediation incorporates two later transaction/provenance findings from the SWAP5 runtime line:

1. `F-KT20@c25eb87f979f4c341713de8fdc890beb0ea3e35f` proved that an executor-local candidate sequence can distinguish same-origin sibling candidates inside one execution domain.
2. independent `F-VQ70@f5bd9762cd28fcf71cd8855fd1205374c5e19ae0` rejected that route for production because two live executors can be assigned the same execution-provenance domain and therefore create colliding exact tokens.
3. `F-PM12@82189c148a38b90b6a5a326d03f282ccbee52960` plus independent `F-VQ72@a3c7bf5a60d80b430758f85489b316b5bcbc2fdc` qualified the safer production pattern: materialize candidate-bound information while the candidate is present, retain prepared information only in private local scope, commit that same candidate object, and only then publish from the returned accepted receipt. F-VQ72 explicitly excludes the non-admissible F-KT20 route.

## Frozen remediation rule

The production-admissible bottom-energy path SHALL NOT rely on a caller-created identity token, lineage tuple, origin revision, time interval, hash, random nonce, or runtime execution-domain identifier to prove exact candidate identity.

Instead, exact association is procedural:

1. a transaction executor owns the trial call;
2. the kernel candidate and the matching bottom thermal candidate are obtained in the same transaction call and remain local to that call;
3. external donor temperatures are resolved against that local thermal candidate by one-based sample ordinal only after the sample class and accepted water exchange are known;
4. the sensible-energy evaluation is retained in a private local prepared carrier;
5. the same kernel candidate object is passed directly to the existing F-KT commit authority;
6. only the receipt returned by that commit may be used to construct accepted energy publication;
7. no public API may accept an independently supplied prepared energy result plus an independently supplied commit receipt.

This is the bottom-energy analogue of the independently qualified F-PM12/F-VQ72 candidate-bound publication pattern.

## External donor contract

The runtime/coupler remains the owner of the external donor temperature. It supplies temperature only. It does not supply, override, reconstruct, or rebook bottom water amount.

The accepted EB-I13 `bottom_outward_exchange_native` sample remains the sole water-transfer authority for bottom sensible-energy accounting.

The external source is generic. The kernel and bottom-energy process do not know whether temperature came from MODFLOW, a deep-vadose transfer component, open water, another model, or another runtime composition.

For an external inflow sample the provider must supply one finite donor temperature for that exact accepted sample ordinal under its own scientifically qualified temporal-discretization contract. The SWAP energy evaluator does not infer an external temperature from local soil temperature.

## Optional-energy commit semantics

Under the current restricted-thermal architecture, bottom sensible-energy accounting is diagnostic and does not govern the physical hydrology solve.

Therefore missing, invalid, or incomplete external thermal provenance SHALL NOT retroactively reject or roll back an otherwise valid mass-conserving hydrologic candidate. The physical commit authority remains unchanged.

After an accepted hydrologic commit, the energy publication shall be either:

- complete and available, when every required donor temperature was valid; or
- explicitly incomplete/unavailable with a diagnostic status tied to the accepted transaction.

There is no zero-energy fallback for missing external donor temperature.

If bottom energy later becomes governing thermal physics, that is a new model-evolution boundary and must qualify acceptance semantics separately.

## State, memory and scaling

Prepared thermal/energy data are worker/job-local scratch. They are not persistent SWAP physical state and do not enter restart state.

Inactive columns allocate no bottom-energy provenance state. No global registry of live candidate IDs is introduced. The design therefore preserves compact state, worker-local scratch, MultiSWAP batching and optional-cost scaling.

## Failure and adversarial requirements

The implementation workunit following this contract must prove at least:

- accepted candidate A can publish only energy evaluated in the same transaction call as A;
- a thermal candidate/result retained from sibling candidate B cannot be injected into A's accepted publication path;
- same lineage, same origin revision and same interval sibling candidates remain safe without unique tokens;
- cross-worker or cross-executor candidate data cannot be paired through a public prepared-result/receipt API because that API does not exist;
- retry/reject paths do not leak stale prepared energy into a later accepted candidate;
- retry exhaustion yields no accepted energy publication;
- missing external donor data can coexist with a valid hydrologic commit only as explicit accepted-energy-unavailable diagnostics;
- rejected trials preserve committed physical state exactly;
- energy accounting never performs a second water or mass booking;
- O0 and O2 semantic observations agree.

## Hard nonclaims

EB-I17R does not itself implement accepted energy publication, change production physics, alter mass booking, change restart schema, add a global candidate namespace, admit F-KT20, or claim whole-system energy closure.

The next implementation boundary is an atomic runtime transaction seam following this contract. Accepted energy publication is allowed there because publication safety and exact-candidate association are inseparable for this process provenance.