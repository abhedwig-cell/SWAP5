# F-CI12 Qualification

Qualified source head: `7098aeaa4ca38dc375a965340a35c9870a33de28`.

Canonical GitHub Actions run `34102787767`, job `101681229677`, completed successfully with GNU Fortran 13.3.0 and emitted `FCI12_GATE_PASS`. The complete sequential F-CI03 through F-CI12 dependency chain passed on the same source head.

```text
F-CI11 generic interval source dependency        PINNED / QUALIFIED
F-CI11 unrounded trial-mass dependency           PINNED / QUALIFIED
F-CI09 transaction binding parent                PINNED / UNCHANGED
F-CI12 physical interval executor                TESTED
F-CI12 reference-model advance                   TESTED / DETERMINISTIC LEGACY TESTDOUBLE
F-CI12 qualified-profile storage                 TESTED / DETERMINISTIC LEGACY TESTDOUBLE
Failed-trial state isolation                     PASS
Worker diagnostics projection                    PASS
Raw water temporal characterization              PASS / UNIT-EXPLICIT
Optional process temporal characterization       INCOMPLETE / FAIL CLOSED
Recoverable legacy solver-failure status         NOT ADMITTED
Scalar temporal error metric/tolerance            NOT ADMITTED
execute_reference_interval on B1.10              NOT ADMITTED
Real B1.10 end-to-end through F-CI12 model        NOT YET QUALIFIED
Canonical GitHub Actions                         PASS
```

The F-CI12 executable test uses a deterministic legacy testdouble to qualify the new production binding and transaction semantics. It is deliberately not presented as a new hydrological-regression run. The source-bound physical evidence for arbitrary intervals and hard mass conservation remains the qualified F-CI11 Hupsel evidence.

The important new result is architectural: a successful qualified-profile physical trial can now be represented through the transaction-model API with an explicit generic interval, worker-owned execution context, unrounded mass in/out, storage projection and state-isolated failure path. However, production reference execution is still fail-closed because legacy solver failure is not yet exposed as a qualified recoverable status, and no scalar temporal-error acceptance policy has been admitted.

No solver physics, Jacobian, constitutive relation, physical option, mass tolerance or calendar-event rule changes in F-CI12.
