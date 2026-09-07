#!/usr/bin/env python3
"""Materialize the F-SI05 production HeadCalc workspace seam.

This is a one-time, fail-closed structural migration from the exact qualified
F-SI04 postimage. It changes ownership/routing of solver scratch only. Richards
expressions, convergence criteria and numerical-policy choices are not edited.
"""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADCALC = ROOT / "src/legacy/b1_10_port/headcalc.f90"
WORKSPACE = ROOT / "src/solver/mod_reference_richards_workspace.f90"
ADAPTER = ROOT / "src/adapter/mod_reference_richards_legacy_binding.f90"
FSI04_GENERATOR = ROOT / "tools/fsi/fsi04_generate_workspace_headcalc.py"

PINNED = {
    HEADCALC: "225b9f2cc1ecff01414b5691799103b92bc068c5",
    WORKSPACE: "f35fc559aec8462313d9e9b6c95171983b3cf8ef",
    ADAPTER: "84366a4b312a86806cc3aa78a7257c3a7a95d2f1",
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def require_blob(path: Path, expected: str) -> None:
    actual = git_blob_sha(path.read_bytes())
    if actual != expected:
        raise SystemExit(f"F-SI05 source guard failed for {path.relative_to(ROOT)}: {actual} != {expected}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F-SI05 {label}: expected exactly one literal match, got {count}")
    return text.replace(old, new, 1)


def replace_regex_once(text: str, pattern: str, repl: str, label: str) -> str:
    out, count = re.subn(pattern, repl, text, count=1, flags=re.IGNORECASE | re.MULTILINE)
    if count != 1:
        raise SystemExit(f"F-SI05 {label}: expected exactly one regex match, got {count}")
    return out


def materialize_headcalc() -> None:
    with tempfile.TemporaryDirectory(prefix="fsi05-headcalc-") as td:
        generated = Path(td) / "headcalc.f90"
        subprocess.run([sys.executable, str(FSI04_GENERATOR), str(HEADCALC), str(generated)], check=True)
        text = generated.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "   type(reference_richards_workspace_t), intent(inout) :: fsi_workspace\n",
        "   type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n"
        "   type(reference_richards_workspace_t), target :: local_fsi_workspace\n"
        "   type(reference_richards_workspace_t), pointer :: fsi_ws\n",
        "optional workspace declaration",
    )
    text = replace_once(
        text,
        "   call initialize_reference_workspace(fsi_workspace, numnod)\n",
        "   if (present(fsi_workspace)) then\n"
        "      fsi_ws => fsi_workspace\n"
        "   else\n"
        "      fsi_ws => local_fsi_workspace\n"
        "   end if\n"
        "   call initialize_reference_workspace(fsi_ws, numnod)\n",
        "workspace selection",
    )
    text = text.replace("fsi_workspace%", "fsi_ws%")
    if "fsi_workspace%" in text:
        raise SystemExit("F-SI05 headcalc workspace alias replacement incomplete")

    start = text.index("   subroutine alternative_solver()")
    end_marker = "   end subroutine alternative_solver"
    end = text.index(end_marker, start) + len(end_marker)
    alt = text[start:end]
    for pattern, label in [
        (r"^\s*integer,\s*dimension\(macp\)\s*::\s*indx\s*\n", "fallback indx declaration"),
        (r"^\s*real\(8\),\s*dimension\(macp,3\)\s*::\s*a\s*\n", "fallback a declaration"),
        (r"^\s*real\(8\),\s*dimension\(macp,1\)\s*::\s*a1\s*\n", "fallback a1 declaration"),
        (r"^\s*real\(8\),\s*dimension\(macp\)\s*::\s*b\s*\n", "fallback b declaration"),
    ]:
        alt = replace_regex_once(alt, pattern, "", label)
    for pattern, replacement in [
        (r"\ba1\b", "fsi_ws%band_aux"),
        (r"\bindx\b", "fsi_ws%band_pivots"),
        (r"\bb\b", "fsi_ws%band_rhs"),
        (r"\ba\b", "fsi_ws%band_matrix"),
    ]:
        alt = re.sub(pattern, replacement, alt)
    text = text[:start] + alt + text[end:]

    forbidden = [
        "real(8), dimension(macp,3) :: a",
        "real(8), dimension(macp,1) :: a1",
        "integer, dimension(macp)   :: indx",
        "real(8), dimension(macp)   :: b",
        "ctx%headcalc%dkdh",
    ]
    for token in forbidden:
        if token.lower() in text.lower():
            raise SystemExit(f"F-SI05 HeadCalc retained forbidden scratch token: {token}")
    if "subroutine headcalc(worker, fsi_workspace)" not in text:
        raise SystemExit("F-SI05 HeadCalc signature missing")
    HEADCALC.write_text(text, encoding="utf-8")


