"""Scoped immutable original/current-composed accepted-grid reconciliation."""
import argparse,base64,copy,io,json,math,sys,tarfile,zipfile
from pathlib import Path
import composed_oxygen_evidence as current
import original_chronology_evidence as old
import original_chronology_audit as algebra
from film_runtime_profiles import profile4
ROOT=current.ROOT;BASE=current.BASE;sha=current.sha;REG='COMPOSED_CHRONOLOGY_PREREGISTRATION_20261105.json'
ORIGINAL='99adab40cc703f4533abc89befa5d16d76d6a36d1b7a09ef3e463becf997c1db'

def original_binding(files):
    sys.path.insert(0,str(ROOT/'tests/dataqual15'))
    from original_sources import select_dec_branches
    import original_oxygen_chronology as source
    import original_micro_forcing as micro
    provider=json.loads(files['provider/BUILD.json']);pins={n.replace('\\','/'):h for n,h in provider['selected_sha256'].items()}
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
        for name in ('swap.f90','swapoutput.f90','RWU_micro.f90','MOD_MvG_functions.f90'):
            raw=select_dec_branches(t.extractfile('SWAP/'+name).read().decode('cp1252')).encode('cp1252')
            assert raw==files['provider-selected/'+name]and sha(raw)==pins['selected/'+name]
    generated=source.instrument(files['provider-selected/swap.f90'].decode().replace('\r\n','\n'));assert generated==files['original/swap.f90'].decode()
    generated=generated.replace(source.USE,source.USE+micro.owner.USE).replace(source.DECL,source.DECL+micro.owner.DECL).replace('      call integral(3)\n','      call integral(3)\n'+micro.owner.BLOCK)
    assert generated==files['micro/swap.f90'].decode()
    for mode in ('observed','unobserved'):
        r=json.loads(files['original/'+mode+'/RUN.json']);assert sha(files['original/'+mode+'.exe'])==r['executable_sha256']
        assert all(sha(files['original/'+mode+'/'+n])==h for n,h in r['inputs'].items())
    complete=json.loads(files['micro/COMPLETE.json']);assert sha(files['micro/observed.exe'])==complete['executable_sha256']
    assert all(sha(files['micro/case/'+n])==h and files['micro/case/'+n]==files['original/unobserved/'+n]for n,h in complete['inputs'].items())
    assert algebra.physical(files['original/observed/result_output.csv'])==algebra.physical(files['original/unobserved/result_output.csv'])==algebra.physical(files['micro/case/result_output.csv'])
    assert files['original/observed/hupsel_profiles.csv']==files['original/unobserved/hupsel_profiles.csv']==files['micro/case/hupsel_profiles.csv']
    for n in ('original_accepted.dat','original_nodes.dat'):assert files['original/observed/'+n]==files['micro/case/'+n]
    science=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());reference=files['reference-archive/dtmax-0.0003125/result_output.csv']
    assert sha(reference)==science['members']['original/dtmax-0.0003125/result_output.csv']
    actual=algebra.csv_rows(files['original/unobserved/result_output.csv']);fine=algebra.csv_rows(reference)
    assert len(actual)==len(fine)==1097 and actual[584]['DATE']==fine[584]['DATE']and abs(float(actual[584]['TREDWET'])-float(fine[584]['TREDWET']))<=5e-13
    archive=(BASE/science['archive']).read_bytes();assert sha(archive)==science['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(archive))as t:
        for name in json.loads(files['original/unobserved/RUN.json'])['inputs']:
            assert t.extractfile('original/dtmax-0.0003125/'+name).read()==files['original/unobserved/'+name]
    return dict(archive_sha256=ORIGINAL,scope='IMMUTABLE_ORIGINAL_RUNTIME_ONLY_NOT_OLD_TYPED_CODEC_ENVELOPE',physical_output_and_profile_controls=True,generated_source_body_controls=True)

def original():
    record=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text());assert record['archive_sha256']==ORIGINAL and record['production_admission']is False and record['whole_scientific_admission']is False
    files=old.unpack(record);assert all(current.run.parent.prior.safe(n)for n in files)
    return files,original_binding(files)

