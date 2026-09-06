#!/usr/bin/env python3
from __future__ import annotations
import argparse, re, shutil, hashlib, json
from pathlib import Path

EXPECTED_PARENT_MANIFEST='aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0'

def sha256_bytes(data: bytes)->str: return hashlib.sha256(data).hexdigest()

def manifest(root: Path)->bytes:
    lines=[]
    for p in sorted(root.iterdir(), key=lambda x:x.name):
        if p.is_file():
            d=p.read_bytes(); lines.append(f'{sha256_bytes(d)}  {len(d):8d}  SWAP/{p.name}\n')
    return ''.join(lines).encode('ascii')

def convert_dec(line: str) -> str:
    stripped=line.strip(); upper=stripped.upper()
    if upper.startswith('!DEC$ IF DEFINED'):
        m=re.search(r'\(([^)]+)\)', stripped)
        if not m: raise ValueError(f'Cannot parse DEC conditional: {line!r}')
        return f'#ifdef {m.group(1).strip()}\n'
    if upper.startswith('!DEC$ IF (LINUX==0)'): return '#if linux==0\n'
    if upper.startswith('!DEC$ ELSE'): return '#else\n'
    if upper.startswith('!DEC$ END IF'): return '#endif\n'
    return line

def replace_once(text: str, old: str, new: str, label: str)->str:
    n=text.count(old)
    if n!=1: raise ValueError(f'{label}: expected one anchor, got {n}')
    return text.replace(old,new,1)

