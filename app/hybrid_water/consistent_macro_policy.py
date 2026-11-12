"""Opt-in candidate: original macro rates/Jacobian from one explicit trial origin.

The existing S5MAC006 checkpoint variables are the owned physical state envelope.
Only active domain/node slices are copied. No original formula or tolerance is
changed. The original public builder does not select this experimental policy.
"""
import copy
import json
from pathlib import Path
import re
import shutil
import subprocess
import daily_host as h
from daily_coupling import validate_bundle
from donor_sources import replace, saved_names

POLICY='original-macro-explicit-trial-origin-rate-jacobian-v1'


def render_macro(source,variables):
    local=source.split('! --- Macropore variables',1)[1].split('contains',1)[0]
    shared=variables.split('module MOD_swap_mp\n',1)[1].split('end module',1)[0]
    fields=saved_names(local)+saved_names(shared)
    fields=[n for n in fields if n.lower() not in ('bma','numdm','hybrid_integral_wall_previous')]
    declarations={}
    for line in (local+'\n'+shared).splitlines():
        m=re.match(r'\s*(real\(8\)|integer|logical)\s*,(.*?)save\s*::\s*(\w+)\s*=',line,re.I)
        if m:
            dims=re.search(r'dimension\(([^)]+)\)',m[2],re.I)
            declarations[m[3].lower()]=(m[1],dims[1].lower().split(',') if dims else [])
    decl=[];capture=[];restore=[]
    for name in fields:
        kind,dims=declarations[name.lower()]
        if dims:
            assert set(dims)<={'madm','macp','maho','madr'}
            decl.append(f'      {kind}, allocatable :: {name}('+','.join(':' for _ in dims)+')')
            section='('+','.join('1:'+{'madm':'NumDm','macp':'NumNod'}.get(d,d) for d in dims)+')'
        else:
            decl.append(f'      {kind} :: {name}');section=''
        capture.append(f'      state%{name} = {name}{section}')
        restore.append(f'      {name}{section} = state%{name}')
    state='   type macro_trial_origin\n'+'\n'.join(decl)+'\n   end type macro_trial_origin\n'
    routines='''
    subroutine capture_macro_trial(state)
      use MOD_grid, only: numnod
      type(macro_trial_origin), intent(out) :: state
'''+ '\n'.join(capture)+'''
    end subroutine capture_macro_trial
    subroutine restore_macro_trial(state)
      use MOD_grid, only: numnod
      type(macro_trial_origin), intent(in) :: state
'''+ '\n'.join(restore)+'''
    end subroutine restore_macro_trial
'''
    source=replace(source,'   contains\n',state+'\n   contains\n'+routines)
    return source,fields


def render_headcalc(source):
    source=replace(source,'only: macropore\n','only: macropore, macro_trial_origin, capture_macro_trial, restore_macro_trial\n')
    source=replace(source,'   real(8)                          :: QMpLatSsSav, lateral_before_pond',
        '   real(8)                          :: QMpLatSsSav, lateral_before_pond\n   type(macro_trial_origin) :: macro_origin')
    source=replace(source,'!  summation of sink terms (constant for the current time step)',
        '   if (swmacro == 1) call capture_macro_trial(macro_origin)\n\n!  summation of sink terms (constant for the current time step)')
    source=replace(source,'!  top layer\n',
        '   if (swmacro == 1) call restore_macro_trial(macro_origin)\n\n!  top layer\n')
    a=source.index('!  depending on iTask\n',source.index('subroutine vector_F'))
    b=source.index('!  take care of top BC: ponding, runoff',a)
    source=source[:a]+'''!  Original task3 computes BOTH the current rates and their derivatives.
   call boundtop(2)
   if (swmacro == 1) call MACROPORE(3)

'''+source[b:]
    source=replace(source,'   if (swmacro == 1 .AND. .NOT.flunsatok(3)) then\n      call MACROPORE(3)',
        '   if (swmacro == 1) then\n      ! Rates and derivatives already belong to the same vector_F evaluation.')
    return source


def build_bundle(base,reference,target):
    base,reference,target=map(Path,(base,reference,target))
    meta,_=validate_bundle(base,reference,h.ANDELST)
    assert meta['binding'].get('macro_policy')=='original-nonlinear-macro-block-explicit-integral-history-v1'
    identity=copy.deepcopy(meta['identity']);objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
    for name,sha in identity['donor_objects'].items():assert h.sha(objects/name)==sha
    assert h.sha(ttutil/'libttutil.a')==identity['ttutil_library']
    shutil.copytree(base,target)
    variables=(reference/'build/swap-selected/variables.f90').read_text(encoding='cp1252')
    p=target/'macropore.f90';source,fields=render_macro(p.read_text(encoding='cp1252'),variables);p.write_text(source,encoding='cp1252')
    p=target/'headcalc.f90';p.write_text(render_headcalc(p.read_text(encoding='cp1252')),encoding='cp1252')
    commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',name] for name in ['macropore.f90','headcalc.f90','swap_main.f90']]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
        *(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
    logs=[]
    for cmd in commands:
        r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=30)
        logs.append({'command':cmd,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        (target/'CONSISTENT_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if r.returncode:raise ValueError(r.stderr)
    for name in ('macropore.f90','headcalc.f90'):identity['donor_generated'][name]=h.sha(target/name)
    identity['consistent_macro_policy']={'name':POLICY,'generator_sha256':h.sha(Path(__file__)),
        'explicit_trial_fields':fields,'original_native_codec':'UNCHANGED_S5MAC006',
        'objects_sha256':{n:h.sha(target/n) for n in ('macropore.o','headcalc.o','swap_main.o')}}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity,'macro_policy':POLICY}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
    return target
