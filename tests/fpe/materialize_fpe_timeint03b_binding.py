#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()
old_module="mod_reference_richards_legacy_binding"
new_module="mod_fpe_timeint03b_reference_binding"
if f"module {old_module}" not in src:
    raise SystemExit("source module marker missing")
src=src.replace(f"module {old_module}",f"module {new_module}",1)
src=src.replace(f"end module {old_module}",f"end module {new_module}",1)

old_guard="""    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
"""
new_guard="""    if (request%numerical%conductivity_implicit_mode < 0 .or. &
        request%numerical%conductivity_implicit_mode > 1) then
       route = 'timeint03b-conductivity-mode-invalid'
       return
    end if
"""
if old_guard not in src:
    raise SystemExit("implicit-k guard patch point missing")
src=src.replace(old_guard,new_guard,1)

decl="""    integer(int64) :: reset_bytes_before
"""
decl_new="""    integer(int64) :: reset_bytes_before
    integer :: timeint03b_predictor_mode
    real(8) :: timeint03b_predictor_h(1000)
    common /timeint03b_predictor_common/ timeint03b_predictor_mode, timeint03b_predictor_h
"""
if decl not in src:
    raise SystemExit("local declaration patch point missing")
src=src.replace(decl,decl_new,1)

marker="""       call initialize_reference_state_binding(ws%state_binding, request)

       ! Only the qualified prescribed-qbot route needs reusable-factor capture.
"""
insert="""       call initialize_reference_state_binding(ws%state_binding, request)

       if (timeint03b_predictor_mode == 1) then
          if (.not. associated(request%evaluation%constitutive)) &
             error stop 'TIMEINT03B predictor requires constitutive provider'
          ws%state_binding%h(1:n) = timeint03b_predictor_h(1:n)
          call request%evaluation%constitutive%evaluate(ws%state_binding%h(1:n), &
               ws%richards%provider_theta(1:n), ws%richards%provider_k(1:n), &
               ws%richards%provider_capacity(1:n), ws%richards%provider_dkdh(1:n))
          ws%state_binding%theta(1:n) = ws%richards%provider_theta(1:n)
       end if

       ! Only the qualified prescribed-qbot route needs reusable-factor capture.
"""
if marker not in src:
    raise SystemExit("predictor insertion point missing")
src=src.replace(marker,insert,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT03B_BINDING_MATERIALIZER=PASS")
