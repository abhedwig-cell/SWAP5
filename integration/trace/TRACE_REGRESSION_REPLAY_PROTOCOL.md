# TRACE regression replay protocol v0.1

Purpose: determine whether evidence already present before discrepancy discovery would itself have exposed a confirmed case.

For every technically replayable confirmed case:

1. identify the latest relevant pre-resolution commit;
2. reconstruct the environment sufficiently to execute the relevant existing suite;
3. identify tests/preservation gates that existed before first observation;
4. freeze that suite without adding TRACE-specific or post-discovery assertions;
5. establish whether the affected execution route lies within meaningful suite scope;
6. execute and preserve command, environment, logs and exit/result;
7. classify:
   - REGRESSION_DETECTED
   - REGRESSION_MISSED
   - REGRESSION_NOT_APPLICABLE
   - COUNTERFACTUAL_NOT_RECONSTRUCTABLE
8. only after that classification, execute the independent scientific/executable evidence used to resolve the case;
9. preserve both evidence streams.

A historical gate that fails only because a later legitimate successor violates a frozen source/blob identity is not automatically evidence that the underlying scientific discrepancy was regression-detected. The failure must causally expose the discrepancy under study.

A passing suite is not a regression miss when the affected route, state or application envelope was outside its meaningful scope.
