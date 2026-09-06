#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, shutil, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import a23bp_prepare_worker_source as bp
import a23br_prepare_timestep_ownership_source as br

PARENT_MANIFEST = bp.EXPECTED_PARENT_MANIFEST


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise ValueError(f'{label}: expected one anchor, got {n}')
    return text.replace(old, new, 1)


def build_a23br(source: Path, output: Path, ttutil_prefs: Path) -> None:
    br.build_a23bq(source, output, ttutil_prefs)
    br.rename_context_refs(output)
    br.transform_headcalc(output/'headcalc.f90')
    br.transform_surfacewater(output/'surfacewater.f90')
    br.transform_timecontrol(output/'timecontrol.f90')
    br.transform_swap(output/'swap.f90')
    br.transform_variables(output/'variables.f90')
    br.transform_initialize(output/'initialize.f90')


def rename_context_refs(root: Path) -> None:
    for p in root.glob('*.f90'):
        s = p.read_text(encoding='latin1')
        s = s.replace('mod_a23br_worker_execution_context', 'mod_a23bs_worker_execution_context')
        s = s.replace('a23br_worker_context_t', 'a23bs_worker_context_t')
        s = s.replace('a23br_record_internal_retry', 'a23bs_record_internal_retry')
        s = s.replace('a23br_request_dt_reduction', 'a23bs_request_dt_reduction')
        s = s.replace('a23br_reset_attempt_control', 'a23bs_reset_attempt_control')
        s = s.replace('a23br_reset_all_numerical_control', 'a23bs_reset_all_numerical_control')
        s = s.replace('a23br_seed_timestep_control', 'a23bs_seed_timestep_control')
        p.write_text(s, encoding='latin1', newline='')


