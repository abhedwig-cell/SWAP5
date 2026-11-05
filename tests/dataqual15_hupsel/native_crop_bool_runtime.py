"""Coherent copied-source native codec qualification, explicitly private."""
import argparse,json,os,struct,subprocess,zlib,shutil
from pathlib import Path
import pressure_film as builder
import native_crop_bool as policy
from production_diagnostic_native import writer_build,measure,app_refusals

def mutations(exe,case,out):
    out.mkdir();raw=(case/'checkpoint.bin').read_bytes()
    assert raw[:8]==b'S5HR0004' and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
    offset=20
    for _ in range(6):offset+=4+struct.unpack_from('=i',raw,offset)[0]
    view=offset+4+struct.unpack_from('=i',raw,offset)[0]
    # First view validity, owner emergence, and allocated-biomass presence.
    events=[]
    for delta in (0,4,16):
        for value in (2,-1,256,2147483647):
            target=out/f'{delta}-{value}';target.mkdir()
            for p in case.iterdir():
                if p.suffix in ('.nml','.swp','.crp','.met','.dra'):shutil.copyfile(p,target/p.name)
            data=bytearray(raw);struct.pack_into('=i',data,view+delta,value)
            struct.pack_into('=I',data,len(data)-4,zlib.crc32(data[:-4]))
            seed=target/'restart-input.bin';seed.write_bytes(data)
            # Nonadvancing: day2 corresponds to the second original requested window.
            p=subprocess.run([str(exe),'input.nml',str(seed), '2','swap.swp','maize.crp'],cwd=target,capture_output=True,timeout=30)
            (target/'stdout').write_bytes(p.stdout);(target/'stderr').write_bytes(p.stderr)
            assert p.returncode!=0 and b'source rotation envelope rejected before publication' in p.stdout+p.stderr,p.stdout+p.stderr
            assert not any((target/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin'))
            events.append(dict(offset=view+delta,value=value,returncode=p.returncode,refused_before_publication=True))
    (out/'RESULT.json').write_text(json.dumps(dict(status='TWELVE_RESEALED_NATIVE_SCALAR_LOGICAL_REFUSALS_PASS',events=events),indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir();os.environ['OMP_NUM_THREADS']='1';os.environ.pop('SWAP5_DIAG_PREDECESSOR',None)
    source=(builder.ROOT/policy.SOURCE).read_text(encoding='utf-8')
    builder.candidate_sources=lambda:{policy.SOURCE:policy.candidate(source)}
    exe=builder.build(a.baseline.resolve(),out/'build',a.compiler.resolve())
    inputs=builder.native.inputs(out/'inputs');probe=writer_build(exe.parent,out/'writer-build',a.compiler.resolve(),windows=False)
    measure(exe,probe,inputs,out/'own-runtime')
    case=out/'own-runtime/continuous2'
    baseline_exe=a.baseline.resolve()/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
    baseline_case=builder.native.execute(baseline_exe,inputs,out/'unmodified-control',2)
    for name in ('checkpoint.bin','budget.csv','crop.csv'):
        assert (baseline_case/name).read_bytes()==(case/name).read_bytes(),name
    app_refusals(exe,case,out/'app-refusals');mutations(exe,case,out/'logical-refusals')
    (out/'RESULT.json').write_text(json.dumps(dict(status='PRIVATE_COHERENT_236_PROVIDER_TWO_DAY_OWN_RESTART_AND_LOGICAL_REFUSALS_PASS',scalar_sites=32,production_admission=False,opaque_derived_logicals_qualified=False),indent=2)+'\n')

if __name__=='__main__':main()
