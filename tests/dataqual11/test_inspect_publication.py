"""Real TTUTIL inspection: original output preservation and fail-closed publication."""
import argparse
from pathlib import Path
import subprocess
import json

root=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--ttutil',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
old=out/'baseline.f90'
old.write_bytes(subprocess.check_output(['git','show','d37a9ba2f09e8ea65168b0f87cd6691ad372536f:app/solute_project/inspect_historical.f90'],cwd=root))
source=(root/'reference/swap-4.3.1/projects/2.grassgrowth/swap.swp').read_bytes()
results=[]
for opt in ('O0','O2'):
    build=out/opt;build.mkdir()
    for name,src in [('old',old),('new',root/'app/solute_project/inspect_historical.f90')]:
        subprocess.run(['gfortran','-'+opt,'-fcheck=all',str(src),str(a.ttutil.resolve()),'-o',str(build/(name+'.exe'))],check=True)
    expected=None
    for case in ('baseline','valid','custom','missing_crop','existing','missing_arg','long_output'):
        folder=build/case;folder.mkdir()
        (folder/'input.swp').write_bytes(source.replace(b'CROPTYPE',b'UNKNOWN_CROP') if case=='missing_crop' else source)
        target=folder/('selected.csv' if case=='custom' else 'capabilities.csv')
        if case=='existing':target.write_bytes(b'preserve\n')
        args=[str(build/('old.exe' if case=='baseline' else 'new.exe')),'input.swp']
        if case=='custom':args.append(target.name)
        if case=='missing_arg':args.pop()
        if case=='long_output':args.append('x'*1025)
        r=subprocess.run(args,cwd=folder,capture_output=True,timeout=60)
        (folder/'stderr.txt').write_bytes(r.stderr)
        assert (r.returncode==0)==(case in ('baseline','valid','custom')),(opt,case,r.stderr)
        if case=='baseline':expected=target.read_bytes()
        elif case in ('valid','custom'):assert target.read_bytes()==expected
        elif case=='existing':assert target.read_bytes()==b'preserve\n'
        else:assert not target.exists()
        results.append(dict(optimization=opt,case=case,returncode=r.returncode))
(out/'RESULT.json').write_text(json.dumps(results,indent=2))
print('HISTORICAL_INSPECTION_PUBLICATION_O0_O2_PASS')
