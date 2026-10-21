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
