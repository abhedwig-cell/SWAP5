# F-VQ33 execution order

1. Reconcile candidate and handoff identities.
2. Verify matrix disjointness against prior authoritative matrices.
3. Persist source-lock and test implementation state.
4. Commit before compilation or executable qualification.
5. Run O0 qualification.
6. Run O2 qualification.
7. Compare O0/O2 outputs exactly where specified.
8. Run source-locked regressions.
9. Persist evidence and invariant audit.
10. Close only if all gates pass.

No qualification case may be used to tune a production budget or fit a factor.
