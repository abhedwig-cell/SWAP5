# F-CI12 Qualification

Initial persisted qualification state before canonical CI.

```text
F-CI11 generic interval source dependency        PINNED / QUALIFIED
F-CI11 unrounded trial-mass dependency           PINNED / QUALIFIED
F-CI09 transaction binding parent                PINNED / UNCHANGED
F-CI12 physical interval executor                MATERIALIZED
F-CI12 reference-model advance                   LOCAL TESTDOUBLE PASS
F-CI12 qualified-profile storage                 LOCAL TESTDOUBLE PASS
Failed-trial state isolation                     LOCAL TESTDOUBLE PASS
Worker diagnostics projection                    LOCAL TESTDOUBLE PASS
Raw water temporal characterization              LOCAL TESTDOUBLE PASS
Optional process temporal characterization       INCOMPLETE / FAIL CLOSED
Recoverable legacy solver-failure status         NOT ADMITTED
Scalar temporal error metric/tolerance            NOT ADMITTED
execute_reference_interval on B1.10              NOT ADMITTED
Real B1.10 end-to-end through F-CI12 model        NOT YET QUALIFIED
Canonical GitHub Actions                         PENDING
```

The local testdouble result is a binding/transaction-semantics check only. It is not substituted for the existing F-CI11 source-bound Hupsel qualification and is not claimed as new physical-regression evidence.

No solver physics, Jacobian, constitutive relation, physical option, mass tolerance or calendar-event rule changes in F-CI12.
