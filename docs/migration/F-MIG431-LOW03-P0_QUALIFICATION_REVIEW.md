# LOW03-P0 bounded solver qualification review

Status: qualified shared solver candidate, not yet canonically admitted; full SWBOTB3 application remains unadmitted.

## Contract and exact postimage

The concrete typed contract was persisted at `2b523d818c5c5135d466495b31c5b20ae29b79be` before production implementation. It explicitly selects direct typed Reference SWKIMPL0 only; it does not silently substitute component tests for full application gates in the original preregistration. The latter remain mandatory before LOW03-A application admission. Qualified postimage: `3407286de38d8d11219678257874afd3c44320a7`; canonical reconcile base: `0d44f0195c94a9732c67b5e77f2148912df9bbc8`.

The only production changes are the internal typed boundary fields/helper, direct Reference validation/candidate mass publication, and typed bottom-row residual/Jacobian in HeadCalc. No public C ABI, production profile allowlist, proposal owner, transaction ledger, restart format, aquifer datum or groundwater coupling owner changes. Other selectors require the new fields at defaults. RossFast still rejects mode3 and no new mode3 directional service is admitted.

## Completed evidence

Run [36970096511](https://github.com/abhedwig-cell/SWAP5/actions/runs/36970096511), job110722079851, passes at exact postimage. Downloaded artifact11210724958 SHA256 `644ac6e537768eb29ea603613348a89c6fc15567964632d73dd6dfd0cc938458` matches the GitHub digest; both JSON members equal fresh local results in full, including inputs and marker outputs. All143 relevant Git blobs were verified; the second postimage changes only the typed solver test and workflow comment relative to the first qualified run. The evidence JSON retains hashes, complete markers, previous diagnostics and dependency boundaries.

At each O0/O2:6075 frozen B1.11 production-helper flux/Jacobian cases,225 same-K zero-R limits and810 nonzero-R nonaliases;45 eight-node homogeneous bare MvG physical cases with capillary/drainage/zero head drives, independent extra flux, both resistance flags and R0/10/100 where nonsingular. Independent finite-volume compartment and whole-profile integrated mass amount gates are1e-12cm. Physical qbot is checked against the bottom law, not overwritten by storage closure. Three zero-R full-solver mode5 limits pass. Fresh-workspace replay and rejected-trial replay preserve base state. Physical checkpoint reconstruction gives bit-identical next direct solve. Seven programs per optimization pass, including the six admitted-mode application preservation suites for2/internal-2,4,ordinary5/defaultGW5,6,7; LOW05 private progress remains43 accepted substeps and348 retries.

## Mandatory gate allocation and nonclaims

P0 qualifies solver candidates and equation-balance publication only. Resistance/head/extra flux are immutable caller-supplied trial values; no P0 proposal sampling or application time law exists to qualify. The original full application gates (source-bound proposal sampling, opaque kernel accept/commit, exactly-once accepted integrated accounting, rollback after private progress, production restart with frozen forcing) remain mandatory for LOW03-A. The physical restart test uses the existing committed-state factory/persistence but does not fabricate an opaque accepted candidate or claim a mode3 production transaction test. Application/profile mode3 remains fail-closed. SWKIMPL1, macropores, sensitivity, explicit3 and broader convergence domains remain deferred.

The first fixtures left head-relative tolerance at its default0 and rejected; a same-fixture baseline5 also rejected at residual floor. Evidence is retained. The corrected test sets the existing numerical criterion explicitly, not a new controller or relaxed mass tolerance. Initial short-step convergence is not established by the corrected dt0.125 test. Adjacent A26 run36969681183 fails because its legacy compile list omits the existing q(gwl) module; it is not repaired here and no global CI-green claim is made.

## Admission recommendation

Admit only the shared direct typed resistive-head solver seam under the concrete preimplementation contract and this bounded evidence. Full SWBOTB3 stays open until LOW03-A forcing/binding/transaction qualification. SWBOTB1 remains parked; active order remains3 then8. Do not describe this as complete lower-boundary migration.
