"""Execute the production lookup codec in its complete native original closure."""
import argparse,hashlib,json,shutil,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from micro_lookup_state import render
from daily_host import NO_MACRO_FP_FLAGS

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());compiler=Path(shutil.which('gfortran'))
    assert sha(compiler)==prepared['toolchain']['gfortran']['sha256']
    selected=ref/'build/swap-selected';objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    source=selected/'RWU_micro.f90';assert sha(source)==prepared['provider_files']['build/swap-selected/RWU_micro.f90']
    profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();generated=target/'RWU_micro.f90';generated.write_text(render(source.read_text(encoding='cp1252')),encoding='cp1252')
        driver=ROOT/'tools/solute/drivers/original_micro_lookup_codec.f90'
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]
        commands=[['gfortran',*flags,'-c',str(generated),str(driver)],
                  ['gfortran','-o',str(target/'codec.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name not in ('swap_main.o','RWU_micro.o')],str(target/'RWU_micro.o'),str(target/'original_micro_lookup_codec.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for command in commands:
            r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,mode,payload=None,refused=False):
            directory=target/name;directory.mkdir()
            if payload is not None:(directory/'lookup.bin').write_bytes(payload)
            r=subprocess.run([str(target/'codec.exe'),mode],cwd=directory,capture_output=True,text=True,timeout=15)
            (directory/'stdout.log').write_text(r.stdout);(directory/'stderr.log').write_text(r.stderr)
            assert (r.returncode!=0)==refused,(opt,name,r.stdout,r.stderr)
            if refused:assert 'microscopic' in r.stderr.lower(),(name,r.stderr)
            return directory,dict(name=name,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
        valid,positive=execute('valid','valid');inactive,empty=execute('inactive','inactive')
        for directory in (valid,inactive):assert (directory/'lookup.bin').read_bytes()==(directory/'lookup-roundtrip.bin').read_bytes()
        data=(valid/'lookup.bin').read_bytes();assert len(data)==13788 and len((inactive/'lookup.bin').read_bytes())==44
        attacks=[]
        for name,offset,fmt,value in [('version',0,'i',99),('flag',4,'i',99),('owner',8,'i',3),('drought',12,'i',2),('model',16,'i',2),
                ('layers',20,'i',3),('Mrows',24,'i',431),('Krows',28,'i',430),('clock',32,'d',37787.),
                ('nanM',40,'d',float('nan')),('negativeM',40,'d',-1.),('nanK',40+430*2*8,'d',float('nan')),('negativeK',40+430*2*8,'d',-1.),('trailer',len(data)-4,'i',0)]:
            changed=bytearray(data);struct.pack_into('='+fmt,changed,offset,value);_,record=execute(name,'consume',bytes(changed),True);attacks.append(record)
        for name,payload in [('short',data[:-1]),('empty-active-context',(inactive/'lookup.bin').read_bytes())]:
            _,record=execute(name,'consume',payload,True);attacks.append(record)
        for mode in ('invalid-write-nan','invalid-write-negative','invalid-write-crop','changed-apply-crop','changed-apply-model','changed-apply-clock','uninitialized-apply'):
            _,record=execute(mode,mode,refused=True);attacks.append(record)
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,valid=positive,inactive=empty,refusals=attacks,
            active_bytes=len(data),inactive_bytes=44,roundtrip_exact=True,staged_read_before_assignment=True,undefined_tails_unchanged=True,
            generated_source_sha256=sha(generated),executable_sha256=sha(target/'codec.exe')))
        print(opt,'PRODUCTION_CODEC_PASS',len(attacks),'ACTUAL_REFUSALS',flush=True)
    result=dict(status='PRODUCTION_ORIGINAL_MICRO_LOOKUP_CODEC_O0_O2_PASS',compiler=prepared['toolchain']['gfortran'],profiles=profiles,
        production_generator_sha256=sha(ROOT/'app/hybrid_water/micro_lookup_state.py'),original_source_sha256=sha(source),driver_sha256=sha(ROOT/'tools/solute/drivers/original_micro_lookup_codec.f90'),
        scope='Actual production generator and full original native dependency closure; only codec entry points execute, no active macro/model/platform campaign')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
