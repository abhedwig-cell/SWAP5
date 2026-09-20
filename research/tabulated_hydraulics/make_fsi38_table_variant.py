#!/usr/bin/env python3
"""Create a research-only table-provider variant of canonical F-SI38.

The physical/numerical F-SI38 matrix and independent Neumann oracle remain
unchanged. Only the constitutive provider and temporal-indicator dispatch are
replaced:
- canonical default MvG provider -> generated bounds-safe raw-head provider;
- concrete solver temporal dispatch -> already-qualified generic research
  indicator function.

This does not alter canonical source or F-SI38 acceptance tolerances.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: make_fsi38_table_variant.py CANONICAL_TEST OUTPUT")

s=Path(sys.argv[1]).read_text()

# Add research provider + already-qualified generic indicator.
anchor="""  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
"""
replacement="""  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, &
       initialize_tabhyd_raw_provider_from_mvg
  use mod_reference_richards_temporal_indicator_generic_research, only: &
       evaluate_reference_richards_temporal_indicator_generic
"""
if s.count(anchor) != 1:
    raise SystemExit(f"provider use anchor mismatch: {s.count(anchor)}")
s=s.replace(anchor,replacement,1)

s=s.replace(
    "program test_fsi38_prescribed_qbot_temporal_certificate",
    "program tabhyd_fsi38_table_temporal_certificate",
    1)
s=s.replace(
    "end program test_fsi38_prescribed_qbot_temporal_certificate",
    "end program tabhyd_fsi38_table_temporal_certificate",
    1)

decl="""    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
"""
repl="""    type(tabhyd_raw_provider_t), target :: constitutive
"""
if s.count(decl) != 1:
    raise SystemExit(f"provider declaration mismatch: {s.count(decl)}")
s=s.replace(decl,repl,1)

init="""    call configure_parameters(parameters, cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, step_dt)
"""
repl="""    call configure_parameters(parameters, cofgen)
    call initialize_tabhyd_raw_provider_from_mvg(constitutive, cofgen, step_dt)
"""
if s.count(init) != 1:
    raise SystemExit(f"provider initialization mismatch: {s.count(init)}")
s=s.replace(init,repl,1)

# The generic indicator uses unchanged F-SI38 mathematics and independent oracle.
old="""    call solver%evaluate_temporal_indicator(request, result, indicator_request, workspace, indicator)
"""
new="""    call evaluate_reference_richards_temporal_indicator_generic(request, result, indicator_request, indicator)
"""
if s.count(old) != 1:
    raise SystemExit(f"indicator call mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    call solver%evaluate_temporal_indicator(unsupported_request, result, indicator_request, workspace, unsupported)
"""
new="""    call evaluate_reference_richards_temporal_indicator_generic(unsupported_request, result, indicator_request, unsupported)
"""
if s.count(old) != 1:
    raise SystemExit(f"unsupported indicator call mismatch: {s.count(old)}")
s=s.replace(old,new,1)

# Rename public evidence markers so canonical F-SI38 and table evidence cannot be confused.
s=s.replace("FSI38_MODE2_ROW", "TABHYD_FSI38_TABLE_ROW")
s=s.replace("FSI38_MODE2_CASES=", "TABHYD_FSI38_TABLE_MODE2_CASES=")
s=s.replace("FSI38_WRONG_DIRICHLET_SEPARATIONS=", "TABHYD_FSI38_TABLE_WRONG_DIRICHLET_SEPARATIONS=")
s=s.replace("FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS", "TABHYD_FSI38_TABLE_TEMPORAL_CERTIFICATE=PASS")
s=s.replace("FSI38_FAIL", "TABHYD_FSI38_TABLE_FAIL")

Path(sys.argv[2]).write_text(s)
print("TABHYD_FSI38_TABLE_VARIANT_CREATED")
