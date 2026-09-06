#!/usr/bin/env python3
"""Apply output-only diagnostics for the SWAP-009 full-production gate.

This modifies only MOD_out_PEARL_ANIMO.f90. The diagnostic changes increase
BFO precision for h/theta/root uptake/boundary flux and print existing
checkmassbal residuals at full precision. No state or physics expression is
changed. Apply exactly the same diagnostic transform to B0 and candidate builds.
"""
from pathlib import Path
import argparse, hashlib

EXPECTED_DIAGNOSTIC_SHA256 = "f2d19330a4625149e03ac15a3334f17c36d5817d15c2c042406108e72a66f550"

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main() -> None:
    ap=argparse.ArgumentParser(); ap.add_argument('source_tree',type=Path); a=ap.parse_args()
    p=a.source_tree/'MOD_out_PEARL_ANIMO.f90'; s=p.read_text()
    old="""      write (afo,'(8(1x,e10.3e2))') (real(hNew(node)),                  node=1,numnodNew)\n      write (afo,'(10(1x,f9.6))')   (real(thetaNew(node)),              node=1,numnodNew)\n      write (afo,'(10(1x,f9.6))')   (0.01*real(inqrotNew(node)/outper), node=1,numnodNew)\n      write (afo,'(10(1x,f9.6))')   (-0.01*real(inqNew(node)/outper),   node=1,numnodNew+1)\n"""
    new="""      ! VQ diagnostic build only: increase output precision; no state/physics change.\n      write (afo,'(3(1x,es24.16e3))') (real(hNew(node),kind=8),                  node=1,numnodNew)\n      write (afo,'(3(1x,es24.16e3))') (real(thetaNew(node),kind=8),              node=1,numnodNew)\n      write (afo,'(3(1x,es24.16e3))') (0.01d0*real(inqrotNew(node)/outper,kind=8), node=1,numnodNew)\n      write (afo,'(3(1x,es24.16e3))') (-0.01d0*real(inqNew(node)/outper,kind=8),   node=1,numnodNew+1)\n"""
    if s.count(old)!=1: raise SystemExit(f'expected one BFO precision block, found {s.count(old)}')
    s=s.replace(old,new,1)
    marker="""      do ic = 1, numnodnew\n         if (FlWriteDevCmp(ic)) write(dev,5) daycum, t, ic, DevMasBalCmp(ic), inqNew(ic), inqNew(ic+1), inqrotNew(ic), Qdra(ic), WaSr(ic), WaSrBeg(ic), IQExcMtxDm1CpNew(ic), IQExcMtxDm2CpNew(ic)\n      end do\n"""
    addition=marker+"""\n!     VQ diagnostic build only: emit unrounded mass-balance residuals to stdout.\n      write(*,'(a,1x,es24.16e3,1x,es24.16e3,1x,es24.16e3)') &\n           'VQ_MB_DIAG', DevMasBalPnd, DevMasBalPrf, maxval(abs(DevMasBalCmp(1:NumNodNew)))\n"""
    if s.count(marker)!=1: raise SystemExit(f'expected one mass-balance output marker, found {s.count(marker)}')
    s=s.replace(marker,addition,1)
    p.write_text(s)
    actual=sha(p.read_bytes()); print(actual)
    if actual!=EXPECTED_DIAGNOSTIC_SHA256: raise SystemExit(f'diagnostic source SHA mismatch: {actual}')
if __name__=='__main__': main()