def native(opt,platform):
    if platform=='windows':
        record=json.loads((BASE/f'COMPOSED_OXYGEN_WINDOWS_{opt}_20261105.json').read_text());raw=(BASE/f'COMPOSED_OXYGEN_WINDOWS_{opt}_20261105.tar.xz').read_bytes()
    else:
        manifest=json.loads((BASE/'COMPOSED_OXYGEN_POSIX_20261105.json').read_text());pin=manifest['original_artifacts'][opt];zipped=(BASE/pin['archive']).read_bytes();assert sha(zipped)==pin['archive_sha256']
        with zipfile.ZipFile(io.BytesIO(zipped))as z:record=json.loads(z.read(f'composed-oxygen/{opt}/CAPSULE.json'));raw=z.read(f'composed-oxygen/{opt}/CAPSULE.tar.xz')
    report=current.read(raw,record);assert report['optimization']==opt and report['platform']==platform
    needed=('whole/root_accepted.dat','whole/root_nodes.dat','whole/budget.csv','whole/checkpoint.bin','RESULT.json');files={}
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        for n in needed:
            b=t.extractfile(n).read();assert sha(b)==record['files_sha256'][n];files[n]=b
    return files,dict(platform=platform,optimization=opt,archive_sha256=sha(raw),scope='COMPLETE_CURRENT_COMPOSED_NATIVE_SOURCE_OBJECT_CONTROL_REPLAY_PROOF_REMEASURED')

def validate_intervals(intervals):
    assert intervals and all(len(r)==4 and all(math.isfinite(x)for x in r)for r in intervals)
    assert intervals[0][0]==0 and abs(intervals[-1][1]-1)<=1e-12
    gamma=36*2.220446049250313e-16/(1-36*2.220446049250313e-16)
    assert all(b>a and p>=0 and o>=0 and o-p<=gamma*p for a,b,p,o in intervals)
    assert all(abs(a[1]-b[0])<=1e-12 for a,b in zip(intervals,intervals[1:]))
    assert abs(math.fsum(b-a for a,b,_,_ in intervals)-1)<=1e-12

def overlaps(original,native):
    validate_intervals(original);validate_intervals(native);i=j=0;cells=[]
    while i<len(original)and j<len(native):
        a,b,*_=original[i];c,d,*_=native[j];dt=min(b,d)-max(a,c)
        if dt>0:cells.append((i,j,dt))
        if b<=d:i+=1
        else:j+=1
    assert abs(math.fsum(dt for _,_,dt in cells)-1)<=1e-12
    return cells

def reconcile(original_rows,original_nodes,native_trace,native_nodes,budget,original_daily,geometry,point):
    a=algebra.intervals(original_rows,True);b=algebra.intervals(native_trace,False);cells=overlaps(a,b)
    ar=[r for r in original_rows if r[0]==584];br=[r for r in native_trace if r[0]>=583 and r[1]<=584];bn=[r for r in native_nodes if r[0]>=583 and r[1]<=584]
    assert len(a)==len(ar)==len(original_nodes)==3206 and len(b)==len(br)==len(bn)
    assert len(geometry)==34 and [int(r['node'])for r in geometry]==list(range(1,35))
    for k in ('z_cm','dz_cm'):assert point[k]==[float(r[k])for r in geometry]
    for r,n in zip(ar,original_nodes):
        assert n[:2]==r[1:3]and len(n)==274 and all(math.isfinite(x)for x in n)
        assert all(0<=x<=1 for x in n[36:70])and abs(math.fsum(n[172:206])-r[4])<=1e-12
    for r,n in zip(br,bn):
        assert n[:2]==r[:2]and len(n)==104 and all(math.isfinite(x)for x in n)
        assert all(0<=x<=1 for x in n[36:70])and abs(math.fsum(n[70:104])-r[6])<=1e-10
    amount=lambda rows:math.fsum((y-x)*o for x,y,_,o in rows)
    original_amount=amount(a);native_amount=amount(b)
    assert abs(original_amount-float(original_daily[584]['TREDWET']))<=5e-13
    day=[r for r in budget if float(r['t1_day'])==584];assert len(day)==1 and abs(native_amount-float(day[0]['oxygen_reduction_cm']))<=1e-10
    decomposition=algebra.attribution(a,b);assert abs(decomposition['total_delta_cm']-(native_amount-original_amount))<=1e-13
    witnesses={}
    for key,start in [('head_cm',2),('theta',36)]:
        weighted=[];maximum=0;witness=None
        for i,j,dt in cells:
            diff=[abs(x-y)for x,y in zip(original_nodes[i][start:start+34],bn[j][start:start+34])]
            weighted.append(dt*math.fsum(diff)/34)
            if max(diff)>maximum:
                node=max(range(34),key=diff.__getitem__);maximum=diff[node]
                witness=dict(node=node+1,original_interval_day=[583+a[i][0],583+a[i][1]],native_interval_day=[583+b[j][0],583+b[j][1]],overlap_duration_day=dt,original_accepted_start=original_nodes[i][start+node],native_accepted_start=bn[j][start+node])
        witnesses[key]=dict(duration_node_mean_absolute_start_difference=math.fsum(weighted),maximum_overlapping_start_difference=maximum,maximum_witness=witness)
    return dict(original_accepted_steps=len(a),native_accepted_steps=len(b),overlap_cells=len(cells),original_oxygen_cm=original_amount,native_oxygen_cm=native_amount,decomposition=decomposition,accepted_start_state_witness=witnesses,witness_scope='OWN_ACCEPTED_PRE_ROOT_START_STATES_ON_EXACT_OVERLAPS_NOT_INTERPOLATED_CONTINUOUS_STATE_OR_CAUSAL_ATTRIBUTION',unchanged_oxygen_bound_cm=5.371840000016327e-7,inside_unchanged_scientific_bound=abs(native_amount-original_amount)<=5.371840000016327e-7,reference_accuracy_qualified=False,production_admission=False,whole_scientific_admission=False,migration_complete=False)

