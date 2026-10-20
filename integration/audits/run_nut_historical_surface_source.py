"""Literal historical surface/source diagnostic, NOT a full-model regression.

Prescribed top-node head/conductivity; original pond producer, whole PONDRUNOFF,
integral statements, management aggregate and unchanged SoilWaterN. No SWAP5
production code or admission envelope is changed. Fresh output directory required.
"""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ['N_SURFACE_SOURCE_RESULT_DIR']).resolve()
OUT.mkdir(exist_ok=False)
FC = shlex.split(os.environ.get('FC', 'gfortran'))
archive = base64.b64decode((ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
assert hashlib.sha256(archive).hexdigest() == '18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c'
tar = tarfile.open(fileobj=io.BytesIO(archive))
names = ['boundtop', 'integral', 'management_soil', 'wofost_soil_watern', 'swap', 'readswap', 'timecontrol']
raw = {n: tar.extractfile('SWAP/' + n + '.f90').read() for n in names}
source = {n: b.decode() for n, b in raw.items()}

def block(name, start, end):
    s = source[name]
    return s[s.index(start):s.index(end, s.index(start))]

pond = block('boundtop', '      SUBROUTINE PONDRUNOFF ()', 'end module MOD_top')
producer = block('boundtop', '         p1     = k1max/disnod(1) * dt', '! --- in case of macropores, calc.')
aggregate = block('management_soil', '      help = 1.d-2 *', '      SoilEvap =')
integration = '\n'.join(next(line for line in source['integral'].splitlines() if line.strip().startswith(prefix))
                        for prefix in ['iruno  = iruno +', 'igrai  = igrai +']) + '\n'
scaffold = '''module MOD_arrays
 integer,parameter::mairg=2
end module
module MOD_grid
 real(8)::disnod(1)=.5d0
end module
module MOD_swap_base
 integer::swdra=0,swmacro=0,swpondmx=0
end module
module variables
 real(8)::dt=1d0,t1900=0d0,h(1)=0d0,pondm1=0d0,rsro=1d0,rsroexp=1d0
 real(8)::pondmxtab(4)=0d0,pondmx=.1d0,pond=0d0,runots=0d0
end module
module MOD_swap_mp
 real(8)::QMpLatSs=0d0
end module
module MOD_drain
 real(8)::wls=0d0,swst=0d0
end module
module MOD_texture_orgmat
 real(8)::bdens(1)=1300d0
end module
module literal_top
 use MOD_grid
 use variables
 implicit none
 real(8)::h0max,k1max=.01d0,q0=0d0,hsurf
 logical::FlRunoff=.true.
 contains
 subroutine producer()
 real(8)::p1,p2
'''+producer+''' end subroutine
'''+pond+'''end module
real(8) function afgen(a,n,t)
 integer::n
 real(8)::a(n),t
 error stop 'unselected time-dependent pond table'
end function
real(8) function swstlev(p)
 real(8)::p
 error stop 'unselected surface drainage'
end function
subroutine swap_error(a,b)
 character(*)::a,b
 print *,a,b
 error stop 'original SoilWaterN error'
end subroutine
'''
driver = '''program witness
 use literal_top
 implicit none
 integer::day,k
 real(8)::graidt,igrai,isnrai,igsnow,igird,iintc,irunon,iruno,outper,help
 real(8)::water_residual,infiltration,gross,initial,final,ct,ca,prod,residual
 do day=1,2
   graidt=0d0
   if(day==1)graidt=2d0
   q0=graidt
   call producer()
   pond=h0max
   call pondrunoff()
   infiltration=k1max*(1d0+(pond-h(1))/disnod(1))*dt
   water_residual=pondm1+graidt*dt-runots-infiltration-pond
   igrai=0d0;iruno=0d0;isnrai=0d0;igsnow=0d0;igird=0d0;iintc=0d0;irunon=0d0;outper=1d0
'''+integration+aggregate+'''
   print '(A,I1,6ES25.16)','SURFACE_DAY=',day,pondm1,graidt,runots,pond,help,water_residual
   if(abs(water_residual)>1d-12)error stop 'water mass'
   if(day==1.and.help<=0d0)error stop 'wet loading'
   if(day==2.and.help>=0d0)error stop 'missing dry negative source'
   pondm1=pond
 end do
 gross=help
 do k=1,2
   initial=.002d0
   if(k==2)initial=1d-8
   call Wofost_SoilWaterN(.3d0,1d0,.3d0,.3d0,0d0,0d0,0d0,gross,0d0, &
     0d0,0d0,0d0,prod,0d0,0d0,.005d0,0d0,initial/.09d0,ct,ca)
   final=ct*.09d0
   residual=initial+gross*.005d0-final
   print '(A,I1,5ES25.16)','CONDITIONAL_N=',k,initial,gross*.005d0,final,residual,abs(residual)/(initial+abs(gross*.005d0))
   if(k==1.and.abs(residual)>1d-15)error stop 'funded mass'
   if(k==2.and.residual>=-1d-6)error stop 'missing depleted defect'
 end do
 print '(A)','LITERAL_SURFACE_SOURCE_AND_CONDITIONAL_DEPLETION=PASS'
end program
'''
events = []
outputs = {}
for opt in ['O0', 'O2']:
    build = OUT / opt
    build.mkdir()
    (build / 'surface.f90').write_text(scaffold)
    (build / 'driver.f90').write_text(driver)
    (build / 'wofost_soil_watern.f90').write_bytes(raw['wofost_soil_watern'])
    flags = ['-' + opt, '-std=f2008', '-ffree-line-length-none', '-fcheck=all', '-fbacktrace', '-ffpe-trap=invalid,zero,overflow']
    exe = build / 'witness'
    for category, command in [('compile_link', FC + flags + ['surface.f90', 'wofost_soil_watern.f90', 'driver.f90', '-o', str(exe)]), ('native', [str(exe)])]:
        start = time.perf_counter()
        r = subprocess.run(command, cwd=build, capture_output=True)
        index = len(events)
        for stream in ['stdout', 'stderr']:
            (OUT / (str(index) + '.' + stream)).write_bytes(getattr(r, stream))
        events.append(dict(category=category, command=command, seconds=time.perf_counter()-start, returncode=r.returncode, stdout=str(index)+'.stdout', stderr=str(index)+'.stderr', stdout_sha256=hashlib.sha256(r.stdout).hexdigest(), stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
        (OUT / 'events.json').write_text(json.dumps(events, indent=2)+'\n')
        r.check_returncode()
    outputs[opt] = r.stdout.decode()
assert outputs['O0'] == outputs['O2']
assert 'LITERAL_SURFACE_SOURCE_AND_CONDITIONAL_DEPLETION=PASS' in outputs['O0']
for name, data in raw.items():
    (OUT / (name + '.original.f90')).write_bytes(data)
result = dict(status='LITERAL_SURFACE_PROCESS_O0_O2_PASS', scope='Prescribed top-node state; full original hydraulic/crop caller trajectory NOT_PROVEN; depleted nitrogen stocks are conditional, not obtained from the wet day', source_sha256={n:hashlib.sha256(b).hexdigest() for n,b in raw.items()}, archive_sha256=hashlib.sha256(archive).hexdigest(), runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0], outputs=outputs, events=events)
(OUT / 'result.json').write_text(json.dumps(result, indent=2)+'\n')
print(outputs['O0'])
