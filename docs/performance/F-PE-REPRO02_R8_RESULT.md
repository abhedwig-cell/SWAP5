# F-PE-REPRO02 R8 result — predictor-history contamination

Date: 2026-09-26

Status: `PREDICTOR_PROCESS_HISTORY_NOT_CAUSAL`

## Protocol

Six difficult PROFILE06 origins were tested at -0.001, 0 and +0.001 cm.

Two arms used an identical mode-5 corrector request and a fresh corrector solver/workspace:

- CLEAN: execute the corrector directly after binding its serialized legacy context;
- AFTER_PREDICTOR: first execute a predictor-like mode-2 solve in the same process with a separate predictor solver/workspace, then rebind and execute the unchanged mode-5 corrector.

Three fresh-process repetitions were used per point and arm.

## Result

Both arms converged at all 18 points:

- CLEAN: 18/18;
- AFTER_PREDICTOR: 18/18.

There were zero changed points.

Nonlinear and backtracking signatures were identical between arms for every case and offset.

Examples:

- B01 wet +0.001 cm: 3 nonlinear / 4 backtracking in both arms;
- B12 wet +/-0.001 cm: 2 / 2 in both arms;
- O14 mid -0.001 cm: 4 / 5 in both arms;
- every zero displacement: 1 / 1 in both arms.

## Conclusion

A preceding predictor-like physical solve in the same process does not contaminate a later corrector solve.

The participant/direct divergence therefore cannot be explained by simple predictor-to-corrector leakage through the process-global legacy context.

Together with R7, the physically explicit corrector request, provider evaluations, fresh workspace and simple process history are now excluded.

The next discriminator must separate:

1. a serialized Reference physical advance outside canonical retry orchestration;
2. the same serialized backend executed through canonical transaction/retry machinery.

The existing serialized backend reference-floor path is suitable for this distinction because it uses the same serialized physical model while bypassing the normal whole-window canonical retry/temporal path.

No production source change is implied by R8.
