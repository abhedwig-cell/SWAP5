"""Complete the original numerical rejection's physical macropore rollback.

This is not a different nonlinear solver. It retains the original retry-control
flags, rate/Jacobian policy, formulas and tolerances. The active physical state
is saved at original MacroStateVar(1) and restored only at MacroStateVar(2).
The origin is ephemeral: the next trial always saves before a possible restore.
"""
import copy
import json
from pathlib import Path
import re
import shutil
import subprocess
import daily_host as h
from daily_coupling import validate_bundle
from donor_sources import replace

POLICY='original-macro-complete-numerical-physical-rollback-v1'
PHYSICAL_FIELDS=('ICpBtDm','VlMpDmCp','WaUnMpDmCp','FlEndSrpEvt','ThtSrpRefDmCp',
    'SorpDmCp','TimAbsCumDmCp','VlMpDyCp','SubsidCp','FrMpWalWet','ICpBtDmPot',
    'ICpTpWaSrDm','ZWaLevDm','ZBtDm','VlMpDm','VlMp','ArMpTp','ArMpTpDm',
    'ArMpSs','KsMpSs','FrArMtrx','WaSrMp','WaSrMpDm','WaUnMpDm','WaUnsat')


def render(source,variables):
    definitions={}
    for line in (source.split('contains',1)[0]+'\n'+variables.split('module MOD_swap_mp\n',1)[1].split('end module',1)[0]).splitlines():
        m=re.match(r'\s*(real\(8\)|integer|logical)\s*,(.*?)save\s*::\s*(\w+)\s*=',line,re.I)
        if m:
            dims=re.search(r'dimension\(([^)]+)\)',m[2],re.I)
            definitions[m[3].lower()]=(m[1],dims[1].lower().split(',') if dims else [])
    declarations=[];save=[];restore=[]
    for name in PHYSICAL_FIELDS:
        kind,dims=definitions[name.lower()]
        if not set(dims)<={'madm','macp'}:raise ValueError('Foreign physical state shape')
        shape='('+','.join(':' for _ in dims)+')' if dims else ''
        section='('+','.join('1:'+{'madm':'NumDm','macp':'NumNod'}[d] for d in dims)+')' if dims else ''
        declarations.append(f'      {kind}'+(', allocatable' if dims else '')+f' :: {name}{shape}')
        save.append(f'         numerical_origin%{name} = {name}{section}')
        restore.append(f'         {name}{section} = numerical_origin%{name}')
    state='   type numerical_macro_origin\n'+'\n'.join(declarations)+'''\n   end type
   type(numerical_macro_origin), save :: numerical_origin
   logical, save :: numerical_origin_valid = .false.
'''
    routine='''
   subroutine physical_numerical_rollback(task)
      use MOD_grid, only: numnod
      integer, intent(in) :: task
      if (task == 1) then
'''+ '\n'.join(save)+'''
         numerical_origin_valid = .true.
      else if (task == 2) then
         if (.not. numerical_origin_valid) error stop 'Missing numerical macro origin'
'''+ '\n'.join(restore)+'''
      end if
   end subroutine physical_numerical_rollback
'''
    source=replace(source,'   contains\n',state+'\n   contains\n'+routine)
    a=source.index('      SUBROUTINE MACROSTATEVAR (task)');b=source.index('    end subroutine MacroStateVar',a)
    source=source[:a]+replace(source[a:b],'      return','      call physical_numerical_rollback(task)\n      return')+source[b:]
    return source


def build_bundle(base,reference,target,*,owner_optimization='O2'):
    if owner_optimization not in ('O0','O2'):raise ValueError('Unqualified owner optimization')
    base,reference,target=map(Path,(base,reference,target))
    meta,_=validate_bundle(base,reference,h.ANDELST)
    if meta['binding'].get('macro_policy')!='original-nonlinear-macro-block-explicit-integral-history-v1':
        raise ValueError('Exact original macro state policy required')
    identity=copy.deepcopy(meta['identity']);objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    if h.sha(Path(shutil.which('gfortran')))!=identity['compiler_sha256']:raise ValueError('Different compiler')
    for name,sha in identity['donor_objects'].items():
        if h.sha(objects/name)!=sha:raise ValueError('Foreign original object: '+name)
    if h.sha(ttutil/'libttutil.a')!=identity['ttutil_library']:raise ValueError('Foreign utility library')
    shutil.copytree(base,target)
    p=target/'macropore.f90'
    p.write_text(render(p.read_text(encoding='cp1252'),(reference/'build/swap-selected/variables.f90').read_text(encoding='cp1252')),encoding='cp1252')
    flags=[('-'+owner_optimization if f in ('-O0','-O2') else f) for f in identity['donor_flags']]
    identity['original_pool_donor_flags']=identity['donor_flags']
    identity['donor_flags']=flags
    commands=[['gfortran',*flags,'-I',str(objects),'-I',str(ttutil),'-c',name] for name in ('macropore.f90','headcalc.f90','swap_main.f90')]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
        *(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
    logs=[]
    for command in commands:
        result=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=30)
        logs.append({'command':command,'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        (target/'NUMERICAL_ROLLBACK_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if result.returncode:raise ValueError(result.stderr)
    identity['donor_generated']['macropore.f90']=h.sha(target/'macropore.f90')
    identity['numerical_rollback']={'policy':POLICY,'generator_sha256':h.sha(Path(__file__)),
        'physical_fields':list(PHYSICAL_FIELDS),'owner_flags':flags,'other_original_objects':'unchanged qualified O2',
        'owner_objects_sha256':{n:h.sha(target/n) for n in ('macropore.o','headcalc.o','swap_main.o')},
        'native_codec':'UNCHANGED_S5MAC006; ephemeral origin overwritten at every original task1'}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity,'macro_policy':POLICY}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
    return target
