#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, shutil, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import a23bp_prepare_worker_source as bp

PARENT_MANIFEST = bp.EXPECTED_PARENT_MANIFEST

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def replace_once(text: str, old: str, new: str, label: str) -> str:
    n=text.count(old)
    if n != 1:
        raise ValueError(f'{label}: expected one anchor, got {n}')
    return text.replace(old,new,1)

def rename_context_refs(root: Path):
    for p in root.glob('*.f90'):
        s=p.read_text(encoding='latin1')
        s=s.replace('mod_a23bp_worker_execution_context','mod_a23bq_worker_execution_context')
        s=s.replace('a23bp_worker_context_t','a23bq_worker_context_t')
        s=s.replace('a23bp_record_internal_retry','a23bq_record_internal_retry')
        p.write_text(s,encoding='latin1',newline='')

def transform_headcalc(path: Path):
    s=path.read_text(encoding='latin1')
    s=s.replace('fllowgwl, k, dimoca, numbit, fldecdt, gwl','fllowgwl, k, dimoca, gwl')
    use='use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t\n'
    s=replace_once(s,use,'use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t, a23bq_request_dt_reduction\n','headcalc control import')
    decl='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror\n'
    s=replace_once(s,decl,decl+'   integer                          :: numbit_local\n','headcalc numbit local')
    s=re.sub(r'\bnumbit\b','numbit_local',s,flags=re.I)
    loop='   do numbit_local = 1, MaxIt1\n'
    s=replace_once(s,loop,'   worker%control%last_numbit = 0\n'+loop+'      worker%control%last_numbit = numbit_local\n','headcalc worker numbit')
    s=replace_once(s,'      fldecdt = .TRUE.\n','      call a23bq_request_dt_reduction(worker)\n','headcalc retry request')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b|\bnumbit\b', code, flags=re.I):
        raise ValueError('headcalc still references legacy numbit/fldecdt')
    path.write_text(s,encoding='latin1',newline='')

def transform_timecontrol(path: Path):
    s=path.read_text(encoding='latin1')
    s=s.replace('a23bq_worker_context_t, a23bq_record_internal_retry',
                'a23bq_worker_context_t, a23bq_record_internal_retry, a23bq_reset_numerical_control')
    s=re.sub(r'\bfldecdt,\s*','',s,count=1,flags=re.I)
    s=re.sub(r'\bnumbit,\s*','',s,count=1,flags=re.I)
    if s.count('      fldecdt = .FALSE.\n') < 2:
        raise ValueError('timecontrol fldecdt reset anchors missing')
    s=s.replace('      fldecdt = .FALSE.\n',
                '      if (present(worker)) call a23bq_reset_numerical_control(worker)\n',1)
    s=replace_once(s,'         if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)\n         if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)\n',
                   "         if (.not. present(worker)) error stop 'A23BQ TimeControl(3): worker context required'\n         if (worker%control%last_numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)\n         if (worker%control%last_numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)\n",
                   'timecontrol numbit policy')
    s=replace_once(s,'      if (fldecdt) then\n',
                   "      if (.not. present(worker)) error stop 'A23BQ TimeControl(5): worker context required'\n      if (worker%control%request_dt_reduction) then\n",
                   'timecontrol retry condition')
    s=replace_once(s,'         fldecdt = .FALSE.\n         return\n',
                   '         worker%control%request_dt_reduction = .false.\n         return\n',
                   'timecontrol retry reset')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b|\bnumbit\b', code, flags=re.I):
        raise ValueError('timecontrol still references legacy numbit/fldecdt')
    path.write_text(s,encoding='latin1',newline='')

def transform_surfacewater(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'      subroutine SurfaceWater(itask)\n','      subroutine SurfaceWater(itask, worker)\n','surfacewater signature')
    anchor='      use MOD_grid,      only: numnod, dz\n'
    s=replace_once(s,anchor,anchor+'      use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t, a23bq_request_dt_reduction\n','surfacewater worker use')
    anchor='      integer, intent(in)  :: itask\n'
    s=replace_once(s,anchor,anchor+'      type(a23bq_worker_context_t), intent(inout) :: worker\n','surfacewater worker dummy')
    s=s.replace('use variables,     only: tcum,gwl,runots,t,thetas,theta,h,fldecdt,fldtmin,rsro,pond,pondmx',
                'use variables,     only: tcum,gwl,runots,t,thetas,theta,h,fldtmin,rsro,pond,pondmx',1)
    s=s.replace('fldecdt = .TRUE.','call a23bq_request_dt_reduction(worker)')
    s=s.replace('fldecdt = .true.','call a23bq_request_dt_reduction(worker)')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b',code,flags=re.I):
        raise ValueError('surfacewater still references fldecdt')
    path.write_text(s,encoding='latin1',newline='')

