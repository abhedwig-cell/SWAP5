"""Actual current rotation lifecycle, admitted rejection input, unchanged asserts."""
import argparse,hashlib,json,os,re,struct,subprocess,sys,time,zlib
from pathlib import Path
import native_crop_adapter_runtime as common
ROOT=common.ROOT
BASE='5921f7dc89871e68e394302a2c62958b691699ac'
PREREG='integration/dataqual15_hupsel/ROTATION_NATIVE_PREREGISTRATION_20261105.json'
ORIGINAL='tests/crop-harvest/test_rotation_joint.f90'
DONOR='tests/nut-crop/test_b112_retained_joint.f90'
OLD='  bad_sp=sp;bad_sp%organic_reference%ratecon_bio=0d0;bad_sp%organic_reference%ratecon_hum=0d0'
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def projection(original,donor):
    lines=[s for s in donor.splitlines()if s.lstrip().startswith('bad_sp=sp;bad_sp%mineral%inventory%nfrac_biomass=1d0;')]
    assert len(lines)==1 and original.count(OLD)==1
    replacement=lines[0].strip()
    assert replacement=='bad_sp=sp;bad_sp%mineral%inventory%nfrac_biomass=1d0;bad_sp%organic_reference%ratecon_fom=1d0;bad_sp%organic_reference%ratecon_bio=0d0;bad_sp%organic_reference%ratecon_hum=0d0;bad_sp%environment%temperature_reference_c=-20d0'
    changed=original.replace(OLD,'  '+replacement)
    # Every original assertion and all other executable statements remain exact.
    assert changed.replace('  '+replacement,OLD)==original
    return changed

def guard():
    r=json.loads((ROOT/PREREG).read_text());assert r['baseline']==BASE and r['production_delta']==[]
    subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
    for area in ('src','app','reference'):
        assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
        assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
        assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',area],cwd=ROOT)
    for name,h in r['source_sha256'].items():assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==h,name
    return r

