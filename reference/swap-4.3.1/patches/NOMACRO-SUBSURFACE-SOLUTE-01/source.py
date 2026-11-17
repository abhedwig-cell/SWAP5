"""Exact original CDE source correction; no global B1 or macro promotion."""
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
ORIGINAL_SHA='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
HELPER_SHA='0a5cf80aa06eecf23ad408292b710e56d616a2236acb8b26f14527f0f838fd0f'


def helper_source():
    raw=(ROOT/'src/process/mod_subsurface_solute_source.f90').read_bytes()
    canonical=raw.replace(b'\r\n',b'\n')
    if hashlib.sha256(canonical).hexdigest()!=HELPER_SHA:
        raise ValueError('Foreign conservative subsurface solute source')
    return canonical


def source(original):
    if hashlib.sha256(original).hexdigest()!=ORIGINAL_SHA:
        raise ValueError('Foreign original solute CDE preimage')
    helper_source()
    end=original.index(b'end submodule MOD_Solute_CDE')+len(b'end submodule MOD_Solute_CDE')
    tail=original[end:]
    original=original[:end]
    def replace(anchor,replacement):
        nonlocal original
        anchor=anchor.replace('\n','\r\n').encode('ascii')
        replacement=replacement.replace('\n','\r\n').encode('ascii')
        if original.count(anchor)!=1:raise ValueError('Changed original CDE anchor: '+repr(anchor))
        original=original.replace(anchor,replacement)
    replace('      use MOD_swap_base,       only: swinco, swhea',
            '      use MOD_swap_base,       only: swinco, swhea, swmacro')
    replace('      use MOD_irrigation,      only: nird, cirr',
            '      use MOD_irrigation,      only: nird, cirr, qssdi\n'
            '      use mod_subsurface_solute_source, only: evaluate_subsurface_solute_source, SUBSOL_OK')
    replace('      logical                             :: differ',
            '      logical                             :: differ\n'
            '      logical                             :: fl_ssdi_source\n'
            '      integer                             :: ssdi_status\n'
            '      real(8)                             :: ssdi_total\n'
            '      real(8), allocatable                :: ssdi_mass(:), ssdi_bulk(:)')
    anchor='         if (allocated(decpotfdepth))    deallocate(decpotfdepth);    allocate(decpotfdepth(numnod))'
    replace(anchor,anchor+'\n'
            '         if(allocated(ssdi_mass))deallocate(ssdi_mass,ssdi_bulk)\n'
            '         allocate(ssdi_mass(numnod),ssdi_bulk(numnod))\n'
            '         ssdi_mass=0.0d0;ssdi_bulk=0.0d0;ssdi_total=0.0d0;fl_ssdi_source=.false.')
    anchor='            tcumsol = tcumsol + dtsolu'
    replace(anchor,anchor+'\n'
            '            fl_ssdi_source=.false.\n'
            '            if(swmacro==0)then\n'
            '               call evaluate_subsurface_solute_source(qssdi(1:numnod),cirr,dz(1:numnod),dtsolu, &\n'
            '                    ssdi_mass,ssdi_bulk,ssdi_total,ssdi_status)\n'
            "               if(ssdi_status/=SUBSOL_OK)error stop 'Invalid conserved subsurface solute source'\n"
            '               fl_ssdi_source=any(ssdi_mass/=0.0d0)\n'
            '            end if')
    anchor='               cmsy(i) = cmsy(i) + (cfluxb-cfluxt) / dz(i) + (-ctrans-crot-cdrtot) * dtsolu'
    replace(anchor,anchor+'\n               if(fl_ssdi_source)cmsy(i)=cmsy(i)+ssdi_bulk(i)')
    anchor='! ---    continue with next solute time step'
    replace(anchor,
            '            if(fl_ssdi_source)then\n'
            '               sqirrig=sqirrig+ssdi_total\n'
            '               imsqirrig=imsqirrig+ssdi_total\n'
            '            end if\n\n'+anchor)
    return original+tail
