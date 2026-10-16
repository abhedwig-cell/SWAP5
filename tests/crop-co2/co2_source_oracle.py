"""Authenticated literal historical response, with renamed external AFGEN symbol."""
import base64,hashlib,io,tarfile

def prepare(root,target):
 capsule=root/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(capsule.read_bytes())))as t:
  raw=t.extractfile('SWAP/MOD_cropdevelopment.f90').read();functions=t.extractfile('SWAP/functions.f90').read()
 assert hashlib.sha256(raw).hexdigest()=='aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210'
 assert hashlib.sha256(functions).hexdigest()=='b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
 s=functions.decode().replace('\r\n','\n');start=s.index('   real(8) function afgen (');end=s.index('   end function afgen',start)+len('   end function afgen')
 afgen=s[start:end].replace('afgen','b111_co2_afgen')
 text=raw.decode().replace('\r\n','\n')
 lines=['               fco2amax = afgen(co2amaxtb, macroptb, co2)', '               fco2eff = afgen(co2efftb, macroptb ,co2)', '            fco2tra = afgen(co2tratb, macroptb, co2)']
 assert all(text.count(line)==1 for line in lines)
 target.write_text('''subroutine b111_co2_response(co2,eff,amax,tra,factors)
use iso_fortran_env,only:real64
implicit none
integer,parameter::macroptb=6
real(real64),intent(in)::co2,eff(6),amax(6),tra(6)
real(real64),intent(out)::factors(3)
real(real64)::co2efftb(6),co2amaxtb(6),co2tratb(6),fco2amax,fco2eff,fco2tra,b111_co2_afgen
co2efftb=eff;co2amaxtb=amax;co2tratb=tra
'''+ '\n'.join(lines).replace('afgen','b111_co2_afgen')+ '\nfactors=[fco2eff,fco2amax,fco2tra]\nend subroutine\n'+afgen+'\n')
 return {'cropdevelopment_sha256':hashlib.sha256(raw).hexdigest(),'functions_sha256':hashlib.sha256(functions).hexdigest(),'oracle_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
