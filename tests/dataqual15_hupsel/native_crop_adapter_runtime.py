"""Fresh controlled shared-adapter closure, authentic drivers, no production edits."""
import argparse,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
import native_crop_opaque as policy
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']

def command(args,cwd,events,label,timeout=300,logdir=None):
    start=time.monotonic();p=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,timeout=timeout)
    logdir=logdir or cwd
    stem=label+'-'+str(len(events));(logdir/(stem+'.stdout')).write_bytes(p.stdout);(logdir/(stem+'.stderr')).write_bytes(p.stderr)
    events.append(dict(label=label,command=list(map(str,args)),returncode=p.returncode,seconds=time.monotonic()-start,stdout=stem+'.stdout',stderr=stem+'.stderr'))
    (logdir/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stdout+p.stderr
    return p.stdout

def prepare(out):
    out.mkdir();events=[];fixture=out/'fixture';fixture.mkdir()
    shell=(ROOT/'tests/fmig431/run_crop_file_weather_production.sh').read_text()
    body=shell.split("<<'PY'\n",1)[1].split('\nPY\n',1)[0]
    source=out/'prepare_fixture.py';source.write_text(body,encoding='utf-8',newline='\n')
    # Execute the original donor/fixture Python verbatim, retaining all assertions.
    command([sys.executable,'-B',source,fixture],ROOT,events,'authentic-fixture',logdir=out)
    sys.path[:0]=[str(ROOT/'tests/mc-irr01'),str(ROOT/'tests/crop-cycle'),str(ROOT/'tests/crop-co2')]
    from tcs6_cycle_driver import prepare_native
    from oxygen_source_oracle import prepare as oxygen
    from co2_source_oracle import prepare as co2
    weather=prepare_native(ROOT,out/'weather.f90',1,True)
    oxygen(ROOT,fixture/'oxygen_oracle.f90');co2(ROOT,fixture/'co2_oracle.f90')
    rotation=ROOT/'tests/crop-harvest/test_rotation_joint.f90';matrix=ROOT/'tests/dataqual15_hupsel/native_crop_adapter_matrix.f90'
    mapping={}
    for p in sorted((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
        for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
    seeds=[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']
    for driver in (weather,rotation,matrix):
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',driver.read_text(),re.M|re.I):
            if name.lower()in ('iso_fortran_env','ieee_arithmetic','iso_c_binding'):continue
            assert name.lower()in mapping,name
            if mapping[name.lower()]not in seeds:seeds.append(mapping[name.lower()])
    raw=subprocess.check_output([sys.executable,'-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',*[str(p.relative_to(ROOT))for p in seeds]],cwd=ROOT,text=True)
    providers=[ROOT/p for p in raw.splitlines()];assert len(providers)==len(set(providers))and ROOT/policy.SOURCE in providers
    names=['astro','daily_meteo','crop_germination','initial_owner','task2','preparation','sowing','oxygen','co2']
    external=[ROOT/'src/legacy/b1_10_port/headcalc.f90',*[fixture/(n+'_oracle.f90')for n in names]]
    inputs={str(p.relative_to(ROOT)):sha(p)for p in [*providers,*[p for p in external if p.is_relative_to(ROOT)],rotation,matrix,ROOT/'tests/nut-crop/crop_fixture.inc',ROOT/'tests/fmig431/run_crop_file_weather_production.sh',ROOT/'tests/support/augment_bartholomeus_backend_sources.py']}
    for module in list(sys.modules.values()):
        path=getattr(module,'__file__',None)
        if path:
            p=Path(path).resolve()
            if p.is_relative_to(ROOT)and p.suffix=='.py':inputs[p.relative_to(ROOT).as_posix()]=sha(p)
    (out/'PREPARED.json').write_text(json.dumps(dict(providers=[str(p.relative_to(ROOT))for p in providers],externals=[str(p)for p in external],inputs_sha256=inputs,drivers=dict(w= str(weather),r=str(rotation),m=str(matrix)),events=events),indent=2)+'\n')
    return providers,external,dict(w=weather,r=rotation,m=matrix),inputs

def build(out,compiler,opt,providers,external,drivers,fixture,candidate):
    out.mkdir();events=[];flags=[*FLAGS,'-'+opt,'-I'+str(out),'-J'+str(out)];objects=[];sources={}
    for i,before in enumerate([*providers,*external]):
        source=fixture/'grid_stubs.f90'if before==ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'else before
        if before==ROOT/policy.SOURCE and candidate:
            source=out/'private_codec.f90';source.write_text(policy.candidate(before.read_text()),encoding='utf-8',newline='\n')
        obj=out/(str(i)+'.o');command([compiler,*flags,'-c',source,'-o',obj],out,events,'provider')
        objects.append(obj);sources[str(source)]=sha(source)
    executables={}
    for name,source in drivers.items():
        includes=['-I'+str(ROOT/'tests/nut-crop')]if name=='r'else[]
        obj=out/(name+'.o');command([compiler,*flags,*includes,'-c',source,'-o',obj],out,events,'driver')
        exe=out/(name+('.exe'if os.name=='nt'else''));args=[*flags]+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,objects),'-o',str(exe)]
        response=out/(name+'.args');response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n')
        command([compiler,'@'+str(response)],out,events,'link');executables[name]=exe
    b=dict(status='FRESH_COMPLETE_SHARED_ADAPTER_CLOSURE_BUILT',candidate=candidate,compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],flags=flags,providers=len(providers),sources_sha256=sources,objects_sha256={str(p):sha(p)for p in objects},drivers_sha256={str(p):sha(p)for p in drivers.values()},executables_sha256={n:sha(p)for n,p in executables.items()},events=events,production_admission=False)
    (out/'BUILD.json').write_text(json.dumps(b,indent=2)+'\n');return executables

def execute(exes,fixture,out):
    events=[]
    command([exes['m']],out,events,'schema-matrix')
    command([exes['r'],'continuous','first.bin','end.bin'],out,events,'rotation-original',900)
    assert (out/'end.bin').read_bytes()==(out/'end.bin.opaque').read_bytes()
    for mode,seed in (('resume','first.bin'),('resume-retired','end.bin.retired'),('resume-fallow','end.bin.fallow'),('roundtrip-successor','end.bin')):
        target=out/(mode+'.bin');command([exes['r'],mode,seed,target],out,events,mode,900)
        assert target.read_bytes()==(out/'end.bin').read_bytes()
    args=[fixture/n for n in ('weather.999','altered.999','bad.999','backup.999')]
    command([exes['w'],*args,'continuous','neutral'],out,events,'weather-original',900)
    for phase in ('neutral','hydraulic'):
        for mode in ('native-write','native-resume','native-write-active','native-resume-active'):
            command([exes['w'],*args,mode,phase],out,events,phase+'-'+mode,900)
        tag='morning'if phase=='neutral'else'dayend'
        files=[Path(str(exes['w'])+'.'+tag+'.'+suffix)for suffix in ('full','opaque','resumed','active.resumed')]
        assert all(p.read_bytes()==files[0].read_bytes()for p in files),tag
    return events

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
    os.environ['OMP_NUM_THREADS']='1';out=a.out.resolve();compiler=a.compiler.resolve()
    providers,external,drivers,inputs=prepare(out)
    variants={}
    for name,candidate in (('incumbent',False),('candidate',True)):
        exes=build(out/name,compiler,a.optimization,providers,external,drivers,out/'fixture',candidate)
        events=execute(exes,out/'fixture',out/name);variants[name]=dict(events=events)
        assert all(sha(ROOT/p)==digest for p,digest in inputs.items()),'source drift'
    names=['first.bin','end.bin','end.bin.opaque','end.bin.retired','end.bin.fallow',*[f'schema-{mode}-{j}.bin'for mode in range(4)for j in range(2)]]
    weather='w.exe'if os.name=='nt'else'w'
    names += [weather+'.'+phase+'.'+suffix for phase in ('morning','dayend')for suffix in ('full','opaque','resumed','active.resumed')]
    for name in names:assert (out/'incumbent'/name).read_bytes()==(out/'candidate'/name).read_bytes(),name
    (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_SHARED_ADAPTER_ROTATION_WEATHER_NATIVE_AND_EIGHT_SCHEMAS_BYTE_EXACT_PASS',optimization=a.optimization,providers=len(providers),variants=variants,byte_exact_files={n:sha(out/'candidate'/n)for n in names},production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
    print('SHARED_ADAPTER_NATIVE_AND_SCHEMA_MATRIX_PASS',a.optimization)

if __name__=='__main__':main()
