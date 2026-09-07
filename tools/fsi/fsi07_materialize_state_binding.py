#!/usr/bin/env python3
from __future__ import annotations
import hashlib, re
from pathlib import Path

PINS = {
    Path("src/legacy/b1_10_port/headcalc.f90"): "38de52dd9f13b70a61f418c29a5c2e4bc9a449a9",
    Path("src/adapter/mod_reference_richards_legacy_binding.f90"): "f60f7ef2d60ccb8cc78e80d56ef88a739e50ab2e",
    Path("src/solver/mod_reference_richards_state_binding.f90"): "7de02815e7c554077bcd41f973f15b99d32b7d09",
}

def blob_sha(path: Path) -> str:
    b = path.read_bytes()
    return hashlib.sha1(f"blob {len(b)}\0".encode() + b).hexdigest()

def one(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"F-SI07_MATERIALIZE FAIL {label}: expected 1 found {n}")
    return text.replace(old, new, 1)

def transform_headcalc(path: Path) -> None:
    s = path.read_text()
    s = one(s,
        "subroutine headcalc(worker, fsi_workspace, history)",
        "subroutine headcalc(worker, fsi_workspace, history, state_binding)",
        "HeadCalc signature")
    s = one(s,
        "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n",
        "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n"
        "   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n",
        "state binding use")
    s = one(s,
        "   type(a23bu_solver_history_t), target :: local_history\n   type(a23bu_solver_history_t), pointer :: hist\n!  local\n",
        "   type(a23bu_solver_history_t), target :: local_history\n"
        "   type(a23bu_solver_history_t), pointer :: hist\n"
        "   type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n"
        "   type(reference_richards_state_binding_t), target :: local_state_binding\n"
        "   type(reference_richards_state_binding_t), pointer :: st\n!  local\n",
        "state declarations")

    marker = "   canonical_trial = present(worker)\n"
    if s.count(marker) != 1:
        raise SystemExit("F-SI07_MATERIALIZE FAIL canonical marker")
    prefix, body = s.split(marker, 1)

    fields = [
        "fllowgwl","fldecdt","numbit","thetm1","pondm1","gwlm1","gwlinp",
        "kmean","dimoca","theta","hm1","hbot","qtop","qbot","pond","gwl","k","h"
    ]
    for name in fields:
        body = re.sub(rf"(?<![%A-Za-z0-9_]){name}(?![A-Za-z0-9_])", f"st%{name}", body, flags=re.IGNORECASE)

    init = (
        "   if (present(state_binding)) then\n"
        "      if (state_binding%active_nodes /= numnod) error stop 'F-SI07 HeadCalc state/grid mismatch'\n"
        "      st => state_binding\n"
        "   else\n"
        "      call fsi07_load_state_from_legacy(local_state_binding)\n"
        "      st => local_state_binding\n"
        "   end if\n\n"
        "   canonical_trial = present(worker)\n"
    )
    body = init + body

    for call in ["call RootExtraction(2)", "call boundtop(2)", "call MACROPORE(2)",
                 "call MACROPORE(3)", "call pondrunoff ()"]:
        if call in body:
            body = body.replace(call,
                "call fsi07_publish_state_to_legacy()\n      " + call +
                "\n      call fsi07_absorb_state_from_legacy()")

    if "\ncontains\n" not in body:
        raise SystemExit("F-SI07_MATERIALIZE FAIL contains marker")
    main, contained = body.split("\ncontains\n", 1)
    main = re.sub(r"(?m)^(\s*)return\s*$",
                  r"\1if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()\n\1return", main)

    helpers = '''
subroutine fsi07_load_state_from_legacy(target)
   type(reference_richards_state_binding_t), intent(inout) :: target
   call target%ensure_shape(numnod)
   target%h = h(1:numnod)
   target%theta = theta(1:numnod)
   target%hm1 = hm1(1:numnod)
   target%thetm1 = thetm1(1:numnod)
   target%k = k(1:numnod)
   target%kmean = kmean(1:numnod+1)
   target%dimoca = dimoca(1:numnod)
   target%pond = pond
   target%pondm1 = pondm1
   target%gwl = gwl
   target%gwlm1 = gwlm1
   target%qtop = qtop
   target%qbot = qbot
   target%hbot = hbot
   target%gwlinp = gwlinp
   target%fllowgwl = fllowgwl
   target%fldecdt = fldecdt
   target%numbit = numbit
end subroutine fsi07_load_state_from_legacy

subroutine fsi07_publish_state_to_legacy()
   h(1:numnod) = st%h
   theta(1:numnod) = st%theta
   hm1(1:numnod) = st%hm1
   thetm1(1:numnod) = st%thetm1
   k(1:numnod) = st%k
   kmean(1:numnod+1) = st%kmean
   dimoca(1:numnod) = st%dimoca
   pond = st%pond
   pondm1 = st%pondm1
   gwl = st%gwl
   gwlm1 = st%gwlm1
   qtop = st%qtop
   qbot = st%qbot
   hbot = st%hbot
   gwlinp = st%gwlinp
   fllowgwl = st%fllowgwl
   fldecdt = st%fldecdt
   numbit = st%numbit
end subroutine fsi07_publish_state_to_legacy

subroutine fsi07_absorb_state_from_legacy()
   st%h = h(1:numnod)
   st%theta = theta(1:numnod)
   st%hm1 = hm1(1:numnod)
   st%thetm1 = thetm1(1:numnod)
   st%k = k(1:numnod)
   st%kmean = kmean(1:numnod+1)
   st%dimoca = dimoca(1:numnod)
   st%pond = pond
   st%pondm1 = pondm1
   st%gwl = gwl
   st%gwlm1 = gwlm1
   st%qtop = qtop
   st%qbot = qbot
   st%hbot = hbot
   st%gwlinp = gwlinp
   st%fllowgwl = fllowgwl
   st%fldecdt = fldecdt
   st%numbit = numbit
end subroutine fsi07_absorb_state_from_legacy

'''
    s = prefix + main + "\ncontains\n" + helpers + contained
    path.write_text(s)

