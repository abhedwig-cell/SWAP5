"""Persist raw native processes, exact scientific inputs and checked builds."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--root',required=True,type=Path);a=ap.parse_args();files={}
    for opt in ['o0','o2']:
        build=a.root/('fct-refine-'+opt);meta=json.loads((build/'build.json').read_text())
        files[f'build-{opt}/build.json']=(build/'build.json').read_bytes()
        files[f'build-{opt}/commit.raw']=subprocess.check_output(['git','cat-file','commit',meta['baseline']],cwd=ROOT)
        for p,h in meta['inputs'].items():
            b=(ROOT/p).read_bytes();assert sha(b)==h;files['source/'+h]=b
        for p in meta['generated']:files[f'build-{opt}/'+p]=(build/p).read_bytes()
        for i,e in enumerate(e for e in meta['events'] if '-std=legacy' in e['command']):files[f'build-{opt}/reader-{i:03d}']=Path(e['command'][-3]).read_bytes()
        for p in build.glob('*'):
            if p.suffix in ['.stdout','.stderr']:files[f'build-{opt}/'+p.name]=p.read_bytes()
        for phase in ['pilot','refinement','duration']:
            folder=a.root/f'refine-{phase}-{opt}'
            for p in folder.rglob('*'):
                if p.is_file():files[f'{phase}-{opt}/'+str(p.relative_to(folder))]=p.read_bytes()
    files['OWNER.json']=(a.root/'refine-owner.json').read_bytes();files['PREDECESSOR.json']=(a.root/'refine-predecessor.json').read_bytes()
    for p in ['run.py','verify.py','seal.py']:files['validation/'+p]=(HERE/p).read_bytes()
    v=runpy.run_path(str(HERE/'verify.py'));r=v['assess'](files);c=v['controls'](files)
    files['VERIFICATION.json']=json.dumps(r,indent=2).encode();files['CONTROLS.json']=json.dumps(c).encode()
    files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())}).encode();stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w:xz')as t:
        for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
    raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
    index=dict(sha256=sha(raw),bytes=len(raw),members=len(files),result=r,controls=c)
    (HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n');print(json.dumps(index,indent=2))

if __name__=='__main__':main()
