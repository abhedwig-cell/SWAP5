# F-DOC01 parameter and calibration documentation policy

Parameters are documented by scientific meaning and ownership, not by legacy input-file location.

## Parameter record

Each important parameter records:

- stable parameter ID, name and symbol;
- physical/empirical/numerical category;
- unit and dimensional meaning;
- valid/qualified range and default, if one exists;
- parameter owner and applicable physics/options;
- spatial and temporal interpretation;
- source/provenance;
- measurement, calibration, pedotransfer or expert origin;
- uncertainty where known;
- sensitivity evidence where known;
- kernel representation and adapter mapping;
- version and qualification scope.

Categories are `PHYSICAL_PARAMETER`, `EMPIRICAL_PARAMETER`, `CALIBRATION_PARAMETER`, `NUMERICAL_PARAMETER`, `TOLERANCE`, `CONFIGURATION_SWITCH`. Numerical policy and tolerances must not be presented as physical parameters.

## Calibration record

Where calibration applies, document objective/target outputs, calibrated parameters, data authority, method, bounds/priors, loss/objective definition, stopping/selection rule, resulting values, uncertainty if available, transferability limits and affected application classes.

Where no calibration is applicable, record `NOT_APPLICABLE` with rationale rather than an empty field.

## Status A/AA readiness

Unknown ranges, uncertainty and sensitivity are explicit gaps. No synthetic range or uncertainty is introduced to complete documentation. AA-readiness specifically distinguishes evidence-backed parameter ranges/default uncertainty from implementation floating-point precision.