def transform_headcalc(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'subroutine headcalc \n','subroutine headcalc(worker) \n','headcalc signature')
    anchor='   use MOD_swap_base,      only: swmacro, i_instance\n'
    s=replace_once(s,anchor,anchor+'   use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t\n','headcalc use')
    s=replace_once(s,'   implicit none\n\n!  local\n','   implicit none\n   type(a23bp_worker_context_t), intent(inout) :: worker\n\n!  local\n','headcalc dummy')
    for decl in [
      '   real(8), dimension(macp)         :: dFdhL, dFdhM, dFdhU     ! elements of Lower, Main and Upper diagonals in coeffcient matrix\n',
      '   real(8), dimension(macp)         :: difh, F                 ! arrays in solution procedure\n',
      '   real(8), dimension(macp)         :: sink, source            ! sink/source terms in Richards equation\n',
      '   real(8), dimension(macp), save   :: dkdh = 0.0d0\n',
      '   real(8), dimension(macp)         :: hold\n',
      '   real(8), dimension(macp+1)       :: qv, hgrad\n',
      '   logical, dimension(macp)         :: flnonconv1, flnonconv2\n',
      '   logical, dimension(3)            :: flunsatok               ! Flag indicating the performance of the iteration process\n',
      '   logical, save                    :: flwarn\n',
      '   integer, save                    :: iwarn, NStep\n',
    ]:
        if decl not in s: raise ValueError(f'missing declaration {decl.strip()}')
        s=s.replace(decl,'',1)
    s=s.replace('call vector_F(1, hgrad)','call vector_F(1)')
    s=s.replace('call vector_F(2, hgrad)','call vector_F(2)')
    s=replace_once(s,'subroutine vector_F(iTask, hgrad)\n','subroutine vector_F(iTask)\n','vector_F signature')
    s=replace_once(s,'   real(8), dimension(macp+1) :: hgrad\n','', 'vector_F hgrad dummy')
    mapping={
      'dFdhL':'worker%headcalc%dfdhl','dFdhM':'worker%headcalc%dfdhm','dFdhU':'worker%headcalc%dfdhu',
      'difh':'worker%headcalc%difh','F':'worker%headcalc%residual','sink':'worker%headcalc%sink',
      'source':'worker%headcalc%source','dkdh':'worker%headcalc%dkdh','hold':'worker%headcalc%hold',
      'qv':'worker%headcalc%qv','hgrad':'worker%headcalc%hgrad',
      'flnonconv1':'worker%headcalc%flnonconv1','flnonconv2':'worker%headcalc%flnonconv2',
      'flunsatok':'worker%headcalc%flunsatok','flwarn':'worker%history%flwarn','iwarn':'worker%history%iwarn',
      'NStep':'worker%history%nstep'
    }
    for name,repl in sorted(mapping.items(), key=lambda kv:-len(kv[0])):
        s=re.sub(rf'\b{re.escape(name)}\b', repl, s, flags=re.IGNORECASE)
    anchor='!---------------------------------------------------------------------\n\n!  reset some variables at the start of a new day\n'
    insert='!---------------------------------------------------------------------\n\n   if (worker%active_nodes /= numnod) error stop \'A23BP headcalc: worker active_nodes mismatch\'\n   worker%diagnostics%headcalc_calls = worker%diagnostics%headcalc_calls + 1\n\n!  reset some variables at the start of a new day\n'
    s=replace_once(s,anchor,insert,'headcalc start diagnostics')
    s=replace_once(s,'   do numbit = 1, MaxIt1\n','   do numbit = 1, MaxIt1\n      worker%diagnostics%nonlinear_iterations = worker%diagnostics%nonlinear_iterations + 1\n','newton count')
    s=replace_once(s,'      call jacobian_F()\n','      call jacobian_F()\n      worker%diagnostics%jacobian_builds = worker%diagnostics%jacobian_builds + 1\n','jacobian count')
    s=replace_once(s,'      call tridag(NN, worker%headcalc%dfdhu, worker%headcalc%dfdhm, worker%headcalc%dfdhl, worker%headcalc%residual, worker%headcalc%difh, ierror)\n',
                   '      call tridag(NN, worker%headcalc%dfdhu, worker%headcalc%dfdhm, worker%headcalc%dfdhl, worker%headcalc%residual, worker%headcalc%difh, ierror)\n      worker%diagnostics%linear_solves = worker%diagnostics%linear_solves + 1\n','linear count')
    s=replace_once(s,'         call alternative_solver()\n','         worker%diagnostics%alternative_solver_calls = worker%diagnostics%alternative_solver_calls + 1\n         call alternative_solver()\n','alternative count')
    s=replace_once(s,'      do itry = 1, MaxBackTr\n','      do itry = 1, MaxBackTr\n         worker%diagnostics%backtracking_attempts = worker%diagnostics%backtracking_attempts + 1\n','backtracking count')
    if re.search(r'\bsave\b', s, flags=re.IGNORECASE):
        for line in s.splitlines():
            if re.search(r'::.*\bsave\b|\bsave\s*::|,\s*save\b',line,flags=re.I):
                raise ValueError(f'headcalc SAVE declaration remains: {line}')
    path.write_text(s,encoding='latin1',newline='')

def transform_soilwater(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'      subroutine soilwater(task) \n','      subroutine soilwater(task, worker) \n','soilwater signature')
    anchor='      use MOD_swap_base, only: swmacro, swinco, swhyst, swsolve\n'
    s=replace_once(s,anchor,anchor+'      use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t\n','soilwater use')
    s=replace_once(s,'      integer, intent(in)  :: task\n','      integer, intent(in)  :: task\n      type(a23bp_worker_context_t), intent(inout), optional :: worker\n','soilwater dummy')
    s=replace_once(s,'            call headcalc\n',"            if (.not. present(worker)) error stop 'A23BP SoilWater: worker context required for Richards advance'\n            call headcalc(worker)\n",'soilwater headcalc call')
    anchor='      implicit none\n!     global\n'
    iface="""      implicit none
      interface
         subroutine headcalc(worker)
            use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t
            type(a23bp_worker_context_t), intent(inout) :: worker
         end subroutine headcalc
      end interface
!     global
"""
    s=replace_once(s,anchor,iface,'soilwater interface')
    path.write_text(s,encoding='latin1',newline='')

