# TRACE capture checklist

Use this sequence for every newly observed potential scientific inconsistency.

1. **REGISTER**  
   Allocate the next model-specific TRACE ID and add the candidate row immediately.

2. **FREEZE**  
   Preserve the exact pre-resolution repository ref plus the relevant theory, documentation, implementation, existing tests, inputs and observed outputs. Create an evidence manifest.

3. **REGISTER THE DENOMINATOR**  
   Ensure the inspected scientific element exists in `TRACE_SCIENTIFIC_ELEMENT_REGISTER.csv`, including elements that ultimately show no discrepancy.

4. **DECIDE ELIGIBILITY**  
   A case is prospectively eligible only when neither the substantive discrepancy nor its disposition was known before registration.

5. **REPLAY EXISTING REGRESSION**  
   Run only evidence that pre-dated discovery. Do not add the new oracle first.

6. **GATHER INDEPENDENT EVIDENCE**  
   Derivation, invariant, differential implementation, metamorphic relation, benchmark or other independent evidence as appropriate.

7. **CLASSIFY**  
   Use preregistered relation classes. Mechanism remains open-coded.

8. **ADJUDICATE**  
   Record competing authorities and why the final disposition follows. Unresolved is an allowed outcome.

9. **REPAIR OR PRESERVE**  
   Only after pre-resolution evidence is frozen.

10. **QUALIFY AND CLOSE**  
    Preserve post-resolution evidence, update the case file and registers, and run `python tools/validate_trace_registry.py`.

Known pre-freeze discrepancies go only to `TRACE_HISTORICAL_PILOT_REGISTER.csv`.
