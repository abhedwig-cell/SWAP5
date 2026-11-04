"""Actual pressure-variant oxygen diagnosis using body-only read-only seams."""
import argparse,json,shutil,subprocess,time
from pathlib import Path
import root_oxygen_observer as root
import matched_oxygen_observer as oxygen
import matched_micro_observer as micro
from root_oxygen_evidence import data
ROOT=root.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=root.sha
MAIN=root.MAIN;BACKEND=oxygen.BACKEND

def backend(source,reg):
    # Reuse qualified output-only seams, excluding the private-table API seam.
    result=micro.instrument(source,reg)
    for line in ('  use mod_root_micro_matric_flux_table,only:observe_micro_table\n',
                 '                call observe_micro_table(self%micro_tables(mi),micro_table_unit,t0,t1,mi)\n',
                 "                open(newunit=micro_table_unit,file='micro_tables.dat',status='replace')\n"):
        assert result.count(line)==1;result=result.replace(line,'')
    return oxygen.instrument(result,reg)

def build(bundle,out,fc,reg=None):
    out.mkdir();r=json.loads((bundle/'BUILD.json').read_text());old=r['baseline'];events=[]
    manifest=json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text())
    opt=next(x[1:] for x in old['flags'] if x in ('-O0','-O2'))
    assert sha(bundle/'BUILD.json')==manifest['files_sha256']['build-'+opt+'/BUILD.json']
    assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==old['compiler']
    assert all(sha(Path(p))==h for p,h in r['source_sha256'].items())
    assert all(sha(bundle/n)==h for n,h in r['compiled_objects_sha256'].items())
    assert sha(bundle/'pressure-runtime.exe')==r['executable_sha256']
    pub=old['publication_provider'];assert sha(Path(pub['object']))==pub['object_sha256']
    assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(old['ttutil_archive']))==old['archive_sha256']
    for p in bundle.glob('*.mod'):shutil.copyfile(p,out/p.name)
    flags=[x for x in old['flags'] if not x.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
    replacements={MAIN:root.instrument((ROOT/MAIN).read_text())}
    if reg:replacements[BACKEND]=backend((ROOT/BACKEND).read_text(),reg)
    objects=[bundle/(str(i)+'.o') for i in range(236)];patches={}
    def run(command):
        begin=time.monotonic();p=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=180)
        i=len(events);(out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
        events.append(dict(command=list(map(str,command)),returncode=p.returncode,seconds=time.monotonic()-begin))
        (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr
    for i,name in enumerate(old['source_sha256']):
        path=Path(name)
        if path.is_relative_to(ROOT) and path.relative_to(ROOT).as_posix() in replacements:
            relative=path.relative_to(ROOT).as_posix();src=out/path.name;src.write_text(replacements[relative],encoding='utf-8',newline='\n')
            obj=out/(str(i)+'.o');run([fc,*flags,'-c',src,'-o',obj]);objects[i]=obj
            patches[relative]=dict(source=src.name,source_sha256=sha(src),object=obj.name,object_sha256=sha(obj))
    assert set(patches)==set(replacements)
    exe=out/'observed.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),pub['object'],old['ttutil_archive'],'-o',str(exe)]
    response=out/'link.args';response.write_text('\n'.join('"'+s.replace('\\','/')+'"' for s in args)+'\n',encoding='utf-8')
    run([fc,'@'+str(response)])
    (out/'BUILD.json').write_text(json.dumps(dict(baseline=r,patches=patches,events=events,executable_sha256=sha(exe),link_arguments=args,link_response_sha256=sha(response),ABI_scope='Only program/backend body output changes, no module public API/type change; every inherited coherent object pinned'),indent=2)+'\n')
    return exe

def selected(trace):
    result=[]
    for day in (525,584):
        rows=[r for r in trace if day-1<=r[0] and r[1]<=day]
        candidates=[rows[0],rows[-1],max(rows,key=lambda r:r[4]),max(rows,key=lambda r:r[4]*(r[1]-r[0])),min(rows,key=lambda r:r[7]),max(rows,key=lambda r:r[7])]
        for r in candidates:
            if not any(x['receipt']==r for x in result):result.append(dict(day=day,receipt=r))
    return dict(selected_profiles=result)

def run_phase(exe,case,seed,out,capture=None,compatible=True):
    root.run(exe,case,seed,out,capture,compatible)

def qualify(opt,bundle,case,out,fc):
    out.mkdir();exe=build(bundle,out/'root-build',fc)
    run_phase(bundle/'pressure-runtime.exe',case,case/'checkpoint-524.bin',out/'unobserved',compatible=(opt=='O0'))
    run_phase(exe,case,case/'checkpoint-524.bin',out/'root-whole',537)
    run_phase(exe,case,out/'root-whole/checkpoint-537.bin',out/'root-strict-537',compatible=False)
    reg=selected(data((out/'root-whole/root_accepted.dat').read_bytes(),9));(out/'SELECTED.json').write_text(json.dumps(reg,indent=2)+'\n')
    exe=build(bundle,out/'forcing-build',fc,reg)
    run_phase(exe,case,case/'checkpoint-524.bin',out/'whole',537)
    run_phase(exe,case,out/'whole/checkpoint-537.bin',out/'strict-own-537',compatible=False)
    for phase in ('root-whole','root-strict-537','whole','strict-own-537'):
        assert (out/phase/'checkpoint.bin').read_bytes()==(out/'unobserved/checkpoint.bin').read_bytes()
    for whole,tail in [('root-whole','root-strict-537'),('whole','strict-own-537')]:
        for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
            assert root.daily(out/whole/name)==root.daily(out/'unobserved'/name)
            assert root.daily(out/tail/name)==[r for r in root.daily(out/whole/name) if float(r[clock])>537]
        for name in ('root_accepted.dat','root_nodes.dat'):
            assert (out/tail/name).read_bytes().splitlines()==[r for r in (out/whole/name).read_bytes().splitlines() if float(r.split()[0])>=537]
    for name in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):
        assert (out/'root-whole'/name).read_bytes()==(out/'whole'/name).read_bytes()
    for name in ('oxygen_trials.dat','micro_trials.dat'):
        assert (out/'strict-own-537'/name).read_bytes().splitlines()==[r for r in (out/'whole'/name).read_bytes().splitlines() if float(r.split()[0])>=537]
    if opt=='O2':
        assert (out/'whole/checkpoint.bin').read_bytes()==(case/'checkpoint-584.bin').read_bytes()
        assert root.daily(out/'whole/budget.csv')==[r for r in root.daily(case/'budget.csv') if 524<float(r['t1_day'])<=584]
        original=[r for r in root.daily(case/'crop.csv') if 524<float(r['day'])<=584]
        diffs=[dict(day=x['day'],fields={k:dict(restarted=x[k],full=y[k]) for k in x if x[k]!=y[k]}) for x,y in zip(root.daily(out/'whole/crop.csv'),original)]
        assert len(diffs)==60 and all(set(r['fields'])=={'pressure_average_cm'} for r in diffs)
        (out/'RETAINED_DIAGNOSTIC_FAILURE.json').write_text(json.dumps(diffs,indent=2)+'\n')
    (out/'COMPLETE.json').write_text(json.dumps(dict(actual_observation=True,exact_unobserved=True,own_strict_537=True,production_admission=False))+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('parent','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir()
    for opt in ('O2','O0'):qualify(opt,a.parent.resolve()/('build-'+opt),a.parent.resolve()/'full-O2',out/opt,a.compiler.resolve())