def transform_drain(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'   subroutine drain(itask)\n','   subroutine drain(itask, worker)\n','drain signature')
    s=replace_once(s,'      use MOD_swap_base, only: swdra\n      use variables,     only: fldecdt\n',
                   '      use MOD_swap_base, only: swdra\n      use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t\n',
                   'drain use')
    s=replace_once(s,'      integer, intent(in) :: itask\n',
                   '      integer, intent(in) :: itask\n      type(a23bq_worker_context_t), intent(inout), optional :: worker\n      interface\n         subroutine surfacewater(itask, worker)\n            use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t\n            integer, intent(in) :: itask\n            type(a23bq_worker_context_t), intent(inout) :: worker\n         end subroutine surfacewater\n      end interface\n',
                   'drain worker dummy')
    s=replace_once(s,'            if (.NOT.fldecdt) call surfacewater(itask)\n',
                   "            if (.not. present(worker)) error stop 'A23BQ drain: worker context required for extended drainage'\n            if (.not. worker%control%request_dt_reduction) call surfacewater(itask, worker)\n",
                   'drain retry condition')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b',code,flags=re.I):
        raise ValueError('drain still references fldecdt')
    path.write_text(s,encoding='latin1',newline='')

def transform_swap(path: Path):
    s=path.read_text(encoding='latin1')
    s=re.sub(r'\bfldecdt,\s*','',s,count=1,flags=re.I)
    s=s.replace('use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t\n',
                'use mod_a23bq_worker_execution_context, only: a23bq_worker_context_t, a23bq_reset_numerical_control\n')
    s=replace_once(s,'   fldecdt    = .FALSE.\n',
                   "   if (.not. present(worker)) error stop 'A23BQ SWAP dynamic: worker context required'\n   call a23bq_reset_numerical_control(worker)\n",
                   'swap dynamic retry reset')
    s=re.sub(r'call\s+drain\((2|3)\)', r'call drain(\1, worker)', s, flags=re.I)
    s=replace_once(s,'         if (.NOT.fldecdt) call SoilWater(2, worker)\n',
                   '         if (.not. worker%control%request_dt_reduction) call SoilWater(2, worker)\n',
                   'swap soilwater retry condition')
    s=replace_once(s,'         if (fldecdt .OR. (swmacro == 1 .AND. FlDecMpRat)) then\n',
                   '         if (worker%control%request_dt_reduction .OR. (swmacro == 1 .AND. FlDecMpRat)) then\n',
                   'swap retry branch')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b',code,flags=re.I):
        raise ValueError('swap still references fldecdt')
    path.write_text(s,encoding='latin1',newline='')

def transform_variables(path: Path):
    s=path.read_text(encoding='latin1')
    s=replace_once(s,'   logical                    :: fldecdt            ! Flag indicating decrease of time step\n','', 'variables remove fldecdt')
    s=replace_once(s,'   integer                    :: numbit             ! Iteration number for solving Richards equation\n','', 'variables remove numbit')
    path.write_text(s,encoding='latin1',newline='')

def transform_initialize(path: Path):
    s=path.read_text(encoding='latin1')
    s=re.sub(r'\bfldecdt,\s*','',s,count=1,flags=re.I)
    s=re.sub(r'\bnumbit,\s*','',s,count=1,flags=re.I)
    s=replace_once(s,'      fldecdt            = .FALSE. \n','', 'initialize remove fldecdt')
    s=replace_once(s,'      numbit             = 0 \n','', 'initialize remove numbit')
    code='\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldecdt\b|\bnumbit\b', code, flags=re.I):
        raise ValueError('initialize still references removed controls')
    path.write_text(s,encoding='latin1',newline='')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--ttutil-prefs',type=Path,required=True)
    ns=ap.parse_args()
    parent=bp.manifest(ns.source)
    if bp.sha256_bytes(parent)!=PARENT_MANIFEST:
        raise ValueError('A23BQ parent is not exact B1.6')
    if ns.output.exists(): shutil.rmtree(ns.output)
    shutil.copytree(ns.source,ns.output)
    for p in ns.output.glob('*.f90'):
        text=p.read_text(encoding='latin1')
        text=''.join(bp.convert_dec(line) for line in text.splitlines(True))
        p.write_text(text,encoding='latin1',newline='')
    shutil.copy2(ns.ttutil_prefs,ns.output/'ttutilprefs.f90')
    bp.transform_headcalc(ns.output/'headcalc.f90')
    bp.transform_soilwater(ns.output/'soilwater.f90')
    bp.transform_timecontrol(ns.output/'timecontrol.f90')
    bp.transform_swap(ns.output/'swap.f90')
    rename_context_refs(ns.output)
    transform_headcalc(ns.output/'headcalc.f90')
    transform_timecontrol(ns.output/'timecontrol.f90')
    transform_surfacewater(ns.output/'surfacewater.f90')
    transform_drain(ns.output/'MOD_drainage.f90')
    transform_swap(ns.output/'swap.f90')
    transform_variables(ns.output/'variables.f90')
    transform_initialize(ns.output/'initialize.f90')
    targets=['headcalc.f90','soilwater.f90','timecontrol.f90','swap.f90','surfacewater.f90','MOD_drainage.f90','variables.f90','initialize.f90']
    hashes={name:sha256_bytes((ns.output/name).read_bytes()) for name in targets}
    print(json.dumps({'parent_manifest_sha256':PARENT_MANIFEST,'postimage_sha256':hashes,
                      'control_extracted':['variables%numbit','variables%fldecdt']},sort_keys=True,indent=2))

if __name__=='__main__': main()
