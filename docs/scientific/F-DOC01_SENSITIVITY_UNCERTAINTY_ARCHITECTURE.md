# F-DOC01 sensitivity and uncertainty architecture

Sensitivity and uncertainty are separate evidence dimensions and are indexed by capability, output and application class.

## Sensitivity classes

- `PARAMETER_SENSITIVITY`
- `NUMERICAL_SENSITIVITY`
- `FORCING_SENSITIVITY`
- `STRUCTURAL_SENSITIVITY`

Each study records method, varied quantities/ranges, held-fixed assumptions, target outputs, scenario/application class, model/source version, metrics and interpretation.

## Uncertainty classes

- `FORCING_INPUT_UNCERTAINTY`
- `PARAMETER_UNCERTAINTY`
- `STRUCTURAL_UNCERTAINTY`
- `MODEL_FORM_UNCERTAINTY`
- `NUMERICAL_UNCERTAINTY`
- `OUTPUT_UNCERTAINTY`
- `UNKNOWN_OR_UNQUANTIFIED_UNCERTAINTY`

## Evidence levels

`QUALITATIVE` identifies sources, direction/mechanism where known and implications. `QUANTITATIVE` propagates defensibly quantified uncertainties to relevant outputs with a documented method. They are not interchangeable.

A model-wide statement is only permitted if coverage is explicitly defined. Otherwise evidence is scoped to component, parameter set, climate/soil class, application class and output.

## AA readiness

The architecture supports recurring protocol/version fields from the start: `protocol_id`, `trigger_on_change`, `last_evaluated_release`, `coverage`, `known_gaps`. F-DOC01 generates no fictitious sensitivity or uncertainty results. Missing analyses remain evidence gaps.
