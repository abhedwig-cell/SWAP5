# F-PE-REPRO02 R4 result — legacy-context binding A/B

Date: 2026-09-26

Status: `CONTEXT_BINDING_NOT_CAUSAL`

## Result

The successful P0 direct request was run with and without:

`bind_b110_serialized_legacy_context(request, ok)`

Across six difficult origins and offsets -0.001, 0 and +0.001 cm:

- DIRECT: 18/18 converged;
- BOUND: 18/18 converged.

Per-point nonlinear and backtracking counts were identical between the two arms.

## Conclusion

Copying the explicit request into legacy globals is not itself the participant/direct divergence.

## Next request differences

Two boundary-carrier fields still differ between P0 and the serialized FGC44 forcing even though bottom mode 5 prescribes head:

- P0 direct request leaves `boundary%bottom_flux = 0`;
- FGC44 base forcing carries the predictor qbot value into `boundary%bottom_flux`.

Also:

- P0 leaves `boundary%top_head = 0`;
- FGC44 carries h0 in `boundary%top_head` despite explicit-flux top mode.

R5 isolates these two carrier differences.
