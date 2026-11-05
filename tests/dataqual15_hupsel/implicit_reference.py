"""Strict implicit reference-family refinements, never an oracle replacement."""
import argparse,ast,io,json,math,os,re,subprocess,sys,time
from pathlib import Path
import composed_chronology as inherited
import original_reference_balance_control as criteria
from original_chronology_audit import csv_rows
ROOT=inherited.ROOT;BASE=inherited.BASE;sha=inherited.sha
REG='IMPLICIT_REFERENCE_PREREGISTRATION_20261105.json';CAPS=(.00015625,.000078125);NAMES=('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra');BOUND=5.371840000016327e-7

def source_control(files):
    tree=ast.parse((ROOT/'tests/dataqual15_hupsel/original_oxygen_k_jacobian.py').read_text())
    values={n.targets[0].id:ast.literal_eval(n.value)for n in ast.walk(tree)if isinstance(n,ast.Assign)and isinstance(n.targets[0],ast.Name)and n.targets[0].id in ('anchor','replacement')}
    before=files['provider-selected/MOD_MvG_functions.f90'].decode().replace('\r\n','\n');assert before.count(values['anchor'])==1
    after=before.replace(values['anchor'],values['replacement']);assert after.replace(values['replacement'],values['anchor'])==before
    assert after==files['reference-implicit-k/MOD_MvG_functions.f90'].decode()
    metadata=json.loads(files['reference-implicit-k/COMPLETE.json']);assert metadata['source_sha256']==sha(after.encode())and metadata['production_admission']is False
    exe=files['reference-implicit-k/reference.exe'];assert sha(exe)==metadata['executable_sha256']
    events=json.loads(files['reference-implicit-k/EVENTS.json']);assert [e['returncode']for e in events]==[0,0,100]
    strict=json.loads(files['reference-implicit-balanced/PREREGISTRATION.json']);assert strict['parent_executable_sha256']==sha(exe)and strict['parent_source_sha256']==sha(after.encode())and strict['parameters']==criteria.VALUES and strict['production_admission']is False
    initial={n:files['reference-implicit-balanced/case/'+n]for n in NAMES}
    for n in NAMES:
        raw=files['original/unobserved/'+n]
        if n=='swap.swp':
            raw,count=re.subn(rb'(?m)^(\s*SWKIMPL\s*=\s*)0\b',rb'\g<1>1',raw);assert count==1
            for key,value in criteria.VALUES.items():raw,count=re.subn(rb'(?m)^(\s*'+key.encode()+rb'\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+value.encode(),raw);assert count==1
        assert initial[n]==raw and sha(raw)==strict['inputs_sha256'][n]
    actual=json.loads(files['reference-implicit-balanced/RESULT.json']);assert actual['returncode']==100 and actual['swap_ok']and b'simulation succesfully terminated'in files['reference-implicit-balanced/case/swap.ok']
    import original_k_jacobian_check as derivative
    source=files['reference-derivative-check/swap.f90'].decode();assert source.replace(derivative.USE,'').replace(derivative.BLOCK,'')==files['provider-selected/swap.f90'].decode().replace('\r\n','\n')
    witness=json.loads(files['reference-derivative-check/RESULT.json']);rows=[list(map(float,l.split()))for l in files['reference-derivative-check/derivative.dat'].splitlines()]
    assert len(rows)==170 and all(len(r)==5 and all(math.isfinite(x)for x in r)for r in rows)and {(int(r[0]),int(r[1]))for r in rows}=={(i,j)for i in range(1,35)for j in range(1,6)}
    error=max(abs(r[3]-r[4])/max(1e-8,abs(r[3]),abs(r[4]))for r in rows);assert error==witness['maximum_scaled_difference']and error<1e-4 and sha(source.encode())==witness['source_sha256']and sha(files['reference-derivative-check/check.exe'])==witness['executable_sha256']
    return initial,exe,dict(archive_sha256=inherited.ORIGINAL,reference_executable_sha256=sha(exe),derivative_source_sha256=sha(after.encode()),actual_derivative_cases=170,maximum_scaled_derivative_difference=error,source_scope='EXPLICIT_PRIOR_REFERENCE_ONLY_KSATEXM_DERIVATIVE_AND_STRICT_IMPLICIT_INPUT_FAMILY_NOT_IMMUTABLE_ORACLE')

def inputs(initial,cap):
    assert cap in CAPS;result=dict(initial);raw=result['swap.swp']
    matches=re.findall(rb'(?m)^\s*DTMAX\s*=\s*([\d.eE+\-]+)',raw);assert len(matches)==1 and float(matches[0])==.0003125
    raw,n=re.subn(rb'(?m)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+format(cap,'.10f').encode(),raw);assert n==1
    raw,n=re.subn(rb'(?m)^(\s*TEND\s*=\s*)2004-12-31',rb'\g<1>2003-08-07',raw);assert n==1;result['swap.swp']=raw;return result

def audit(files,parent,cap,binding):
    r=json.loads(files['START.json']);end=json.loads(files['RESULT.json']);initial,exe,pin=source_control(parent);assert pin==binding==r['binding']
    wanted=inputs(initial,cap);assert r['cap']==cap and r['reference_executable_sha256']==sha(exe)and r['registration']==json.loads((BASE/REG).read_text())and r['from_initialization']is True and r['checkpoint_seed']is None
    assert all(r['registration'][k]is False for k in ('production_admission','whole_scientific_admission','original_oracle_replaced','migration_complete'))
    assert r['inputs_sha256']=={n:sha(b)for n,b in wanted.items()}and all(files['case/'+n]==b for n,b in wanted.items())
    assert end['status']=='EXECUTED'and end['returncode']==100 and end['swap_ok']and end['production_admission']is False and b'simulation succesfully terminated'in files['case/swap.ok']
    assert sha(files['reference.exe'])==sha(exe)and end['outputs_sha256']=={n:sha(files['case/'+n])for n in ('result_output.csv','hupsel_profiles.csv')}
    daily=csv_rows(files['case/result_output.csv']);profiles=csv_rows(files['case/hupsel_profiles.csv']);baseline=csv_rows(parent['reference-implicit-balanced/case/result_output.csv']);geometry=csv_rows(parent['original/unobserved/hupsel_profiles.csv'])[:34]
    assert len(daily)==585 and len(profiles)==585*34 and len(baseline)==1097 and [r['DATE']for r in daily]==[r['DATE']for r in baseline[:585]]and daily[-1]['DATE']=='2003-08-07'
    largest=0
    for day,r in enumerate(daily):
        assert all(math.isfinite(float(r[k]))for k in ('WTOT','TREDWET','TPOT','TACT','BALDEV'))and min(float(r[k])for k in ('WTOT','TREDWET','TPOT','TACT'))>=0
        p=profiles[34*day:34*(day+1)];assert [int(x['node'])for x in p]==list(range(1,35))and all(int(x['day'])==day for x in p)
        assert [(x['z_cm'],x['dz_cm'])for x in p]==[(x['z_cm'],x['dz_cm'])for x in geometry]
        assert all(all(math.isfinite(float(x[k]))for k in ('head_cm','water_content','temperature_c','concentration_mg_cm3'))and 0<=float(x['water_content'])<=1 for x in p)
        stock=math.fsum(float(x['dz_cm'])*float(x['water_content'])for x in p);error=abs(stock-float(r['WTOT']));gamma=36*sys.float_info.epsilon/(1-36*sys.float_info.epsilon);assert error<=.5e-12+gamma*stock;largest=max(largest,error)
    return dict(cap=cap,days=584,primitive_rows=len(profiles),maximum_primitive_stock_publication_error_cm=largest,oxygen584_cm=float(daily[584]['TREDWET']),maximum_reported_BALDEV_cm=max(abs(float(r['BALDEV']))for r in daily),reported_balance_is_not_exact_mass_qualification=True,production_admission=False,whole_scientific_admission=False,original_oracle_replaced=False),daily

def screen(levels):
    assert len(levels)==3 and all(len(r)>=585 for r in levels)
    assert all(a['DATE']==b['DATE']==c['DATE']for a,b,c in zip(*[r[:585]for r in levels]))
    for rows in levels:
        assert all(math.isfinite(float(r['TREDWET']))and float(r['TREDWET'])>=0 for r in rows)
    changes=[max(abs(float(a['TREDWET'])-float(b['TREDWET']))for a,b in zip(levels[i][:585],levels[i+1][:585]))for i in (0,1)]
    return dict(caps=[.0003125,*CAPS],oxygen584_cm=[float(r[584]['TREDWET'])for r in levels],successive_prefix_maximum_changes_cm=changes,unchanged_bound_cm=BOUND,research_family_self_convergence_screen_pass=all(v<=BOUND for v in changes),original_oracle_replaced=False,original_reference_accuracy_qualified=False,production_admission=False,whole_scientific_admission=False,migration_complete=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cap',type=float,choices=CAPS,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();parent,_=inherited.original();initial,exe,binding=source_control(parent);wanted=inputs(initial,a.cap);target=out/'reference.exe';target.write_bytes(exe);case=out/'case';case.mkdir()
    for n,b in wanted.items():(case/n).write_bytes(b)
    record=dict(cap=a.cap,registration=json.loads((BASE/REG).read_text()),reference_executable_sha256=sha(exe),inputs_sha256={n:sha(b)for n,b in wanted.items()},from_initialization=True,checkpoint_seed=None,binding=binding)
    (out/'START.json').write_text(json.dumps(record,indent=2)+'\n');start=time.monotonic();env=dict(os.environ,OMP_NUM_THREADS='1');env.pop('SWAP5_DIAG_PREDECESSOR',None)
    try:r=subprocess.run([str(target)],cwd=case,env=env,capture_output=True,timeout=3600);code=r.returncode;stdout=r.stdout;stderr=r.stderr
    except subprocess.TimeoutExpired as e:code=None;stdout=e.stdout or b'';stderr=e.stderr or b''
    (out/'stdout').write_bytes(stdout);(out/'stderr').write_bytes(stderr);ok=(case/'swap.ok').exists();status='EXECUTED'if code==100 and ok else('CENSORED'if code is None else'FAILED')
    result=dict(status=status,returncode=code,seconds=time.monotonic()-start,swap_ok=ok,outputs_sha256={n:sha((case/n).read_bytes())for n in ('result_output.csv','hupsel_profiles.csv')if(case/n).exists()},production_admission=False);(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');assert status=='EXECUTED',result
    actual={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};report,_=audit(actual,parent,a.cap,binding);(out/'AUDIT.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True)

if __name__=='__main__':main()
