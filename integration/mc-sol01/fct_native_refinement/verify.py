"""Independent conservative profile/balance and fresh-process proof checks."""
import base64,csv,hashlib,io,json,math,re,struct,tarfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()

def assess(files):
    for p in ['run.py','verify.py','seal.py']:
        assert files['validation/'+p]==(HERE/p).read_bytes(),('validation source',p)
    predecessor=json.loads(files['PREDECESSOR.json']);assert predecessor['cases']==24 and len(predecessor['controls'])==8
    owner=json.loads(files['OWNER.json']);assert owner['result']['qualified'] and len(owner['controls'])==13
    profiles={};summaries={};processes=0;maxima={'water':0.,'solute':0.};cost={}
    def rows(p):
        result=[{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(files[p].decode()))]
        assert result and all(math.isfinite(v) for row in result for v in row.values());return result
    oldindex=json.loads((HERE.parent/'fct_native_domain/NATIVE_EVIDENCE_INDEX.json').read_text())
    oldraw=base64.b64decode((HERE.parent/'fct_native_domain/NATIVE_EVIDENCE.tar.xz.b64').read_bytes());assert sha(oldraw)==oldindex['sha256']
    with tarfile.open(fileobj=io.BytesIO(oldraw),mode='r:xz')as t:
        old={p:t.extractfile('build-o2/'+p).read() for p in json.loads(files['build-o2/build.json'])['generated']}
        original_swp=t.extractfile('native-o2/1.0-1.0-unequal/project.swp').read().decode()
    for opt in ['o0','o2']:
        b=json.loads(files[f'build-{opt}/build.json']);assert b['status']=='BUILT_RESEARCH_NATIVE' and len(set(b['closure']))==201
        raw=files[f'build-{opt}/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==b['baseline']
        for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h and sha(files['source/'+h])==h
        for p,h in b['generated'].items():assert sha(files[f'build-{opt}/'+p])==h and files[f'build-{opt}/'+p]==old[p]
        cmd=b['events'][-1]['command'];assert [x for x in cmd if x.endswith('.f90')]==b['closure']
        assert all(x in cmd for x in ['-'+opt.upper(),'-fcheck=all','-ffpe-trap=invalid,zero,overflow'])
        assert all(e['returncode']==0 for e in b['events'])
        readers=[e for e in b['events'] if '-std=legacy' in e['command']];assert len(readers)==153
        for i,e in enumerate(readers):assert '-'+opt.upper() in e['command'] and files[f'build-{opt}/reader-{i:03d}']
        roots=set()
        for p in b['closure']:
            keys=[k for k in b['inputs'] if p.endswith('/'+k)]
            if keys:assert len(keys)==1;roots.add(p[:-len(keys[0])])
            else:assert Path(p).name in b['generated'] and Path(p).parent==Path(cmd[-1]).parent
        assert len(roots)==1
        cost[opt]={'build_seconds':sum(e['seconds'] for e in b['events']),'native_seconds':0.}
        for phase in ['pilot','refinement','duration']:
            prefix=f'{phase}-{opt}/';r=json.loads(files[prefix+'RESULT.json'])
            assert r['status']=='EXECUTIONS_COMPLETE' and r['phase']==phase and r['build']==b
            assert r['runner_sha256']==sha(files['validation/run.py'])
            expected={'pilot':{(1,.4,.001,1.)},'refinement':{(f,.4,.001,1.) for f in [1,2,4]}|{(1,.4,t,1.) for t in [.0005,.00025]},'duration':{(1,4.,.001,e) for e in [.5,1.,2.]}}[phase]
            assert {(c['factor'],c['days'],c['tolerance'],c['exponent']) for c in r['cases']}==expected and len(r['cases'])==len(expected)
            for c in r['cases']:
                f,days,tol,exp=c['factor'],c['days'],c['tolerance'],c['exponent'];base=prefix+c['name']+'/'
                swp=files[base+'project.swp'].decode();mesh=f'1 1 40.0 {20*f}\n2 2 2.0 {f}\n3 2 78.0 {20*f}'
                assert swp.count(mesh)==1 and f'FREXP={exp}' in swp
                restored=swp.replace(mesh,'1 1 40.0 20\n2 2 2.0 1\n3 2 78.0 20')
                restored=re.sub(r'(?im)^FREXP\s*=.*$','FREXP=1.0',restored);assert restored==original_swp
                nml=files[base+'input.nml'].decode()
                assert f'drain_cm_day={41*f}*{.00005/f:.17g}' in nml and f'temporal_tolerance={tol:.17g}' in nml
                assert nml.count(f'upper_layer_bottom_node={20*f},')==2 and 'potential_transpiration_cm_day=4*.001' in nml
                assert 'ends_day='+','.join(f'{days*j/4:.17g}' for j in range(1,5)) in nml
                assert len(c['events'])==(3 if phase=='duration' else 1)
                for e in c['events']:
                    assert e['returncode']==0 and not e['censored'];processes+=1;cost[opt]['native_seconds']+=e['seconds']
                    assert Path(e['command'][0]).name=='native_fct' and Path(e['command'][1]).name=='input.nml'
                    assert files[base+e['label']+'/stderr']==b''
                budget=rows(base+'full/budget.csv');state=rows(base+'full/state.csv');end=rows(base+'full/endpoint.csv')[0]
                assert len(budget)==4 and len(state)==41*f and end['time_day']==days and end['pond_cm']==0
                assert [row['t1_day'] for row in budget]==[days*j/4 for j in range(1,5)]
                assert sum(row['actual_transpiration_cm'] for row in budget)>0
                for j,row in enumerate(budget):
                    dt=days/4
                    for s,u in [('water','cm'),('solute','mg_cm2')]:
                        err=row[f'{s}_end_{u}']-row[f'{s}_start_{u}']-row[f'{s}_in_{u}']+row[f'{s}_out_{u}']
                        maxima[s]=max(maxima[s],abs(err),abs(row[f'{s}_residual_{u}']));assert abs(err)<1e-10
                        if j:assert abs(row[f'{s}_start_{u}']-budget[j-1][f'{s}_end_{u}'])<1e-11
                    assert abs(row['water_in_cm']-.005*dt)<1e-10
                    assert abs(row['solute_in_mg_cm2']-.000875*dt)<1e-10
                    assert abs(row['water_out_cm']-(41*.00005*dt+row['actual_transpiration_cm']+row['runoff_cm']))<1e-10
                aggregates=[];z=0.
                for i,v in enumerate(state):
                    h=v['dz_cm'];theta=v['theta'];conc=v['concentration_mg_cm3'];d=v['dissolved_mg_cm2'];s=v['sorbed_mg_cm2']
                    assert min(h,theta,conc,d,s)>=0 and abs(v['z_cm']+z+h/2)<1e-10;z+=h
                    capacity=.26 if i<20*f else .6
                    assert abs(d-theta*h*conc)<1e-11 and abs(s-capacity*h*conc**exp)<1e-11
                assert abs(z-120)<1e-10
                for i in range(41):
                    group=state[i*f:(i+1)*f]
                    aggregates.append([sum(v['dz_cm'] for v in group),sum(v['theta']*v['dz_cm'] for v in group),sum(v['dissolved_mg_cm2'] for v in group),sum(v['sorbed_mg_cm2'] for v in group)])
                assert abs(sum(v[1] for v in aggregates)-end['total_water_cm'])<1e-10
                assert abs(sum(v[2]+v[3] for v in aggregates)+end['pond_solute_mg_cm2']-end['total_solute_mg_cm2'])<1e-10
                assert abs(budget[-1]['water_end_cm']-end['total_water_cm'])<1e-10
                assert abs(budget[-1]['solute_end_mg_cm2']-end['total_solute_mg_cm2'])<1e-10
                raw=files[base+'full/restart.bin'];assert struct.unpack_from('<q',raw,12)[0]==1670001 and struct.unpack_from('<I',raw,len(raw)-4)[0]==zlib.crc32(raw[:-4])
                if phase=='duration':
                    for p in ['restart.bin','state.csv','endpoint.csv']:assert files[base+'full/'+p]==files[base+'resume/'+p]
                    assert budget[2:]==rows(base+'resume/budget.csv')
                key=(opt,phase,f,tol,exp);profiles[key]=aggregates
                summaries[str(key)]={'initial_water_cm':budget[0]['water_start_cm'],'initial_solute_mg_cm2':budget[0]['solute_start_mg_cm2'],'endpoint':end,'accepted_substeps':sum(v['accepted_substeps'] for v in budget)}
    assert processes==30 and max(maxima.values())<1e-10
    difference=max(abs(a-b) for key,profile in profiles.items() if key[0]=='o0' for left,right in zip(profile,profiles[('o2',*key[1:])]) for a,b in zip(left,right));assert difference<1e-12
    def compare(a,b):
        assert all(abs(x[0]-y[0])<1e-12 for x,y in zip(a,b))
        return {'water_l1_cm':sum(abs(x[1]-y[1]) for x,y in zip(a,b)),
                'dissolved_l1_mg_cm2':sum(abs(x[2]-y[2]) for x,y in zip(a,b)),
                'sorbed_l1_mg_cm2':sum(abs(x[3]-y[3]) for x,y in zip(a,b)),
                'total_solute_l1_mg_cm2':sum(abs(x[2]+x[3]-y[2]-y[3]) for x,y in zip(a,b))}
    spatial={f'{41*a}-{41*b}':compare(profiles['o2','refinement',a,.001,1.],profiles['o2','refinement',b,.001,1.]) for a,b in [(1,2),(2,4)]}
    temporal={f'{a}-{b}':compare(profiles['o2','refinement',1,a,1.],profiles['o2','refinement',1,b,1.]) for a,b in [(.001,.0005),(.0005,.00025)]}
    initial={str(f):{k:summaries[str(('o2','refinement',f,.001,1.))][k] for k in ['initial_water_cm','initial_solute_mg_cm2']} for f in [1,2,4]}
    return dict(status='BOUNDED_NATIVE_REFINEMENT_OBSERVATIONS_AND_FOUR_DAY_RESTART_VERIFIED',cases=18,processes=processes,exact_four_day_restarts=6,maxima=maxima,O0_O2_difference=difference,spatial=spatial,temporal=temporal,initial_stocks=initial,case_summaries=summaries,cost=cost,general_native_accuracy=False,historical_forcing=False,production_activated=False)

def controls(files):
    passed=[];base='duration-o0/f1-d4.0-t0.001-e0.5/'
    for p in [base+'resume/state.csv',base+'full/restart.bin','OWNER.json','build-o0/native_driver.f90']:
        f=dict(files);f.pop(p)
        try:assess(f)
        except (AssertionError,KeyError,ValueError):passed.append('missing '+p);continue
        raise AssertionError('accepted missing '+p)
    def change_sorbed(b):
        lines=b.decode().splitlines();values=lines[1].split(',');values[-1]=str(float(values[-1])+.001);lines[1]=','.join(values)
        return ('\n'.join(lines)+'\n').encode()
    mutations=[('unscaled refinement drainage','refinement-o2/f2-d0.4-t0.001-e1.0/input.nml',lambda b:b.replace(b'82*2.5000000000000001e-05',b'82*.00005')),
               ('changed layer boundary','refinement-o2/f2-d0.4-t0.001-e1.0/project.swp',lambda b:b.replace(b'1 1 40.0 40',b'1 1 41.0 40')),
               ('changed fine sorbed profile','refinement-o2/f4-d0.4-t0.001-e1.0/full/state.csv',change_sorbed),
               ('lost exact empty limit','build-o2/native_driver.f90',lambda b:b.replace(b'supply%exact_empty_pool_chemistry=.true.',b'supply%exact_empty_pool_chemistry=.false.'))]
    for label,p,change in mutations:
        f=dict(files);f[p]=change(f[p]);assert f[p]!=files[p],label
        try:assess(f)
        except (AssertionError,KeyError,ValueError):passed.append(label);continue
        raise AssertionError('accepted '+label)
    return passed

def unpack():
    index=json.loads((HERE/'EVIDENCE_INDEX.json').read_text());raw=base64.b64decode((HERE/'EVIDENCE.tar.xz.b64').read_bytes());assert sha(raw)==index['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
        ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
        f={m.name:t.extractfile(m).read() for m in ms}
    assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b) for p,b in f.items()};return f

if __name__=='__main__':
    f=unpack();r=assess(f);r['controls']=controls(f);print(json.dumps(r,indent=2))