def transform_timecontrol(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'   subroutine TimeControl(task)\n','   subroutine TimeControl(task, worker)\n','timecontrol signature')
    anchor='   use MOD_timer\n'
    s=replace_once(s,anchor,anchor+'   use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t, a23bp_record_internal_retry\n','timecontrol use')
    s=replace_once(s,'   integer, intent(in) :: task\n','   integer, intent(in) :: task\n   type(a23bp_worker_context_t), intent(inout), optional :: worker\n','timecontrol dummy')
    anchor='      if (fldecdt) then\n'
    s=replace_once(s,anchor,anchor+'         if (present(worker)) call a23bp_record_internal_retry(worker)\n','retry hook')
    path.write_text(s,encoding='latin1',newline='')

def transform_swap(path: Path):
    s=path.read_text(encoding='latin1')
    old='   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap)\n'
    new='   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, worker, toswap, fromswap)\n'
    s=replace_once(s,old,new,'SWAP interface signature')
    anchor='      use MOD_arrays, only: fillen\n'
    s=replace_once(s,anchor,anchor+'      use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t\n','SWAP interface use')
    s=replace_once(s,'      type(swap_output),      intent(out),   optional :: fromswap\n',
                   '      type(swap_output),      intent(out),   optional :: fromswap\n      type(a23bp_worker_context_t), intent(inout), optional :: worker\n','SWAP interface dummy')
    s=replace_once(s,'call SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap)\n',
                   'call SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap=toswap, fromswap=fromswap)\n','SWAP_4_DFF call')
    s=replace_once(s,'subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) \n',
                   'subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, worker, toswap, fromswap) \n','SWAP actual signature')
    anchor='use swap_exchange\n'
    apos=s.find('subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, worker, toswap, fromswap) ')
    pos=s.find(anchor, apos)
    if pos < 0: raise ValueError('actual SWAP swap_exchange use missing')
    s=s[:pos]+anchor+'use mod_a23bp_worker_execution_context, only: a23bp_worker_context_t\n'+s[pos+len(anchor):]
    actual_dummy='type(swap_output),      intent(out),   optional :: fromswap\n\n! local\n'
    apos=s.find('subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, worker, toswap, fromswap) ')
    dpos=s.find(actual_dummy, apos)
    if dpos < 0: raise ValueError('SWAP actual dummy anchor missing after actual signature')
    s=s[:dpos]+'type(swap_output),      intent(out),   optional :: fromswap\ntype(a23bp_worker_context_t), intent(inout), optional :: worker\n\n! local\n'+s[dpos+len(actual_dummy):]
    s=re.sub(r'call\s+TimeControl\(([^\n\)]*)\)', r'call TimeControl(\1, worker)', s, flags=re.I)
    s=re.sub(r'call\s+SoilWater\(([^\n\)]*)\)', r'call SoilWater(\1, worker)', s, flags=re.I)
    path.write_text(s,encoding='latin1',newline='')

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--source',type=Path,required=True); ap.add_argument('--output',type=Path,required=True); ap.add_argument('--ttutil-prefs',type=Path,required=True)
    ns=ap.parse_args()
    parent=manifest(ns.source)
    if sha256_bytes(parent)!=EXPECTED_PARENT_MANIFEST: raise ValueError('A23BP parent is not exact B1.6')
    if ns.output.exists(): shutil.rmtree(ns.output)
    shutil.copytree(ns.source,ns.output)
    for p in ns.output.glob('*.f90'):
        text=p.read_text(encoding='latin1'); text=''.join(convert_dec(line) for line in text.splitlines(True)); p.write_text(text,encoding='latin1',newline='')
    shutil.copy2(ns.ttutil_prefs,ns.output/'ttutilprefs.f90')
    transform_headcalc(ns.output/'headcalc.f90')
    transform_soilwater(ns.output/'soilwater.f90')
    transform_timecontrol(ns.output/'timecontrol.f90')
    transform_swap(ns.output/'swap.f90')
    hashes={p.name:sha256_bytes(p.read_bytes()) for p in [ns.output/'headcalc.f90',ns.output/'soilwater.f90',ns.output/'timecontrol.f90',ns.output/'swap.f90']}
    print(json.dumps({'parent_manifest_sha256':EXPECTED_PARENT_MANIFEST,'postimage_sha256':hashes},sort_keys=True,indent=2))

if __name__=='__main__': main()
