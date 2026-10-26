"""Materialize immutable original reader procedures and original TTUTIL providers."""
import base64,hashlib,io,tarfile,zipfile
from pathlib import Path
B111='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
def materialize(root,out):
 archive=root/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz') as tar:
  solute=tar.extractfile('SWAP/solute.f90').read()
  assert hashlib.sha256(solute).hexdigest()==B111
  functions=tar.extractfile('SWAP/functions.f90').read().decode('latin1')
 text=solute.decode('latin1');a=text.index('      subroutine read_solute_CDE');b=text.index('      end subroutine read_solute_CDE',a)+len('      end subroutine read_solute_CDE')
 reader=text[a:b]
 reader=reader.replace('use MOD_swap_base, only:', 'use legacy_swp_context, only:').replace('use MOD_grid,      only:', 'use legacy_swp_context, only:')
 generated="""module legacy_swp_context
 implicit none
 integer::unit_swp=71,unit_err=0,swcrop=0,swsolu=1,numlay=0
 character(1024)::swpfilnam
 logical::fl_initialize=.false.
end module
module mod_swp_original_chemistry
 use legacy_swp_context
 implicit none
 integer::nconc,ncseep,swbotbc,swbr,swsba=0,swsp,swdc
 real(8)::cpre,cdrain,cseep,ddif,tscf,frexp,cref,gampar,rtheta,bexp,daquif,poros,kfsat,decsat
 real(8),allocatable::cmltb(:),cseeptab(:),kf(:),ldis(:),decpot(:),fdepth(:)
contains
"""+reader+'\nend module\n'
 # These historical utilities remain exact, including the original interpolation.
 for name in ['afgen_2','rdadortb']:
  import re
  match=re.search(r'^\s*subroutine '+name+r'\b.*?^\s*end subroutine '+name+r'\b',functions,re.M|re.I|re.S)
  assert match,name
  generated+=match.group()+'\n'
 path=out/'legacy_swp_original.f90';path.write_text(generated)
 raw=base64.b64decode((root/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
 assert hashlib.sha256(raw).hexdigest()=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
 folder=out/'historical-input'
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in z.namelist())
  z.extractall(folder)
 tt=folder/'TTUTIL';first=['ttutilprefs.f90','ttutil.f90','outdat.f90','rdmodulettutil.f90']
 providers=[tt/n for n in first]+[p for p in sorted(tt.glob('*.f90'))+sorted(tt.glob('*.for')) if p.name not in first]
 return path,providers

def materialize_macro_geometry(root,out):
    """Exact original geometry/read procedures in an isolated preparation context."""
    import re
    archive=root/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz')as tar:
        raw={n:tar.extractfile('SWAP/'+n).read()for n in ['arrays.f90','variables.f90','macropore.f90']}
    assert hashlib.sha256(raw['macropore.f90']).hexdigest()=='f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f'
    arrays=raw['arrays.f90'].decode('latin1')
    normal=arrays.split('!DEC$ ELSE',1)[1].split('!DEC$ END IF',1)[0]
    arrays='module MOD_arrays\n'+normal+'\nend module MOD_arrays\n'
    variables=raw['variables.f90'].decode('latin1');m=re.search(r'^module MOD_swap_mp\b.*?^end module MOD_swap_mp',variables,re.I|re.M|re.S);assert m
    shared=m.group()+'\n'
    macro=raw['macropore.f90'].decode('latin1');header=macro[:macro.lower().index('   contains')]
    # These two public names belong to unselected execution procedures. Remove
    # only that declaration; all selected scientific procedure bytes stay exact.
    header=re.sub(r'^\s*public :: macrostatevar, macropore\s*$', '',header,flags=re.M|re.I)
    procedures=[]
    for name in ['MACROGEOM','DEFINECOMPART','DiamPolyg','read_macropore']:
        pattern=(r'^\s*real\(8\)\s+FUNCTION 'if name=='DiamPolyg'else r'^\s*SUBROUTINE ')+name+r'\b.*?^\s*end\s+(?:subroutine|function)\s+'+name+r'\b'
        p=re.search(pattern,macro,re.M|re.I|re.S);assert p,name;procedures.append((name,p.group()))
    context='''module MOD_grid
 use MOD_arrays,only:macp,maho
 implicit none
 integer::numnod=0,numlay=0
 real(8),allocatable::z(:),dz(:),zbotcp(:)
 integer,allocatable::layer(:)
end module
module variables
 use MOD_arrays,only:maho
 implicit none
 real(8)::ksatfit(maho)=0d0
end module
module MOD_swap_base
 implicit none
 integer::swsolu=0
end module
'''
    text=arrays+shared+context+header+'\ncontains\n'+'\n'.join(p for _,p in procedures)+'\nend module MOD_macropore\n'
    path=out/'original_macro_geometry.f90';path.write_bytes(text.encode('latin1'))
    identity=dict(raw_sha256={n:hashlib.sha256(b).hexdigest()for n,b in raw.items()},procedure_sha256={n:hashlib.sha256(p.encode('latin1')).hexdigest()for n,p in procedures},generated_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),original_array_branch='non-multiswap DEC ELSE; exact constants',scope='read_macropore/MACROGEOM/DEFINECOMPART/DiamPolyg only')
    return path,identity
