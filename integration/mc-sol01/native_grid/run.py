"""Bounded nested-grid experiment using the unchanged actual native project."""
import argparse,base64,csv,hashlib,io,json,os,signal,subprocess,sys,tarfile,time
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
CAPSULE='integration/mc-sol01/evidence/MC_SOL01_REFINED_YEAR_20261023.tar.xz.b64'
EXPECTED='7dfe7a6cee6666484ebbbc8614a979d8ea86b240f7a46ddb3b66358d27303b4e'
PREFIX='annual-O2/O2/annual1998/'
MESH='1 1 40.0 20\n2 2 2.0 1\n3 2 78.0 20'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def read(path):
    return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(path.open())]
def audit(path):
    text=''.join(l.split('=',1)[1] for l in path.read_text().splitlines() if l.startswith('! native_project_audit_base64='))
    return json.loads(base64.b64decode(text))
def validate(folder,days):
    m=json.loads((folder/'manifest.json').read_text())
    assert m['status']=='COMPLETE' and m['returncode']==0
    for p,h in m['files'].items():assert sha(folder/p)==h
    assert sha(folder/'input.nml')==m['input_sha256']
    budget=read(folder/'budget.csv');assert len(budget)==days
    state=read(folder/'state.csv');endpoint=read(folder/'endpoint.csv')[0]
    assert all(np.isfinite(v) for rows in [budget,state,[endpoint]] for row in rows for v in row.values())
    for r in state:
        assert min(r[k] for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
    a=audit(folder/'input.nml');rain=[float(r['rain_cm_day']) for r in a['prepared_periods'][0]['rain']]
    assert a['days']==365 and a['periods']==2
    maxima={'water':0.,'solute':0.,'gross_water':0.}
    for i,r in enumerate(budget):
        for substance,unit in [('water','cm'),('solute','mg_cm2')]:
            residual=r[f'{substance}_end_{unit}']-r[f'{substance}_start_{unit}']-r[f'{substance}_in_{unit}']+r[f'{substance}_out_{unit}']
            maxima[substance]=max(maxima[substance],abs(residual),abs(r[f'{substance}_residual_{unit}']))
        gross=r['water_end_cm']-r['water_start_cm']-rain[i]+r['soil_evaporation_cm']+r['pond_evaporation_cm']+r['runoff_cm']+r['actual_transpiration_cm']+.01
        maxima['gross_water']=max(maxima['gross_water'],abs(gross))
        assert abs(r['potential_transpiration_cm']-r['actual_transpiration_cm']-r['drought_reduction_cm']-r['oxygen_reduction_cm'])<1e-12
    assert max(maxima.values())<1e-10,maxima
    water=sum(r['theta']*r['dz_cm'] for r in state)+endpoint['pond_cm']
    solute=sum(r['dissolved_mg_cm2']+r['sorbed_mg_cm2'] for r in state)+endpoint['pond_solute_mg_cm2']
    assert abs(water-endpoint['total_water_cm'])<1e-10 and abs(solute-endpoint['total_solute_mg_cm2'])<1e-10
    assert endpoint['time_day']==days and endpoint['pond_cm']>=0 and endpoint['pond_solute_mg_cm2']>=0
    result=dict(days=days,nodes=len(state),initial_water_cm=budget[0]['water_start_cm'],initial_solute_mg_cm2=budget[0]['solute_start_mg_cm2'],endpoint=endpoint,maxima=maxima,
                cumulative_runoff_cm=sum(r['runoff_cm'] for r in budget),cumulative_transpiration_cm=sum(r['actual_transpiration_cm'] for r in budget),
                cumulative_solute_out_mg_cm2=sum(r['solute_out_mg_cm2'] for r in budget),accepted_substeps=sum(r['accepted_substeps'] for r in budget),
                active_crop_days=sum(a['profile_index'][i]>0 for i in range(days)))
    return result,state

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--days',type=int,choices=[2,8,64],required=True);ap.add_argument('--timeout',type=int,default=180);a=ap.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);bundle=a.bundle.resolve()
    meta=json.loads((bundle/'bundle.json').read_text());build=json.loads((Path(meta['exe']).parent/'build-complete.json').read_text())
    assert meta['status']=='BUILT' and meta['optimization']=='O2' and '-fcheck=all' in build['flags']
    for p,h in meta['executable_sha256'].items():assert sha(Path(p))==h
    for p,h in build['input_sha256'].items():assert sha(ROOT/p)==h,('current build source',p)
    raw=base64.b64decode((ROOT/CAPSULE).read_bytes());assert hashlib.sha256(raw).hexdigest()==EXPECTED
    names=['Project.SWP','Crop Data/First.CRP','Crop Data/Second.CRP','Weather Data/History.998']
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:original={p:t.extractfile(PREFIX+p).read() for p in names}
    inputs={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__)),CAPSULE:sha(ROOT/CAPSULE)}
    inputs.update(build['input_sha256'])
    for p in ['tools/solute/run_project.py','tools/solute/run_column.py']:inputs[p]=sha(ROOT/p)
    report=dict(status='RUNNING',days=a.days,baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                inputs=inputs,bundle=meta,build=build,source_capsule_sha256=EXPECTED,events=[],cases={},comparisons={},full_native_grid_convergence=False,full_mc_sol01_closed=False)
    def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    arrays={};save()
    for factor in [1,2,4]:
        case=out/str(factor);case.mkdir()
        for p,v in original.items():q=case/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
        swp=(case/'Project.SWP').read_text();mesh=f'1 1 40.0 {20*factor}\n2 2 2.0 {factor}\n3 2 78.0 {20*factor}'
        assert swp.count(MESH)==1;(case/'Project.SWP').write_text(swp.replace(MESH,mesh))
        assert (case/'Project.SWP').read_text().replace(mesh,MESH).encode()==original['Project.SWP']
        cmd=[sys.executable,str(ROOT/'tools/solute/run_project.py'),str(case/'Project.SWP'),'--bundle',str(bundle),'--output',str(case/'full'),
             '--stop-after',str(a.days),'--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
        start=time.monotonic();p=subprocess.Popen(cmd,cwd=case,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        censored=False
        try:stdout,stderr=p.communicate(timeout=a.timeout)
        except subprocess.TimeoutExpired:
            censored=True;os.killpg(p.pid,signal.SIGTERM);stdout,stderr=p.communicate()
        (case/'stdout').write_bytes(stdout);(case/'stderr').write_bytes(stderr)
        event=dict(factor=factor,command=cmd,seconds=time.monotonic()-start,returncode=p.returncode,censored=censored)
        report['events'].append(event)
        if p.returncode or censored:
            report['status']='TERMINAL_FAILED_OR_CENSORED';save();print(json.dumps(event));return
        result,state=validate(case/'full',a.days);assert result['nodes']==41*factor
        arrays[factor]={k:np.array([r[k] for r in state]).reshape(41,factor).sum(axis=1) for k in ['dz_cm','dissolved_mg_cm2','sorbed_mg_cm2']}
        arrays[factor]['water_cm']=np.array([r['theta']*r['dz_cm'] for r in state]).reshape(41,factor).sum(axis=1)
        report['cases'][str(factor)]=result;save()
    for lo,hi in [(1,2),(2,4)]:
        assert np.max(np.abs(arrays[lo]['dz_cm']-arrays[hi]['dz_cm']))<1e-12
        left=arrays[lo];right=arrays[hi]
        ml=left['dissolved_mg_cm2']+left['sorbed_mg_cm2'];mr=right['dissolved_mg_cm2']+right['sorbed_mg_cm2']
        cl=left['dissolved_mg_cm2']/left['water_cm'];cr=right['dissolved_mg_cm2']/right['water_cm']
        report['comparisons'][f'{41*lo}-vs-{41*hi}']=dict(soil_total_mass_l1_mg_cm2=float(np.sum(np.abs(ml-mr))),
            relative_soil_total_mass_l1=float(np.sum(np.abs(ml-mr))/np.sum(mr)),
            water_l1_cm=float(np.sum(np.abs(left['water_cm']-right['water_cm']))),
            aqueous_concentration_l1=float(np.sum(left['dz_cm']*np.abs(cl-cr))),maximum_coarse_bin_concentration_difference=float(np.max(np.abs(cl-cr))))
    report['status']='BOUNDED_NATIVE_NESTED_GRID_EXECUTIONS_COMPLETE_NOT_ACCURACY_ADMISSION';save()
    print(json.dumps({k:report[k] for k in ['status','events','cases','comparisons']},indent=2))
if __name__=='__main__':main()
