# F-CI08 — Physical Process Continuation State

F-CI08 completes the first source-bound separation between **persistent physical/process continuation state** and **worker-local legacy trial context** for the controlled B1.10 port.

## Persistent per logical column

Only data required to continue physical evolution is admitted. The water checkpoint is extended with optional blocks for soil temperature, solute, irrigation continuation, crop continuation and WOFOST. These blocks allocate only when the corresponding physics is active. Crop state includes `rdpot`, because the B1.10 root-extension path can build the next potential rooting depth from its previous value.

WOFOST state is preserved whenever the current crop is a WOFOST crop, including before emergence. This prevents a rejected attempt that crosses emergence from losing continuation state.

## Worker-local rollback context

Time projection, numerical timestep control, forcing cursors, output/reporting progress, intermediate and cumulative accounting, thermal forcing positions, irrigation event workspace, and the mutable irrigation `schedule` projection remain outside persistent column state.

The replay order is:

1. restore worker-local trial capsule;
2. restore persistent process state;
3. reset worker numerical scratch;
4. rerun the physical interval.

This ordering matters because process-state restore validates active configuration against the optional state being restored.

## Qualification

The exact B1.10 manifest was reverified: 63 Fortran members, 1,863,575 bytes, manifest SHA-256 `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The final F-CI08 process and capsule postimages are Git blobs `4084f979d86e0a97d2b7b570af38ad44d85dca6c` and `46ebc5339e85f69c8a24ab99ba70987f559c817d`. Four Hupsel whole-day boundaries (offsets 499, 520, 760 and 800) were replayed after full restore at both O0 and O2. All eight runs produced an exact maximum process-state difference of zero.

Canonical CI run `34088797066` independently passes F-CI03 through F-CI08, including the exact transaction attempt-context implementation and O0/O2 process/capsule gates.

## Not admitted

F-CI08 does not imply generic sub-day support. In particular, `noddrz_old` is safe to recompute on the current whole-day route but remains an explicit audit item before arbitrary intra-day checkpoints are allowed. F-CI08 also does not yet provide the final canonical B1.10 `transaction_model_t` adapter or complete unrounded accepted-interval mass result.