def materialize_workspace() -> None:
    text = WORKSPACE.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "     real(real64), allocatable :: head_gradient(:)\n",
        "     real(real64), allocatable :: head_gradient(:)\n"
        "     real(real64), allocatable :: band_matrix(:,:)\n"
        "     real(real64), allocatable :: band_aux(:,:)\n"
        "     real(real64), allocatable :: band_rhs(:)\n"
        "     integer, allocatable :: band_pivots(:)\n",
        "workspace fallback fields",
    )
    text = replace_once(
        text,
        "       allocate(workspace%vertical_flux(active_nodes+1), workspace%head_gradient(active_nodes+1))\n",
        "       allocate(workspace%vertical_flux(active_nodes+1), workspace%head_gradient(active_nodes+1))\n"
        "       allocate(workspace%band_matrix(active_nodes,3), workspace%band_aux(active_nodes,1))\n"
        "       allocate(workspace%band_rhs(active_nodes), workspace%band_pivots(active_nodes))\n",
        "workspace fallback allocation",
    )
    text = replace_once(
        text,
        "    workspace%head_gradient = 0.0_real64\n",
        "    workspace%head_gradient = 0.0_real64\n"
        "    workspace%band_matrix = 0.0_real64\n"
        "    workspace%band_aux = 0.0_real64\n"
        "    workspace%band_rhs = 0.0_real64\n"
        "    workspace%band_pivots = 0\n",
        "workspace fallback reset",
    )
    text = replace_once(
        text,
        "    workspace%head_gradient = qnan\n",
        "    workspace%head_gradient = qnan\n"
        "    workspace%band_matrix = qnan\n"
        "    workspace%band_aux = qnan\n"
        "    workspace%band_rhs = qnan\n"
        "    workspace%band_pivots = -huge(0)\n",
        "workspace fallback poison",
    )
    text = replace_once(
        text,
        "    if (allocated(workspace%head_gradient)) deallocate(workspace%head_gradient)\n",
        "    if (allocated(workspace%head_gradient)) deallocate(workspace%head_gradient)\n"
        "    if (allocated(workspace%band_matrix)) deallocate(workspace%band_matrix)\n"
        "    if (allocated(workspace%band_aux)) deallocate(workspace%band_aux)\n"
        "    if (allocated(workspace%band_rhs)) deallocate(workspace%band_rhs)\n"
        "    if (allocated(workspace%band_pivots)) deallocate(workspace%band_pivots)\n",
        "workspace fallback release",
    )
    text = replace_once(
        text,
        "    integer(int64) :: nreal, nlogical\n\n    nreal = 0_int64\n    nlogical = 0_int64\n",
        "    integer(int64) :: nreal, nlogical, ninteger\n\n    nreal = 0_int64\n    nlogical = 0_int64\n    ninteger = 0_int64\n",
        "workspace payload counters",
    )
    text = replace_once(
        text,
        "    if (allocated(workspace%warm_start_head)) nreal = nreal + size(workspace%warm_start_head, kind=int64)\n",
        "    if (allocated(workspace%warm_start_head)) nreal = nreal + size(workspace%warm_start_head, kind=int64)\n"
        "    if (allocated(workspace%band_matrix)) nreal = nreal + size(workspace%band_matrix, kind=int64)\n"
        "    if (allocated(workspace%band_aux)) nreal = nreal + size(workspace%band_aux, kind=int64)\n"
        "    if (allocated(workspace%band_rhs)) nreal = nreal + size(workspace%band_rhs, kind=int64)\n"
        "    if (allocated(workspace%band_pivots)) ninteger = ninteger + size(workspace%band_pivots, kind=int64)\n",
        "workspace payload fallback counts",
    )
    text = replace_once(
        text,
        "    nbytes = nreal * int(storage_size(0.0_real64)/8, int64) + &\n             nlogical * int(storage_size(.false.)/8, int64)\n",
        "    nbytes = nreal * int(storage_size(0.0_real64)/8, int64) + &\n"
        "             nlogical * int(storage_size(.false.)/8, int64) + &\n"
        "             ninteger * int(storage_size(0)/8, int64)\n",
        "workspace payload bytes",
    )
    WORKSPACE.write_text(text, encoding="utf-8")


def materialize_adapter() -> None:
    text = ADAPTER.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "     subroutine headcalc(worker)\n       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n       type(a23bu_worker_context_t), intent(inout), optional :: worker\n     end subroutine headcalc\n",
        "     subroutine headcalc(worker, fsi_workspace)\n"
        "       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n"
        "       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n"
        "       type(a23bu_worker_context_t), intent(inout), optional :: worker\n"
        "       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n"
        "     end subroutine headcalc\n",
        "adapter HeadCalc interface",
    )
    text = replace_once(
        text,
        "       call headcalc(ws%legacy_worker)\n",
        "       call headcalc(ws%legacy_worker, ws%richards)\n",
        "adapter workspace call",
    )
    ADAPTER.write_text(text, encoding="utf-8")


def main() -> int:
    for path, expected in PINNED.items():
        require_blob(path, expected)
    materialize_workspace()
    materialize_headcalc()
    materialize_adapter()
    print("F-SI05_MATERIALIZE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