def refusal_controls(args):
    results=[]
    for label in ('missing_native_leaf','duplicate_native_leaf','nonfinite_rate','wrong_native_clock','wrong_native_node_clock','wrong_original_node_clock','wrong_root_sink','wrong_daily_oxygen','wrong_geometry','nonfinite_original_state','wrong_original_daily'):
        values=copy.deepcopy(args);a,an,b,bn,budget,donor,g,p=values
        if label=='missing_native_leaf':b.pop(next(i for i,r in enumerate(b)if r[0]>=583))
        elif label=='duplicate_native_leaf':b.insert(-1,b[-1])
        elif label=='nonfinite_rate':b[-1][4]=float('nan')
        elif label=='wrong_native_clock':b[-1][0]+=1e-5
        elif label=='wrong_native_node_clock':bn[-1][0]+=1e-5
        elif label=='wrong_original_node_clock':an[0][0]+=1e-5
        elif label=='wrong_root_sink':bn[-1][70]+=1e-6
        elif label=='wrong_daily_oxygen':budget[-1]['oxygen_reduction_cm']=str(float(budget[-1]['oxygen_reduction_cm'])+1e-6)
        elif label=='wrong_geometry':p['dz_cm'][0]+=1e-6
        elif label=='nonfinite_original_state':an[0][2]=float('nan')
        else:donor[584]['TREDWET']=str(float(donor[584]['TREDWET'])+1e-6)
        try:reconcile(*values)
        except(AssertionError,ValueError):results.append(label)
        else:raise AssertionError('accepted composed chronology defect '+label)
    return results

def measure():
    registration=json.loads((BASE/REG).read_text());assert all(registration[k]is False for k in ('production_admission','whole_scientific_admission','migration_complete'))
    files,binding=original();a=algebra.numbers(files['original/observed/original_accepted.dat'],15);an=algebra.numbers(files['original/observed/original_nodes.dat'],274);donor=algebra.csv_rows(files['original/unobserved/result_output.csv']);geometry=[r for r in algebra.csv_rows(files['original/unobserved/hupsel_profiles.csv'])if int(r['day'])==584]
    reports={};bindings={}
    for platform in ('windows','posix'):
        for opt in ('O0','O2'):
            f,pin=native(opt,platform);trace=algebra.numbers(f['whole/root_accepted.dat'],9);nodes=algebra.numbers(f['whole/root_nodes.dat'],104);budget=algebra.csv_rows(f['whole/budget.csv']);point=profile4(f['whole/checkpoint.bin']);args=(a,an,trace,nodes,budget,donor,geometry,point)
            key=platform+'-'+opt;report=reconcile(*args);assert report['inside_unchanged_scientific_bound']is False;report['rejected_actual_data_controls']=refusal_controls(args);reports[key]=report;bindings[key]=pin
    return dict(status='ACTUAL_ORIGINAL_COMPOSED_GRID_ATTRIBUTION_AND_STATE_WITNESSES_QUALIFIED_NOT_CAUSAL_ADMISSION',original=binding,composed=bindings,results=reports,production_admission=False,whole_scientific_admission=False,migration_complete=False)

def dependencies():
    d=current.dependencies()
    for name in ('composed_chronology.py','test_composed_chronology.py','original_chronology_evidence.py','original_chronology_audit.py','original_oxygen_chronology.py','original_micro_forcing.py','original_oxygen_forcing.py','scientific_followup.py'):
        p='tests/dataqual15_hupsel/'+name;d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    for p in ('tests/dataqual15/original_sources.py','tools/vq/b0_source_runner.py','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64','integration/dataqual15_hupsel/'+REG,'.github/workflows/hupsel-composed-chronology.yml'):
        d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    return d

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--write',type=Path);p.add_argument('--verify',type=Path);a=p.parse_args();result=measure();record=dict(result=result,qualification_dependencies=dependencies())
    if a.write:a.write.write_text(json.dumps(record,indent=2)+'\n')
    if a.verify:assert json.loads(a.verify.read_text())==record
    print(result['status'])

if __name__=='__main__':main()
