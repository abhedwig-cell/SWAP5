#!/usr/bin/env python3
"""Byte-safe verifier/applicator for the isolated SWAP-012 prhead correction."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

B0_SHA256 = "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"
PATCH_SHA256 = "263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131"
CORRECTED_SHA256 = "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"

DECL_OLD = (
    b"      use MOD_grid,  only: layer\r\n"
    b"      implicit none\r\n\r\n"
    b"! --- global\r\n"
    b"      integer, intent(in)  :: node\r\n"
    b"      real(8), intent(in)  :: wcon,disnod\r\n"
    b"      real(8), intent(in)  :: h_in(macp)\r\n"
    b"      real(8), intent(in)  :: cofgen_in(mcof,macp)\r\n\r\n"
    b"! --- local\r\n"
    b"      integer              :: imod\r\n"
    b"      real(8)              :: s_enpr,relsat,help,dummy,prh,locwcon\r\n"
    b"      real(8)              :: thetar, thetas, alfamg, npar, mpar, h_enpr\r\n"
)
DECL_NEW = (
    b"      use MOD_grid,  only: layer\r\n"
    b"      use WC_K_models_04_11, only: functionvalue_04_11\r\n"
    b"      implicit none\r\n\r\n"
    b"! --- global\r\n"
    b"      integer, intent(in)  :: node\r\n"
    b"      real(8), intent(in)  :: wcon,disnod\r\n"
    b"      real(8), intent(in)  :: h_in(macp)\r\n"
    b"      real(8), intent(in)  :: cofgen_in(mcof,macp)\r\n\r\n"
    b"! --- local\r\n"
    b"      integer              :: imod, iter\r\n"
    b"      real(8)              :: s_enpr,relsat,help,dummy,prh,locwcon\r\n"
    b"      real(8)              :: thetar, thetas, alfamg, npar, mpar, h_enpr\r\n"
    b"      real(8)              :: hlow,hhigh,hmid,wclow,wcmid,omega1,alpha2,npar2,mpar2\r\n"
)

BRANCH_OLD = (
    b"         else  ! use default MvG\r\n\r\n"
    b"            if (thetas-wcon < 1.0d-6) then\r\n"
)
BRANCH_NEW = (
    b"         else if (imod == 3 .OR. imod >= 5) then\r\n"
    b"            ! These models do not share the analytical inverse of default MvG.\r\n"
    b"            ! Invert their actual retention relation by robust bisection.\r\n"
    b"            if (thetas-wcon < 1.0d-6) then\r\n"
    b"               if (node == 1) then\r\n"
    b"                  prhead = disnod\r\n"
    b"               else\r\n"
    b"                  prhead = h_in(node-1) + disnod\r\n"
    b"               end if\r\n"
    b"               prhead = dmax1(prhead,0.0d0)\r\n"
    b"            else\r\n"
    b"               hhigh = 0.0d0\r\n"
    b"               if ((imod == 5 .OR. imod == 7 .OR. (imod >= 8 .AND. imod <= 11)) .AND. cofgen_in(18,node) > 0.0d0) then\r\n"
    b"                  hlow = -cofgen_in(18,node)\r\n"
    b"               else\r\n"
    b"                  hlow = -1.0d12\r\n"
    b"               end if\r\n\r\n"
    b"               if (imod == 3) then\r\n"
    b"                  omega1 = cofgen_in(16,node)\r\n"
    b"                  alpha2 = cofgen_in(13,node)\r\n"
    b"                  npar2  = cofgen_in(14,node)\r\n"
    b"                  mpar2  = cofgen_in(15,node)\r\n"
    b"                  wclow = thetar + (thetas-thetar) * &\r\n"
    b"                          (omega1/(1.0d0+dabs(alfamg*hlow)**npar)**mpar + &\r\n"
    b"                          (1.0d0-omega1)/(1.0d0+dabs(alpha2*hlow)**npar2)**mpar2)\r\n"
    b"               else if (imod >= 5 .AND. imod <= 11) then\r\n"
    b"                  wclow = functionvalue_04_11(1,node,iHWCKmodel,cofgen_in,hlow)\r\n"
    b"               else\r\n"
    b"                  iLayer = layer(node)\r\n"
    b"                  wclow = dble(WCRIA(hlow*1.0_dp))\r\n"
    b"               end if\r\n\r\n"
    b"               if (wcon <= wclow + 1.0d-10) then\r\n"
    b"                  prhead = hlow\r\n"
    b"               else\r\n"
    b"                  do iter = 1, 100\r\n"
    b"                     hmid = 0.5d0*(hlow+hhigh)\r\n"
    b"                     if (imod == 3) then\r\n"
    b"                        wcmid = thetar + (thetas-thetar) * &\r\n"
    b"                                (omega1/(1.0d0+dabs(alfamg*hmid)**npar)**mpar + &\r\n"
    b"                                (1.0d0-omega1)/(1.0d0+dabs(alpha2*hmid)**npar2)**mpar2)\r\n"
    b"                     else if (imod >= 5 .AND. imod <= 11) then\r\n"
    b"                        wcmid = functionvalue_04_11(1,node,iHWCKmodel,cofgen_in,hmid)\r\n"
    b"                     else\r\n"
    b"                        iLayer = layer(node)\r\n"
    b"                        wcmid = dble(WCRIA(hmid*1.0_dp))\r\n"
    b"                     end if\r\n"
    b"                     if (wcmid > wcon) then\r\n"
    b"                        hhigh = hmid\r\n"
    b"                     else\r\n"
    b"                        hlow = hmid\r\n"
    b"                     end if\r\n"
    b"                     if (dabs(hhigh-hlow) <= dmax1(1.0d-8,1.0d-10*dabs(hmid))) exit\r\n"
    b"                  end do\r\n"
    b"                  prhead = 0.5d0*(hlow+hhigh)\r\n"
    b"               end if\r\n"
    b"            end if\r\n\r\n"
    b"         else  ! use analytical default MvG inverse (models 1 and 4)\r\n\r\n"
    b"            if (thetas-wcon < 1.0d-6) then\r\n"
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(data: bytes) -> bytes:
    if digest(data) != B0_SHA256:
        raise ValueError("SWAP-012 canonical/ordered preimage SHA mismatch")
    if data.count(DECL_OLD) != 1:
        raise ValueError("SWAP-012 declaration target not unique")
    data = data.replace(DECL_OLD, DECL_NEW, 1)
    if data.count(BRANCH_OLD) != 1:
        raise ValueError("SWAP-012 default-MvG branch target not unique")
    data = data.replace(BRANCH_OLD, BRANCH_NEW, 1)
    if digest(data) != CORRECTED_SHA256:
        raise ValueError("SWAP-012 corrected target SHA mismatch")
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    patch = Path(__file__).with_name("fix.patch")
    if digest(patch.read_bytes()) != PATCH_SHA256:
        raise SystemExit("stored SWAP-012 fix.patch identity mismatch")
    raw = args.input.read_bytes()
    corrected = apply(raw)
    if args.output:
        args.output.write_bytes(corrected)
    print(f"SWAP-012 PASS preimage={B0_SHA256} corrected={CORRECTED_SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
