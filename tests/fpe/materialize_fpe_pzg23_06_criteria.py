#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F_PE_PZG23_06_FAIL {label} count={count}")
    return text.replace(old, new, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    src = Path(args.source).read_text(encoding="utf-8")

    src = replace_once(
        src,
        "   real(8)                          :: pzg23_bt_iter_best_ratio, pzg23_bt_iter_min_factor\n",
        "   real(8)                          :: pzg23_bt_iter_best_ratio, pzg23_bt_iter_min_factor\n"
        "   real(8)                          :: pzg23_cr_comp, pzg23_cr_total, pzg23_cr_head, pzg23_cr_pond, pzg23_cr_node\n",
        "criterion declarations",
    )

    anchor = (
        "!  Convergence could not been reached\n"
        "   if (.NOT.fldtmin) then\n"
    )
    inserted = (
        "!  Convergence could not been reached\n"
        "   pzg23_cr_comp = Fmax / max(CritDevBalCp, tiny(1.0d0))\n"
        "   pzg23_cr_total = dabs(sum1) / max(CritDevBalTot, tiny(1.0d0))\n"
        "   pzg23_cr_head = 0.0d0\n"
        "   do i = 1, NN\n"
        "      if (dabs(fsi_ws%old_head(i)) < 1.0d0) then\n"
        "         pzg23_cr_node = dabs(state%h(i)-fsi_ws%old_head(i)) / max(CritDevh2Cp, tiny(1.0d0))\n"
        "      else\n"
        "         pzg23_cr_node = dabs(state%h(i)-fsi_ws%old_head(i)) / dabs(fsi_ws%old_head(i)) / &\n"
        "              max(CritDevh1Cp, tiny(1.0d0))\n"
        "      end if\n"
        "      pzg23_cr_head = max(pzg23_cr_head, pzg23_cr_node)\n"
        "   end do\n"
        "   pzg23_cr_pond = 0.0d0\n"
        "   if (state%ftoph) pzg23_cr_pond = dabs(deviat) / max(CritDevPondDt, tiny(1.0d0))\n"
        "   if (canonical_trial) write(*,'(*(g0))') 'PZG23_06_TERMINAL|dt=',dt,'|numbit=',state%numbit, &\n"
        "        '|comp_ratio=',pzg23_cr_comp,'|total_ratio=',pzg23_cr_total,'|head_ratio=',pzg23_cr_head, &\n"
        "        '|pond_ratio=',pzg23_cr_pond,'|ftoph=',state%ftoph,'|fmax=',Fmax,'|sum1=',sum1\n"
        "   if (.NOT.fldtmin) then\n"
    )
    src = replace_once(src, anchor, inserted, "terminal criterion insertion")

    Path(args.output).write_text(src, encoding="utf-8")
    print("F_PE_PZG23_06_HEADCALC_MATERIALIZE=PASS")


if __name__ == "__main__":
    main()