def run(args,out,events,label,expected=0):
    start=time.monotonic();p=subprocess.run(list(map(str,args)),cwd=out,capture_output=True,timeout=300)
    stem='%03d-%s'%(len(events),label)
    for stream in ('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(p,stream))
    events.append(dict(label=label,command=list(map(str,args)),returncode=p.returncode,expected_returncode=expected,seconds=time.monotonic()-start,stdout=stem+'.stdout',stderr=stem+'.stderr'))
    (out/'EXECUTED.json').write_text(json.dumps(events,indent=2)+'\n')
    assert p.returncode==expected,(label,p.stdout,p.stderr)
    return p.stdout

def original_compact_controls(exe,out,events):
    # Exact original twelve mutations from tests/crop-harvest/run_joint.py.
    names=[]
    for phase in ('retired','fallow'):
        data=bytearray((out/('end.bin.'+phase)).read_bytes())
        nn=struct.unpack_from('<i',data,152)[0];hh=struct.unpack_from('<i',data,156)[0]
        chemical=160+16*nn+16+(8*nn if hh else 0)
        pc=struct.unpack_from('<i',data,chemical+24)[0];crop=chemical+28+8*pc+104
        cc=struct.unpack_from('<i',data,crop+8)[0];owner=crop+12+8*cc+4
        assert struct.unpack_from('<d',data,owner)[0]==-81002.
        tests={'marker':(0,-81001.),'clock':(1,99.),'identity':(2,99.),'N':(3,99999.),'OM':(4,99999.),'ledger':(7,0.)}
        for label,(index,value)in tests.items():
            raw=data.copy();struct.pack_into('<d',raw,owner+8*index,value)
            struct.pack_into('<I',raw,len(raw)-4,zlib.crc32(raw[:-4]))
            name=phase+'-'+label+'.bin';(out/name).write_bytes(raw)
            assert b'INVALID_DISK=PASS'in run([exe,'reject',name,'unused'],out,events,'compact-'+phase+'-'+label)
            names.append(name)
    return names

def qualify(out,compiler,opt):
    r=guard();out.mkdir(parents=True)
    providers,external,drivers,inputs=common.prepare(out/'prepared')
    # Full current source/object closure; no private production transformation.
    bundle=out/'build';common.build(bundle,compiler,opt,providers,external,{'r':drivers['r']},out/'prepared/fixture',False)
    b=json.loads((bundle/'BUILD.json').read_text());suffix='.exe'if os.name=='nt'else''
    original=bundle/('r'+suffix);events=[]
    raw=run([original,'continuous','old-first.bin','old-end.bin'],out,events,'original-obsolete-premise',1)
    assert b'FAIL reaction rejects after actual crop preparation'in raw
    assert not(out/'old-first.bin').exists()and not(out/'old-end.bin').exists()
    source=out/'rotation.f90';text=projection((ROOT/ORIGINAL).read_text(),(ROOT/DONOR).read_text());source.write_text(text,encoding='utf-8',newline='\n')
    fixture=out/'prepared/fixture'
    flags=[x for x in b['flags']if not x.startswith(('-I','-J'))]+['-I'+str(bundle),'-J'+str(out),'-I'+str(fixture),'-I'+str(ROOT/'tests/nut-crop'),'-I'+str(ROOT/'tests/nut-material')]
    obj=out/'rotation.o';run([compiler,*flags,'-c',source,'-o',obj],out,events,'successor-driver-compile')
    exe=out/('rotation'+suffix);args=[*flags]+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*b['objects_sha256'],'-o',str(exe)]
    response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n')
    run([compiler,'@'+str(response)],out,events,'successor-link')
    assert b'ROTATION_ACTUAL_RICHARDS_RETIRE_FALLOW_SUCCESSOR=PASS'in run([exe,'continuous','first.bin','end.bin'],out,events,'successor-original-all-assertions')
    assert(out/'end.bin').read_bytes()==(out/'end.bin.opaque').read_bytes()
    for mode,seed in (('resume','first.bin'),('resume-retired','end.bin.retired'),('resume-fallow','end.bin.fallow'),('roundtrip-successor','end.bin')):
        target=mode+'.bin';run([exe,mode,seed,target],out,events,mode)
        assert(out/target).read_bytes()==(out/'end.bin').read_bytes()
    controls=original_compact_controls(exe,out,events)
    for phase in ('first.bin','end.bin','end.bin.retired','end.bin.fallow'):
        raw=(out/phase).read_bytes()
        for label,bad in (('crc',raw[:-1]+bytes([raw[-1]^1])),('truncated',raw[:-5])):
            name=phase+'.'+label;(out/name).write_bytes(bad)
            assert b'INVALID_DISK=PASS'in run([exe,'reject',name,'unused'],out,events,label+'-'+phase)
            controls.append(name)
    assert len(controls)==20
    assert all(common.sha(ROOT/p)==h for p,h in inputs.items())
    assert all(common.sha(Path(p))==h for p,h in b['objects_sha256'].items())
    guard()
    report=dict(status='ACTUAL_CURRENT_ROTATION_ALL_ASSERTIONS_ADMITTED_EXHAUSTION_NATIVE_LIFECYCLE_AND_20_REFUSALS_PASS',optimization=opt,production_transform=False,production_trees={area:subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT,text=True).strip()for area in ('src','app','reference')},original_driver_sha256=sha((ROOT/ORIGINAL).read_bytes().replace(b'\r\n',b'\n')),donor_sha256=sha((ROOT/DONOR).read_bytes().replace(b'\r\n',b'\n')),successor_driver_sha256=common.sha(source),driver_object_sha256=common.sha(obj),executable_sha256=common.sha(exe),inputs_sha256=inputs,controls=controls,native_sha256={name:common.sha(out/name)for name in ('first.bin','end.bin','end.bin.opaque','end.bin.retired','end.bin.fallow','resume.bin','resume-retired.bin','resume-fallow.bin','roundtrip-successor.bin')},whole_scientific_admission=False,migration_complete=False)
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],opt,flush=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    os.environ['OMP_NUM_THREADS']='1';qualify(a.output.resolve(),a.compiler.resolve(),a.optimization)

if __name__=='__main__':main()
