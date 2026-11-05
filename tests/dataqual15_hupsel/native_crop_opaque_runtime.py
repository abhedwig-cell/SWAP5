"""Coherent private opaque codec build, byte controls and actual owner refusals."""
import argparse,json,os,struct,subprocess,sys
from pathlib import Path
import native_crop_opaque as policy
import native_crop_bool_runtime as inherited
from production_diagnostic_guards import qualify
from production_diagnostic_native import mature_case
ROOT=inherited.builder.ROOT

def fixture(bundle,baseline,compiler,out):
    out.mkdir();events=[]
    def build(b,directory):
        directory.mkdir();record=json.loads((b/'BUILD.json').read_text());objects=list(record['object_sha256'])[:-1]
        program=ROOT/'tests/dataqual15_hupsel/native_crop_opaque_fixture.f90'
        exe=directory/('fixture.exe'if os.name=='nt'else'fixture')
        flags=[x for x in record['flags']if not x.startswith(('-I','-J'))]+['-I'+str(b),'-J'+str(directory)]
        args=[*flags,str(program),*objects,record['publication_provider']['object'],record['ttutil_archive'],'-o',str(exe)]
        response=directory/'compile.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n')
        p=subprocess.run([str(compiler),'@'+str(response)],cwd=directory,capture_output=True,timeout=120)
        (directory/'compile.stdout').write_bytes(p.stdout);(directory/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
        return exe
    def run(exe,directory,mode):
        p=subprocess.run([str(exe),mode],cwd=directory,capture_output=True,timeout=30)
        (directory/(mode+'.stdout')).write_bytes(p.stdout);(directory/(mode+'.stderr')).write_bytes(p.stderr)
        events.append(dict(executable=str(exe),mode=mode,returncode=p.returncode));assert p.returncode==0,p.stderr
    old=build(baseline,out/'incumbent');new=build(bundle,out/'candidate')
    run(old,out/'incumbent','valid');run(new,out/'candidate','valid');run(new,out/'candidate','invalid')
    for name in ('owner0.bin','owner1.bin','view0.bin','view1.bin'):
        assert (out/'incumbent'/name).read_bytes()==(out/'candidate'/name).read_bytes(),name
    for kind,offset in (('owner',28),('view',64)):
        original=(out/'incumbent'/(kind+'1.bin')).read_bytes();assert struct.unpack_from('=i',original,offset)[0]==1
        for bad in (2,-1,256,2147483647):
            raw=bytearray(original);struct.pack_into('=i',raw,offset,bad);(out/'candidate/input.bin').write_bytes(raw)
            run(new,out/'candidate','read-'+kind)
    (out/'RESULT.json').write_text(json.dumps(dict(status='OPAQUE_VALID_COMPONENT_ORDER_BYTES_AND_16_WRITER_8_READ_REFUSALS_PASS',events=events),indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
    inherited.policy=policy;inherited.main()
    out=a.out.resolve();baseline=a.baseline.resolve();compiler=a.compiler.resolve()
    fixture(out/'build',baseline,compiler,out/'opaque-fixture')
    if os.name=='nt':case=ROOT.parent/'pressure-film-20261105/O2/full1096'
    else:case=mature_case(out/'build',out,False)
    qualify(out/'build',case,case/'checkpoint.bin',out/'mature-owner-controls')
    (out/'OPAQUE_RESULT.json').write_text(json.dumps(dict(status='OPAQUE_COMPONENT_AND_MATURE37_CONTROLS_PASS_WRITER_FAULT_PROBE_PENDING',source_sites=34,production_admission=False),indent=2)+'\n')

if __name__=='__main__':main()
