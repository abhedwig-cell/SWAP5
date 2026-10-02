#!/usr/bin/env python3
"""Extract exact B1.11 bottom-row fragments; diagnostic, not production admission."""
import base64,gzip,hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
TEST=ROOT/'tests/fmig431/test_low03_boundary_composition.f90'
CARRIER=ROOT/'integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json'
member=next(m for m in json.loads(CARRIER.read_text())['members'] if m['path']=='SWAP/headcalc.f90')
raw=gzip.decompress(base64.b64decode(member['gzip_base64']))
if hashlib.sha256(raw).hexdigest()!=member['sha256']:raise RuntimeError('B1.11 source mismatch')
source=raw.decode()
def exact(pattern):
    matches=re.findall(pattern,source,re.I|re.M)
    if len(matches)!=1:raise RuntimeError('ambiguous frozen fragment: '+pattern)
    return matches[0].strip()
q0=exact(r'^\s*(qbot\s*=\s*-\s*\(h\(NN\)\+z\(NN\)-deepgw\)\s*/\s*\(disnod\(NN\+1\)/kmean\(NN\+1\)\+rimlay\))\s*$')
q1=exact(r'^\s*(qbot\s*=\s*-\s*\(h\(NN\)\+z\(NN\)-deepgw\)\s*/\s*rimlay)\s*$')
j0=exact(r'^\s*(dFdhM\(NN\)\s*=\s*dFdhM\(NN\)\s*\+\s*1\.0d0\s*/\s*\(disnod\(NN\+1\)/kmean\(NN\+1\)\s*\+\s*rimlay\))\s*$')
j1=exact(r'^\s*(dFdhM\(NN\)\s*=\s*dFdhM\(NN\)\s*\+\s*1\.0d0\s*/\s*rimlay)\s*$')
grad=exact(r'^\s*(hgrad\(NN\+1\)\s*=\s*\(h\(NN\)\s*-\s*hbot\)\s*/\s*disnod\(NN\+1\)\s*\+\s*1\.0d0)\s*$')
def function(name,body):
    return f'''real(8) function {name}(hn,zn,aq,kb,d,r,flag) result(value)
implicit none
real(8),intent(in)::hn,zn,aq,kb,d,r
integer,intent(in)::flag
integer,parameter::NN=1
real(8)::h(1),z(1),kmean(2),disnod(2),dFdhM(1),hgrad(2),deepgw,rimlay,qbot,hbot
h(1)=hn;z(1)=zn;kmean=kb;disnod=d;deepgw=aq;rimlay=r;dFdhM=0.d0
hbot=aq-(zn-d)
{body}
end function
'''
frozen='module frozen_low03_oracle\nimplicit none\ncontains\n'
frozen+=function('b111_q3',f'if(flag==0)then\n{q0}\nelse\n{q1}\nend if\nvalue=qbot')
frozen+=function('b111_j3',f'if(flag==0)then\n{j0}\nelse\n{j1}\nend if\nvalue=dFdhM(1)')
frozen+=function('q5_wrapper',grad+'\nvalue=-kmean(NN+1)*hgrad(NN+1)')
frozen+='real(8) function b111_q5(h,z,aq,k,d) result(value)\nreal(8),intent(in)::h,z,aq,k,d\nvalue=q5_wrapper(h,z,aq,k,d,0.d0,0)\nend function\nend module\n'
FC=shlex.split(os.environ.get('FC','gfortran'));LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
result={'work_unit':'F-MIG431-LOW03-P0','tested_postimage':os.environ.get('LOW03_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),'scope':'frozen bottom-row algebra only, same K; no solver/transaction/restart qualification','b111_headcalc_sha256':member['sha256'],'carrier_sha256':hashlib.sha256(CARRIER.read_bytes()).hexdigest(),'typed_contract_sha256':hashlib.sha256((ROOT/'src/solver/mod_soil_water_solver_contract.f90').read_bytes()).hexdigest(),'test_sha256':hashlib.sha256(TEST.read_bytes()).hexdigest(),'runner_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'frozen_wrapper_sha256':hashlib.sha256(frozen.encode()).hexdigest(),'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'runs':{},'production_admitted':False}
with tempfile.TemporaryDirectory(prefix='low03-composition-') as folder:
    for opt in ('O0','O2'):
        b=pathlib.Path(folder)/opt;b.mkdir();oracle=b/'frozen.f90';oracle.write_text(frozen)
        exe=b/'test';flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
        subprocess.run(FC+LINK+flags+[str(ROOT/'src/solver/mod_soil_water_solver_contract.f90'),str(oracle),str(TEST),'-o',str(exe)],check=True,capture_output=True,text=True)
        output=subprocess.check_output([str(exe)],text=True).strip()
        if not output.startswith('LOW03_COMPOSITION_PASS'):raise RuntimeError('missing marker')
        result['runs'][opt]=output;print(opt+' '+output,flush=True)
if result['runs']['O0']!=result['runs']['O2']:raise RuntimeError('optimization mismatch')
result['status']='BOTTOM_ROW_COMPOSITION_DIAGNOSTIC_PASS'
pathlib.Path(os.environ.get('LOW03_RESULT','low03_boundary_composition_result.json')).write_text(json.dumps(result,indent=2)+'\n')
