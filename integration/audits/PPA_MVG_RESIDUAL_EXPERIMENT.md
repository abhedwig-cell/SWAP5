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
