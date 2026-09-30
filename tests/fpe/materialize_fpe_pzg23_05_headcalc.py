#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F_PE_PZG23_05_FAIL {label} count={count}")
    return text.replace(old, new, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    src = Path(args.source).read_text(encoding="utf-8")

    src = replace_once(
        src,
        "   logical                          :: flboth, flok\n",
        "   logical                          :: flboth, flok\n"
        "   logical                          :: pzg23_bt_progress, pzg23_bt_iter_exhausted\n"
        "   integer                          :: pzg23_bt_exhaustions, pzg23_bt_progress_accepts, pzg23_bt_fmax_accepts\n"
        "   real(8)                          :: pzg23_bt_best_ratio, pzg23_bt_min_factor, pzg23_bt_last_fmax\n"
        "   real(8)                          :: pzg23_bt_iter_best_ratio, pzg23_bt_iter_min_factor\n",
        "declarations",
    )

    src = replace_once(
        src,
        "   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1\n",
        "   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1\n"
        "   pzg23_bt_exhaustions = 0\n"
        "   pzg23_bt_progress_accepts = 0\n"
        "   pzg23_bt_fmax_accepts = 0\n"
        "   pzg23_bt_best_ratio = huge(0.0d0)\n"
        "   pzg23_bt_min_factor = 1.0d0\n"
        "   pzg23_bt_last_fmax = huge(0.0d0)\n"
        "   pzg23_bt_iter_best_ratio = huge(0.0d0)\n"
        "   pzg23_bt_iter_min_factor = 1.0d0\n"
        "   pzg23_bt_iter_exhausted = .FALSE.\n",
        "initialization",
    )

    src = replace_once(
        src,
        "!     back tracking cycle\n      factor = 1.0d0\n",
        "!     back tracking cycle\n"
        "      factor = 1.0d0\n"
        "      pzg23_bt_progress = .FALSE.\n"
        "      pzg23_bt_iter_exhausted = .FALSE.\n"
        "      pzg23_bt_iter_best_ratio = huge(0.0d0)\n"
        "      pzg23_bt_iter_min_factor = 1.0d0\n",
        "backtracking start",
    )

    src = replace_once(
        src,
        "!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor\n"
        "         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1\n"
        "         factor = factor / 3.0d0\n\n"
        "      end do\n"
        " 1    continue\n",
        "!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor\n"
        "         if (sumold > 0.0d0) then\n"
        "            pzg23_bt_best_ratio = min(pzg23_bt_best_ratio, sump / sumold)\n"
        "            pzg23_bt_iter_best_ratio = min(pzg23_bt_iter_best_ratio, sump / sumold)\n"
        "         end if\n"
        "         pzg23_bt_min_factor = min(pzg23_bt_min_factor, factor)\n"
        "         pzg23_bt_iter_min_factor = min(pzg23_bt_iter_min_factor, factor)\n"
        "         pzg23_bt_last_fmax = Fmax\n"
        "         if (sump < sumold) then\n"
        "            pzg23_bt_progress_accepts = pzg23_bt_progress_accepts + 1\n"
        "            pzg23_bt_progress = .TRUE.\n"
        "         else if (Fmax < CritDevBalCp) then\n"
        "            pzg23_bt_fmax_accepts = pzg23_bt_fmax_accepts + 1\n"
        "            pzg23_bt_progress = .TRUE.\n"
        "         end if\n"
        "         if (pzg23_bt_progress) goto 1\n"
        "         factor = factor / 3.0d0\n\n"
        "      end do\n"
        "      pzg23_bt_exhaustions = pzg23_bt_exhaustions + 1\n"
        "      pzg23_bt_iter_exhausted = .TRUE.\n"
        " 1    continue\n",
        "progress block",
    )

    success_anchor = (
        "         ctx%control%last_numbit = state%numbit\n"
        "         if (legacy_state_binding) call publish_legacy_state(state)\n"
        "         return\n"
    )
    success_new = (
        "         ctx%control%last_numbit = state%numbit\n"
        "         if (canonical_trial) write(*,'(*(g0))') 'PZG23_05_HEADCALC|outcome=CONVERGED|call=', &\n"
        "              ctx%diagnostics%headcalc_calls,'|dt=',dt,'|numbit=',state%numbit,'|backtracking=',iBackTr, &\n"
        "              '|exhaustions=',pzg23_bt_exhaustions,'|progress_accepts=',pzg23_bt_progress_accepts, &\n"
        "              '|fmax_accepts=',pzg23_bt_fmax_accepts,'|best_ratio=',pzg23_bt_best_ratio, &\n"
        "              '|min_factor=',pzg23_bt_min_factor,'|last_fmax=',pzg23_bt_last_fmax, &\n"
        "              '|last_iter_exhausted=',pzg23_bt_iter_exhausted,'|last_iter_best_ratio=',pzg23_bt_iter_best_ratio, &\n"
        "              '|last_iter_min_factor=',pzg23_bt_iter_min_factor\n"
        "         if (legacy_state_binding) call publish_legacy_state(state)\n"
        "         return\n"
    )
    src = replace_once(src, success_anchor, success_new, "success logging")

    retry_anchor = (
        "      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1\n\n"
        "      if (legacy_state_binding) call publish_legacy_state(state)\n\n"
        "      return\n"
    )
    retry_new = (
        "      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1\n"
        "      if (canonical_trial) write(*,'(*(g0))') 'PZG23_05_HEADCALC|outcome=REQUEST_DT_REDUCTION|call=', &\n"
        "           ctx%diagnostics%headcalc_calls,'|dt=',dt,'|numbit=',state%numbit,'|backtracking=',iBackTr, &\n"
        "           '|exhaustions=',pzg23_bt_exhaustions,'|progress_accepts=',pzg23_bt_progress_accepts, &\n"
        "           '|fmax_accepts=',pzg23_bt_fmax_accepts,'|best_ratio=',pzg23_bt_best_ratio, &\n"
        "           '|min_factor=',pzg23_bt_min_factor,'|last_fmax=',pzg23_bt_last_fmax\n\n"
        "      if (legacy_state_binding) call publish_legacy_state(state)\n\n"
        "      return\n"
    )
    src = replace_once(src, retry_anchor, retry_new, "retry logging")

    terminal_anchor = (
        "!     continue without convergence !!!\n"
        "      if (legacy_state_binding) call publish_legacy_state(state)\n"
        "      return\n"
    )
    terminal_new = (
        "!     continue without convergence !!!\n"
        "      if (canonical_trial) write(*,'(*(g0))') 'PZG23_05_HEADCALC|outcome=NO_CONVERGENCE|call=', &\n"
        "           ctx%diagnostics%headcalc_calls,'|dt=',dt,'|numbit=',state%numbit,'|backtracking=',iBackTr, &\n"
        "           '|exhaustions=',pzg23_bt_exhaustions,'|progress_accepts=',pzg23_bt_progress_accepts, &\n"
        "           '|fmax_accepts=',pzg23_bt_fmax_accepts,'|best_ratio=',pzg23_bt_best_ratio, &\n"
        "           '|min_factor=',pzg23_bt_min_factor,'|last_fmax=',pzg23_bt_last_fmax, &\n"
        "           '|last_iter_exhausted=',pzg23_bt_iter_exhausted,'|last_iter_best_ratio=',pzg23_bt_iter_best_ratio, &\n"
        "           '|last_iter_min_factor=',pzg23_bt_iter_min_factor\n"
        "      if (legacy_state_binding) call publish_legacy_state(state)\n"
        "      return\n"
    )
    src = replace_once(src, terminal_anchor, terminal_new, "terminal logging")

    Path(args.output).write_text(src, encoding="utf-8")
    print("F_PE_PZG23_05_HEADCALC_MATERIALIZE=PASS")


if __name__ == "__main__":
    main()