def transform_adapter(path: Path) -> None:
    s = path.read_text()
    s = one(s,
        "  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &\n       reset_reference_workspace\n",
        "  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &\n       reset_reference_workspace\n"
        "  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n",
        "adapter state use")
    s = one(s,
        "  use variables, only: h, theta, pond, gwl, hm1, thetm1, pondm1, gwlm1, dt, swbotb, &\n"
        "       maxit, maxbacktr, swkimpl, swkmean, dtmin, CritDevBalCp, CritDevBalTot, &\n"
        "       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, fldecdt, numbit\n",
        "  use variables, only: h, theta, pond, gwl, hm1, thetm1, pondm1, gwlm1, dt, swbotb, &\n"
        "       maxit, maxbacktr, swkimpl, swkmean, dtmin, CritDevBalCp, CritDevBalTot, &\n"
        "       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, fldecdt, numbit, &\n"
        "       k, kmean, dimoca, hbot, gwlinp, fllowgwl\n",
        "adapter legacy bridge imports")
    s = one(s,
        "     type(reference_richards_workspace_t) :: richards\n     type(a23bu_worker_context_t) :: legacy_worker\n",
        "     type(reference_richards_workspace_t) :: richards\n"
        "     type(reference_richards_state_binding_t) :: state\n"
        "     type(a23bu_worker_context_t) :: legacy_worker\n",
        "workspace state field")
    s = one(s, "     subroutine headcalc(worker, fsi_workspace, history)\n",
               "     subroutine headcalc(worker, fsi_workspace, history, state_binding)\n",
               "adapter interface signature")
    s = one(s,
        "       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n",
        "       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n"
        "       use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n",
        "adapter interface state use")
    s = one(s,
        "       type(a23bu_solver_history_t), target, intent(inout), optional :: history\n",
        "       type(a23bu_solver_history_t), target, intent(inout), optional :: history\n"
        "       type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n",
        "adapter interface state declaration")

    old_assign = '''       h(1:numnod) = request%base_state%pressure_head
       theta(1:numnod) = request%base_state%water_content
       hm1(1:numnod) = request%base_state%pressure_head
       thetm1(1:numnod) = request%base_state%water_content
       pond = request%base_state%ponding_depth
       gwl = request%base_state%groundwater_level
       pondm1 = request%base_state%ponding_depth
       gwlm1 = request%base_state%groundwater_level
       fldecdt = .false.

       call headcalc(ws%legacy_worker, ws%richards, call_history)
'''
    new_assign = '''       call ws%state%ensure_shape(numnod)
       ws%state%h = request%base_state%pressure_head
       ws%state%theta = request%base_state%water_content
       ws%state%hm1 = request%base_state%pressure_head
       ws%state%thetm1 = request%base_state%water_content
       ws%state%k = k(1:numnod)
       ws%state%kmean = kmean(1:numnod+1)
       ws%state%dimoca = dimoca(1:numnod)
       ws%state%pond = request%base_state%ponding_depth
       ws%state%gwl = request%base_state%groundwater_level
       ws%state%pondm1 = request%base_state%ponding_depth
       ws%state%gwlm1 = request%base_state%groundwater_level
       ws%state%qtop = qtop
       ws%state%qbot = qbot
       ws%state%hbot = hbot
       ws%state%gwlinp = gwlinp
       ws%state%fllowgwl = fllowgwl
       ws%state%fldecdt = .false.
       ws%state%numbit = 0

       call headcalc(ws%legacy_worker, ws%richards, call_history, ws%state)
'''
    s = one(s, old_assign, new_assign, "adapter request binding")
    replacements = [
        ("result%candidate_state%pressure_head = h(1:numnod)",
         "result%candidate_state%pressure_head = ws%state%h", "result h"),
        ("result%candidate_state%water_content = theta(1:numnod)",
         "result%candidate_state%water_content = ws%state%theta", "result theta"),
        ("result%candidate_state%ponding_depth = pond",
         "result%candidate_state%ponding_depth = ws%state%pond", "result pond"),
        ("result%candidate_state%groundwater_level = gwl",
         "result%candidate_state%groundwater_level = ws%state%gwl", "result gwl"),
        ("result%top_flux = qtop", "result%top_flux = ws%state%qtop", "result qtop"),
        ("result%bottom_flux = qbot", "result%bottom_flux = ws%state%qbot", "result qbot"),
        ("if (fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then",
         "if (ws%state%fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then", "retry state"),
    ]
    for old, new, label in replacements:
        s = one(s, old, new, label)
    path.write_text(s)

def main() -> None:
    for p, sha in PINS.items():
        actual = blob_sha(p)
        if actual != sha:
            raise SystemExit(f"F-SI07_MATERIALIZE FAIL preimage {p}: {actual} != {sha}")
    transform_headcalc(Path("src/legacy/b1_10_port/headcalc.f90"))
    transform_adapter(Path("src/adapter/mod_reference_richards_legacy_binding.f90"))
    print("F-SI07_MATERIALIZE PASS")
    print("physics_change_intended=false")
    print("numerical_policy_change_intended=false")
    print("transaction_semantics_change_intended=false")
    print("full_parallel_admission=false")

if __name__ == "__main__":
    main()