def transform_variables(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = replace_once(s,
        '   logical                    :: fldayend           ! Flag indicating end of day\n', '',
        'variables remove fldayend')
    s = replace_once(s,
        '   logical                    :: fldaystart         ! Flag indicating that this time step is the first one of a day\n', '',
        'variables remove fldaystart')
    path.write_text(s, encoding='latin1', newline='')


def transform_initialize(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldayend,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldaystart,\s*', '', s, count=1, flags=re.I)
    s = replace_once(s, '      fldayend           = .FALSE. \n', '', 'initialize remove fldayend')
    s = replace_once(s, '      fldaystart         = .FALSE. \n', '', 'initialize remove fldaystart')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldaystart\b|\bfldayend\b', code, re.I):
        raise ValueError('initialize still references day flags')
    path.write_text(s, encoding='latin1', newline='')


def transform_timecontrol(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldaystart,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldayend,\s*', '', s, count=1, flags=re.I)
    if s.count('      flDayStart = .TRUE.\n') != 2:
        raise ValueError('timecontrol expected two day-start true anchors')
    s = s.replace('      flDayStart = .TRUE.\n',
        '      if (present(worker)) then\n         worker%time%day_start_event = .true.\n         worker%time%day_end_event = .false.\n      end if\n', 1)
    s = re.sub(r'\bflDayStart\b', 'worker%time%day_start_event', s, flags=re.I)
    s = re.sub(r'\bflDayEnd\b', 'worker%time%day_end_event', s, flags=re.I)
    anchor='''   select case (task)\n\n   case (1)\n'''
    if anchor not in s:
        raise ValueError('timecontrol select anchor missing')
    s = s.replace('   case (2)\n', "   case (2)\n      if (.not. present(worker)) error stop 'A23BS TimeControl(2): worker context required'\n", 1)
    s = s.replace('   case (3)\n', "   case (3)\n      if (.not. present(worker)) error stop 'A23BS TimeControl(3): worker context required'\n", 1)
    s = s.replace('   case (5)\n', "   case (5)\n      if (.not. present(worker)) error stop 'A23BS TimeControl(5): worker context required'\n", 1)
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldaystart\b|\bfldayend\b', code, re.I):
        raise ValueError('timecontrol still references legacy day flags')
    path.write_text(s, encoding='latin1', newline='')


def transform_headcalc(path: Path) -> None:
    s=path.read_text(encoding='latin1')
    s = re.sub(r'\bfldaystart,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldaystart\b', 'worker%time%day_start_event', s, flags=re.I)
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldaystart\b', code, re.I):
        raise ValueError('headcalc still references legacy day start')
    path.write_text(s, encoding='latin1', newline='')


def transform_integral(path: Path) -> None:
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'      subroutine integral(iTask)\n','      subroutine integral(iTask, day_start_event)\n','integral signature')
    s=re.sub(r'\bfldaystart,\s*','',s,count=1,flags=re.I)
    anchor='      subroutine integral(iTask, day_start_event)\n'
    pos=s.index(anchor)
    pos2=s.index('      integer, intent(in) :: iTask\n', pos)
    s=s[:pos2] + '      integer, intent(in) :: iTask\n      logical, intent(in) :: day_start_event\n' + s[pos2+len('      integer, intent(in) :: iTask\n'):]
    s=re.sub(r'\bfldaystart\b','day_start_event',s,flags=re.I)
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldaystart\b',code,re.I): raise ValueError('integral legacy day flag remains')
    path.write_text(s,encoding='latin1',newline='')


def transform_swap(path: Path) -> None:
    s=path.read_text(encoding='latin1')
    s=re.sub(r'\bfldaystart,\s*','',s,count=1,flags=re.I)
    s=re.sub(r'\bfldayend,\s*','',s,count=1,flags=re.I)
    old='''   ! need to re-initialize\n   fldaystart = .TRUE.\n   flrunend   = .FALSE.\n   if (.not. present(worker)) error stop 'A23BQ SWAP dynamic: worker context required'\n   call a23bs_reset_attempt_control(worker)\n'''
    new='''   ! need to re-initialize\n   flrunend   = .FALSE.\n   if (.not. present(worker)) error stop 'A23BS SWAP dynamic: worker context required'\n   worker%time%day_start_event = .true.\n   worker%time%day_end_event = .false.\n   call a23bs_reset_attempt_control(worker)\n'''
    s=replace_once(s,old,new,'swap dynamic day event')
    s=s.replace('call integral(2)','call integral(2, worker%time%day_start_event)')
    s=s.replace('call integral(3)','call integral(3, worker%time%day_start_event)')
    s=s.replace('call integral (4)','call integral (4, worker%time%day_start_event)')
    s=re.sub(r'\bflDayStart\b','worker%time%day_start_event',s,flags=re.I)
    s=re.sub(r'\bflDayEnd\b','worker%time%day_end_event',s,flags=re.I)
    s=s.replace('      worker%time%day_start_event = .TRUE.\n',
                "      if (.not. present(worker)) error stop 'A23BS handle_exchange: worker context required'\n      worker%time%day_start_event = .true.\n      worker%time%day_end_event = .false.\n",1)
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldaystart\b|\bfldayend\b',code,re.I):
        raise ValueError('swap legacy day flags remain')
    path.write_text(s,encoding='latin1',newline='')


def transform_initialize_integral_call(path: Path) -> None:
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'      call integral(1)\n','      call integral(1, .false.)\n','initialize integral call')
    path.write_text(s,encoding='latin1',newline='')


def main() -> None:
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--ttutil-prefs',type=Path,required=True)
    ns=ap.parse_args()
    build_a23br(ns.source,ns.output,ns.ttutil_prefs)
    rename_context_refs(ns.output)
    transform_variables(ns.output/'variables.f90')
    transform_initialize(ns.output/'initialize.f90')
    transform_timecontrol(ns.output/'timecontrol.f90')
    transform_headcalc(ns.output/'headcalc.f90')
    transform_integral(ns.output/'integral.f90')
    transform_swap(ns.output/'swap.f90')
    transform_initialize_integral_call(ns.output/'initialize.f90')

    active_day_flags=[]
    for p in ns.output.glob('*.f90'):
        code='\n'.join(line.split('!')[0] for line in p.read_text(encoding='latin1').splitlines())
        if re.search(r'\bfldaystart\b|\bfldayend\b',code,re.I): active_day_flags.append(p.name)
    if active_day_flags:
        raise ValueError(f'legacy day flags remain active: {active_day_flags}')

    targets=['variables.f90','initialize.f90','timecontrol.f90','headcalc.f90','integral.f90','swap.f90']
    hashes={name:sha256_bytes((ns.output/name).read_bytes()) for name in targets}
    counts={}
    for sym in ['t1900','tcum','timjan1','daynr','daycum']:
        total=0
        for p in ns.output.glob('*.f90'):
            code='\n'.join(line.split('!')[0] for line in p.read_text(encoding='latin1').splitlines())
            total += len(re.findall(rf'\b{sym}\b',code,re.I))
        counts[sym]=total
    print(json.dumps({
      'parent_manifest_sha256':PARENT_MANIFEST,
      'postimage_sha256':hashes,
      'removed_legacy_globals':['variables%fldaystart','variables%fldayend'],
      'worker_derived_calendar_events':['worker%time%day_start_event','worker%time%day_end_event'],
      'legacy_calendar_projection_reference_counts':counts,
      'kernel_time_contract':'generic [t0,t1]; calendar projection remains adapter-only',
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
