# Moving pulse accuracy and fresh-process joint disk continuation

Both previously open research gates now pass in the stated domains. Numerical
FCT/dispersion/decay formulas and production source are unchanged from PR1410.

The36 checked O0/O2 pulse runs compare the unchanged research method and actual
production implicit comparator against independent analytical Gaussian cell
averages with advection, mechanical/molecular dispersion, linear sorption and
decay. The corrected mass L1 error is48.2 to94.6percent smaller in all nine
grid/time combinations. On the finest time grid, errors decrease from0.383414
to0.102775 to0.014735mg/cm2 as the grid increases40,80,160cells. Errors also
decrease when time steps are halved at each spatial grid. Maximum mass residual
is2.3707598384437034e-14mg/cm2; O0/O2 numerical output is exact. This is a
linear homogeneous fixed-water analytical pulse qualification, not a general
nonlinear/full Richards spatial convergence result.

The24 O0/O2 water/reactive disk cases execute150 separate native processes.
Every resumed endpoint payload is byte-identical to uninterrupted execution,
and continued per-window ledgers match exactly. Existing production joint disk
I/O retains water fields, derivative history, clock, revision, lineage and both
chemical stores after physical validation. An external research envelope binds
the exact method-source identity and constant fixture context to the complete
payload. It prevents unintended automatic cross-policy/context continuation.

All96 wrong/damaged envelope requests and72 native wrong-parameter/CRC/physical
equilibrium corruptions reject. The last corruption has a valid recomputed CRC,
so rejection exercises physical validation rather than checksum rejection alone.
Both native restore targets remain uninitialized on rejected reads.

Four separate publisher processes are killed before/after atomic replacement.
The complete previous/new generation remains authoritative as appropriate;
fresh processes recover each and reach exactly the uninterrupted endpoint and
remaining ledgers. Publication uses file fsync, same-directory atomic replace
and directory fsync. This qualifies the tested POSIX process-crash boundary;
hardware power failure, cross-platform encoding and concurrent writers are
outside the proof. Uncommitted pending files are not recovery authority.

The complete selected execution cost is108.264seconds. The proof retains the
initial pulse run, full current raw executions and all relevant binary state
artifacts. A validator initially classified disk builds incorrectly because
the evidence-root name contained `pulse-`; the failure and original validator
are reproduced and retained. The corrected validator selects the immediate
build directory, with source/command and physical assertions intact.

Current composed scientific owner+156 controls, the frozen reactive proof+8
controls and8 new source/raw controls pass. No production dispatch/default or
whole MC-SOL01/master capability is promoted. Root/drainage sink composition,
wider nonlinear pulse accuracy and an explicit production application binding
remain separate gates. Actual canonical admission is recorded separately.

Run `python integration/mc-sol01/fct_pulse_restart/verify.py --self-test`.

Canonical `247b9f5b` adds only four unrelated status/admission paths after the
execution base. All190 qualified inputs and five generated sources remain
exact. On the composed tree the capsule+8 controls and current owner+156
controls pass; `CURRENT_RECONCILIATION.json` preserves the identities.
