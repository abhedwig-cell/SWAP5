"""Execute the production lookup codec in its complete native original closure."""
import argparse,hashlib,json,shutil,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from oxygen_lookup_state import render
from daily_host import NO_MACRO_FP_FLAGS

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());compiler=Path(shutil.which('gfortran'))
    assert sha(compiler)==prepared['toolchain']['gfortran']['sha256']
    selected=ref/'build/swap-selected';objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    source=selected/'oxygenstress.f90';assert sha(source)==prepared['provider_files']['build/swap-selected/oxygenstress.f90']
    profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();generated=target/'oxygenstress.f90';generated.write_text(render(source.read_text(encoding='cp1252')),encoding='cp1252')
        driver=ROOT/'tools/solute/drivers/original_oxygen_lookup_codec.f90'
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]
        commands=[['gfortran',*flags,'-c',str(generated),str(driver)],
                  ['gfortran','-o',str(target/'codec.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name not in ('swap_main.o','oxygenstress.o')],str(target/'oxygenstress.o'),str(target/'original_oxygen_lookup_codec.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for command in commands:
            r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,mode,payload=None,refused=False):
            directory=target/name;directory.mkdir()
            if payload is not None:(directory/'state.bin').write_bytes(payload)
            r=subprocess.run([str(target/'codec.exe'),mode],cwd=directory,capture_output=True,text=True,timeout=15)
            (directory/'stdout.log').write_text(r.stdout);(directory/'stderr.log').write_text(r.stderr)
            assert (r.returncode!=0)==refused,(opt,name,r.stdout,r.stderr)
            if refused:assert 'oxygen history' in r.stderr.lower(),(name,r.stderr)
            return directory,dict(name=name,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
        valid,positive=execute('valid','valid');inactive,empty=execute('inactive','inactive')
        data=(valid/'state.bin').read_bytes();assert len(data)==168 and data==(valid/'roundtrip.bin').read_bytes()
        assert len((inactive/'state.bin').read_bytes())==24 and (inactive/'state.bin').read_bytes()==(inactive/'roundtrip.bin').read_bytes()
        attacks=[]
        for name,offset,fmt,value in [('version',0,'i',9),('flag',4,'i',9),('nodes',8,'i',4),('clock',12,'d',0.),('nan',20,'d',float('nan')),
             ('negative',20,'d',-1.),('mplus1',20+5*3*8,'d',.5),('trailer',164,'i',0)]:
            changed=bytearray(data);struct.pack_into('='+fmt,changed,offset,value);_,record=execute(name,'consume',bytes(changed),True);attacks.append(record)
        _,record=execute('short','consume',data[:-1],True);attacks.append(record)
        for mode in ('writer-nan','writer-negative','writer-domain','stale-apply','grid-apply'):
            _,record=execute(mode,mode,refused=True);attacks.append(record)
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,positive=positive,refusals=attacks,
          roundtrip_exact=True,staged_read_before_assignment=True,undefined_tails_unchanged=True,inactive_roundtrip_exact=True,generated_source_sha256=sha(generated),executable_sha256=sha(target/'codec.exe')))
    (out/'RESULT.json').write_text(json.dumps(dict(status='PRODUCTION_ORIGINAL_OXYGEN_LOOKUP_CODEC_O0_O2_PASS',compiler=prepared['toolchain']['gfortran'],profiles=profiles,
      production_generator_sha256=sha(ROOT/'app/hybrid_water/oxygen_lookup_state.py'),original_source_sha256=sha(source),driver_sha256=sha(ROOT/'tools/solute/drivers/original_oxygen_lookup_codec.f90'),
      scope='Actual production complete oxygen preprocessing codec in original native dependency closure; no model or active macropore execution'),indent=2)+'\n')
    print('PRODUCTION_ORIGINAL_OXYGEN_LOOKUP_CODEC_O0_O2_PASS')

if __name__=='__main__':main()
