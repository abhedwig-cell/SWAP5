# PPA MvG residual experiment

Baseline: f05760c6d8e2daf379814df4415a51dcf6e1c5be.
Workstream: free-drainage small-step residual accuracy; candidate verification only.

Before changing the shared solver ABI, test the already oracle-qualified bound
storage difference in a disposable HeadCalc compilation. The runner mechanically
replaces only the four storage differences in vector_F and asserts the expected
match count. Production source, vertical-flux reconstruction, tolerances, candidate
water contents and transaction/restart ownership remain unchanged. The generated
variant is a numerical experiment, not another admitted production kernel.

The substitution is restricted to explicit fixed-flux top, bottom mode 7, no
macropores, and the exact default MvG provider. Unsupported/locality failures retain
the original rounded subtraction; they do not repair inconsistent base water.
Each residual evaluation uses one atomic vector binding evaluation.

Replay the existing 20-step halving sweep with bounds/FPE checks at O0 and O2.
For each converged attempt check the native residual and independently compute
sum(theta_after*dz)-sum(theta_before*dz)+dt*(qtop-qbot), with the unchanged
1e-12 cm ledger gate. Preserve base heads and water exactly. Report failure to
converge honestly: a diagnostic PASS is not whole-sweep convergence.

Affected invariants: 3, 5, 7, 13, 23, 25. No shared interface or canonical admission
change. Local checkpoints only, as requested; remote publication is not in scope.
Implemented/tested status and outcome are recorded in the storage-difference status
record. Next action: persist harness, execute paired default/candidate sweep, then
decide whether a production opt-in interface is justified by the evidence.

## Completed bounded evidence

At fcd24308d the default small-step sweep converges in 14/20 cases; the stable
storage variant converges in 17/20. All converged cases pass both unchanged mass
checks, with identical O0/O2 transcripts within each variant. The two tiniest
steps and the largest step remain rejected. This is not universal convergence.

At fb14bf768 the disposable variant completes and commits the original WU04C
and WU04D two-tile half-day owner cases with the unchanged hard mass gate.
All 94,447 diagnostic lines match between O0/O2, not just PASS markers.
Transcript SHA256 (both builds):
`D583252F96E9BC376DF069C3567835CF348905167C88BDE91F52EFDC77652E6C`.
Build: `swap-ppa-wu01-a0762fd5a462472c9630c48e516d186b` in the local temp directory.
Each WU04C tile uses 2358 accepted substeps, 27126 HeadCalc calls and 286783
nonlinear iterations. This demonstrates completion, not efficient production.

The experiment justifies proceeding with a separately explicit numerical opt-in;
it does not itself introduce it. Shared callback interface design, configuration
forwarding, default-path regression, restart/rebind and accepted source-window
receipt coverage remain subsequent work. Existing user-owned dirty files were
not included in these checkpoints.
