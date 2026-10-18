# Native historical material positions and disabled crop diagnostics

Status: implementation contract after canonical PR1316 admission; not qualified.
Baseline is1e8bf36ec52544e50f5b2720031228f9a6369525. Full HIST remains open.

Original management_soil119..126 reads material definitions into positional
property arrays. Its129..132 event read overwrites the same MatNum array with
iMat. Original wofost_soilamendents then uses MatNum(event) directly as the
property-array position. Definition labels are therefore validated integers1..20,
but neither lookup keys nor uniqueness constraints. The existing source-followup
witness compiles the original reader slices and complete original amendment
routine: contiguous, noncontiguous, reversed and duplicate definition labels
produce the same positional mineral application at O0/O2. Its raw evidence is
in the admitted humus retained capsule, explicitly source evidence only.

Remove only the native reader's accidental contiguous-label restriction. Validate
every original definition label against its source range and physical source line,
then normalize its row to its position before the existing amendment-table reader.
Keep event positions within the actually defined property array; reject uninitialized
or out-of-bounds source accesses. Do not change modern export identifiers, material
properties, event sorting/grouping, doses or Soil-N application physics.

Original management_soil249..251 defaults flCropExt to false and optionally reads
it with RDSLOG. Admit explicit native .false. case-insensitively with the existing
disabled diagnostics semantics. No state/vector/schema is needed for a disabled
output option. Explicit true is source-valid but remains unsupported until the
historical extended output is implemented; reject it at its physical source line.
Malformed, duplicate and contradictory options remain atomic errors. Modern
export must not silently gain this native logical field.

Extend the independent source witness to execute unmodified TTUTIL RDSLOG and the
original default/read statements, including source true versus intentionally
unsupported new true. The native matrix must prove definition-label permutations,
duplicates, source bounds, positional property selection in both tables and arrays,
explicit disabled flags and rejection/source lines. Existing38 fixtures stay selected.

For physical integration, use noncontiguous definition labels and explicit false
only in the existing730-day humus profile; all material/event properties remain
identical. Its exact previously admitted endpoint must remain unchanged, alongside
the other profiles, all36 fresh processes and rejected-state bytes. No extra crop
or chemical implementation is introduced. Source124 and current owning admission
checks remain required. Preserve independently unchanged small material/reactive/
mineral/source-clock and export evidence only with full input identity; reexecute
the affected actual production/retained closure and its required preservation.
RossFast, reference files, numerical policy and mastercoverage are unchanged.

Affected invariants are1..4,7,9,11,13,21..23,25,26,28..30. This closes two bounded
native-input gaps. It does not admit all TTUTIL constructs, true extended output,
fractional timestamps, the original unsafe event indices or gross ponding N semantics.
