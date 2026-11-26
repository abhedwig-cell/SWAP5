"""Source-bound physical trial origin, ported from qualified rollback39aac77.
Private worker state only; retry controls and native wire stay unchanged.
"""
import re
from donor_sources import replace

PHYSICAL_FIELDS=('ICpBtDm','VlMpDmCp','WaUnMpDmCp','FlEndSrpEvt','ThtSrpRefDmCp',
    'SorpDmCp','TimAbsCumDmCp','VlMpDyCp','SubsidCp','FrMpWalWet','ICpBtDmPot',
    'ICpTpWaSrDm','ZWaLevDm','ZBtDm','VlMpDm','VlMp','ArMpTp','ArMpTpDm',
    'ArMpSs','KsMpSs','FrArMtrx','WaSrMp','WaSrMpDm','WaUnMpDm','WaUnsat')


def render(source,variables):
    source=source.replace('\r\n','\n');variables=variables.replace('\r\n','\n')
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

