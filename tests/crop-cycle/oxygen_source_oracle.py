"""Extract literal B1.11 drought/wet sink arithmetic, never production physics."""
import base64, hashlib, io, tarfile
from pathlib import Path

def prepare(root, target):
    capsule=root/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(capsule.read_bytes())),mode='r:gz') as donor:
        raw=donor.extractfile('SWAP/rootextraction.f90').read()
    assert hashlib.sha256(raw).hexdigest()=='8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5'
    text=raw.decode().replace('\r\n','\n').split('! --- DROUGHT REDUCTION ACCORDING TO FEDDES ET AL. (1978)',1)[1]
    def section(first,last):
        assert text.count(first)==1 and text.count(last)==1
        return first+text.split(first,1)[1].split(last,1)[0]
    potential=section('   do node = 1,noddrz','! --- calculating critical point hlim3')
    critical=section('   if (ptra < adcrl) then','! === COMBINATION OF OXYGEN')
    wet=section('            if (node > botcom(1)) then','          ! Bartholomeus non-linear reduction')
    dry=section('      if (h(node) < hlim4) then','! ---   reduction due to salt stress')
    header='''subroutine b111_root_sink(n,noddrz,upper,enabled,h,ptra,cumdens_top,limits,qrot)
use iso_fortran_env,only:real64
implicit none
integer,intent(in)::n,noddrz,upper
logical,intent(in)::enabled
real(real64),intent(in)::h(n),ptra,cumdens_top(noddrz+1),limits(8)
real(real64),intent(out)::qrot(n)
real(real64)::hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1,hlim2u,hlim2l,hlim2,hlim3,alpdry,alpwet,alpsol,alpfrs
integer::node,botcom(1)
hlim3l=limits(1);hlim3h=limits(2);hlim4=limits(3);adcrl=limits(4);adcrh=limits(5)
hlim1=limits(6);hlim2u=limits(7);hlim2l=limits(8);botcom(1)=upper
qrot=0.0_real64
if(noddrz==0.or.ptra<1.e-10_real64)return
'''
    body=potential+critical+'do node=1,noddrz\nalpwet=1.0_real64;alpdry=1.0_real64;alpsol=1.0_real64;alpfrs=1.0_real64\nif(enabled)then\n'+wet+'end if\n'+dry+'       qrot(node)    = qrot(node) * alpwet * alpdry * alpsol * alpfrs\nend do\nend subroutine\n'
    target.write_text(header+body)
    return {'member':'SWAP/rootextraction.f90','sha256':hashlib.sha256(raw).hexdigest(),'oracle_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
