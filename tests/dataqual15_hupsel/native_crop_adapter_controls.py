"""Retain existing real native refusal requirements for both shared-adapter drivers."""
import argparse,json,struct,sys,zlib
from pathlib import Path
import native_crop_adapter_runtime as runtime
ROOT=runtime.ROOT

def execute(out):
    sys.path.insert(0,str(ROOT/'tests/mc-irr01'))
    from tcs6_native_controls import execute as weather_controls
    opt=json.loads((out/'RESULT.json').read_text())['optimization'];reports={}
    for variant in ('incumbent','candidate'):
        build=out/variant;events=[];exe=build/('r.exe'if sys.platform=='win32'else'r')
        rotation=[]
        for phase in ('retired','fallow'):
            raw=(build/('end.bin.'+phase)).read_bytes()
            nn=struct.unpack_from('<i',raw,152)[0];hh=struct.unpack_from('<i',raw,156)[0]
            chemical=160+16*nn+16+(8*nn if hh else 0)
            pc=struct.unpack_from('<i',raw,chemical+24)[0];crop=chemical+28+8*pc+104
            cc=struct.unpack_from('<i',raw,crop+8)[0];owner=crop+12+8*cc+4
            assert struct.unpack_from('<d',raw,owner)[0]==-81002.
            for name,(index,value)in dict(marker=(0,-81001.),clock=(1,99.),identity=(2,99.),N=(3,99999.),OM=(4,99999.),ledger=(7,0.)).items():
                bad=bytearray(raw);struct.pack_into('<d',bad,owner+8*index,value);struct.pack_into('<I',bad,len(bad)-4,zlib.crc32(bad[:-4]))
                target=build/('reject-'+phase+'-'+name+'.bin');target.write_bytes(bad)
                stdout=runtime.command([exe,'reject',target],build,events,'reject-'+phase+'-'+name)
                assert b'CROP_SOIL_INVALID_DISK=PASS'in stdout
                rotation.append(dict(phase=phase,case=name,sha256=runtime.sha(target)))
        class Session:
            def command(self,args,cwd,label):
                raw=runtime.command(args,cwd,events,label)
                return raw,dict(returncode=events[-1]['returncode'],wall_seconds=events[-1]['seconds'])
        weather={}
        for phase in ('neutral','hydraulic'):
            rows=weather_controls(Session(),build/('w.exe'if sys.platform=='win32'else'w'),out/'fixture',phase,build,opt,variant)
            assert len(rows)>=16 and all(r['returncode']==0 for r in rows)
            weather[phase]=rows
        reports[variant]=dict(rotation=rotation,weather=weather,events=events)
        (build/'DECODER_EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    result=dict(status='ACTUAL_ROTATION12_AND_EXISTING_WEATHER_NATIVE_REFUSALS_PASS',reports=reports,unchanged_controllers_sha256={p:runtime.sha(ROOT/p)for p in ('tests/mc-irr01/tcs6_native_controls.py','tests/crop-harvest/run_joint.py')},production_admission=False)
    (out/'CONTROLS.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],opt)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);args=parser.parse_args();execute(args.out.resolve())
