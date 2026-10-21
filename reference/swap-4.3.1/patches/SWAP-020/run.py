"""Run bounded reference feedback and actual original main with exact raw inputs."""
from pathlib import Path
import argparse, base64, hashlib, io, json, os, runpy, shlex, subprocess, sys, tarfile, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE))
from apply import transform, FIELDS

sha = lambda b: hashlib.sha256(b).hexdigest()
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--output', type=Path, required=True)
ap.add_argument('--direct-only', action='store_true')
args = ap.parse_args()
OUT = args.output.resolve()
OUT.mkdir(parents=True, exist_ok=False)
FC = shlex.split(os.environ.get('FC', 'gfortran'))
events = []


def event(command, cwd, category, stdin=None, expected=0):
    command = list(map(str, command))
    t = time.perf_counter()
    p = subprocess.run(command, cwd=cwd, input=stdin, capture_output=True, timeout=180)
    e = dict(command=command, category=category, returncode=p.returncode, seconds=time.perf_counter()-t)
    for stream in ['stdout', 'stderr']:
        name = f'{len(events):04d}.{stream}'
        b = getattr(p, stream)
        (OUT/name).write_bytes(b)
        e[stream] = name
        e[stream+'_sha256'] = sha(b)
    events.append(e)
    (OUT/'events.json').write_text(json.dumps(events, indent=2)+'\n')
    if p.returncode != expected:
        raise RuntimeError('retained failed event '+str(len(events)-1)+' '+p.stdout.decode(errors='replace')+p.stderr.decode(errors='replace'))
    return p.stdout


archive = ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes()))) as a:
    sources = {Path(n).name: a.extractfile(n).read() for n in a.getnames() if n.endswith('.f90')}
corrected = transform(sources)
changed = {p: dict(before=sha(b), after=sha(corrected[p])) for p, b in sources.items() if b != corrected[p]}
assert set(changed) == {'management_soil.f90', 'wofost_soil_balancecheck.f90', 'wofost_soil_watern.f90'}
(OUT/'TRANSFORM.json').write_text(json.dumps(changed, indent=2)+'\n')
for group, data in [('original', sources), ('corrected', corrected)]:
    d = OUT/group
    d.mkdir()
    for p, b in data.items():
        (d/p).write_bytes(b)


def matrix():
    # Five literal coefficient classes; NH4 sorption and NO3; independent
    # source/stock scales, including exhausted donors and continuing inflow.
    cases = []
    for w0, wt, qout, rate in [(.3,.32,.002,.1), (.3,.32,0.,0.),
                               (.3,.3,.002,.1), (.3,.28,.006,0.), (.3,.3,0.,0.)]:
        for sorption in [0., .0002]:
            for c0 in [0., 1e-6, .002, .2]:
                for production, qbot, cbot in [(0.,0.,0.), (1e-5,.001,.002)]:
                    cases.append([.3,1.,wt,w0,qout,0.,qbot,-.04,0.,0.,rate,production,
                                  sorption,cbot,.005,0.,c0,1300.])
    # Invalid negative production, a positive carrier, dry capacity, NaN.
    for index, value in [(11,-.001), (7,.04), (2,0.), (16,float('nan'))]:
        x = list(cases[0]); x[index] = value; cases.append(x)
    return cases


cases = matrix()
payload = ('\n'.join(' '.join(format(v,'.17e') for v in x) for x in cases)+'\n').encode()
(OUT/'direct-input.txt').write_bytes(payload)
direct = {}
for opt in ['O0', 'O2']:
    b = OUT/('direct-'+opt)
    b.mkdir()
    flags = ['-'+opt, '-ffree-line-length-none', '-fcheck=all', '-ffpe-trap=invalid,zero,overflow']
    # The fixture defines only the original ambient density and error adapter.
    event([*FC,*flags,'-c',HERE/'test_negative.f90','-o',b/'driver.o'], b, 'direct_compile')
    event([*FC,*flags,'-c',OUT/'corrected/wofost_soil_watern.f90','-o',b/'watern.o'], b, 'direct_compile')
    event([*FC,*flags,b/'driver.o',b/'watern.o','-o',b/'test'], b, 'direct_link')
    direct[opt] = event([b/'test'], b, 'direct_native', payload).decode()
    (b/'result.txt').write_text(direct[opt])
assert direct['O0'] == direct['O2'], 'direct optimization drift'

# Independent high-accuracy numerical integration of concentration plus its
# time integral. It calls no original or corrected Fortran analytical formula.
from scipy.integrate import solve_ivp
direct_checks = []
for x, line in zip(cases, direct['O0'].splitlines()):
    code, *r = map(float, line.split())
    if len(direct_checks) >= 160:
        assert code != 0, 'unsupported input accepted'
        direct_checks.append(dict(invalid_rejected=True))
        continue
    assert code == 0
    dz,dt,wt,w0,qout,qr,qb,qt,ql,tcsf,k,prod,K,cb,ct,cl,c0,rho = x
    h = (wt-w0)/dt
    s0 = w0+rho*K
    positive = (qb*cb+ql*cl)/dz+prod
    extraction = -qt*ct/dz
    h1 = h+qout/dz+tcsf*qr/dz+k*.5*(wt+w0)
    def rhs(t,y):
        return [(positive-extraction-h1*y[0])/(s0+h*t), y[0]]
    def zero(t,y):
        return y[0]
    zero.terminal = True
    zero.direction = -1
    if c0 == 0 and positive <= extraction:
        ce = ca = tau = 0.
    else:
        sol = solve_ivp(rhs,[0.,dt],[c0,0.],rtol=2.3e-14,atol=1e-17,events=zero,max_step=.01)
        assert sol.success
        ce = max(0.,sol.y[0,-1]); ca = sol.y[1,-1]/dt; tau = sol.t[-1]
    actual = -dz*(extraction*tau+positive*(dt-tau))/dt
    unmet = dz*(extraction-positive)*(dt-tau)
    ce_f,ca_f,actual_f,unmet_f,tau_f,orig_c,orig_a = r
    error = max(abs(ce_f-ce),abs(ca_f-ca),abs(actual_f-actual),abs(unmet_f-unmet),abs(tau_f-tau))
    assert error < 2e-11, (x,r,[ce,ca,actual,unmet,tau],error)
    before = dz*s0*c0
    after = dz*(wt+rho*K)*ce_f
    sinks = (qout+tcsf*qr+k*.5*(w0+wt)*dz)*ca_f*dt
    residual = before+dz*positive*dt+actual_f*dt-sinks-after
    assert abs(residual) <= 1e-12, (x,residual)
    assert min(ce_f,ca_f,unmet_f) >= 0 and qt*ct <= actual_f <= 0
    assert abs(-qt*ct*dt+actual_f*dt-unmet_f) <= 1e-14
    if unmet_f == 0:
        assert ce_f == orig_c and ca_f == orig_a, 'literal nondepleted drift'
    direct_checks.append(dict(residual=residual,scale=max(before+dz*positive*dt,sinks+after+abs(actual_f*dt),1e-30),
                              oracle_max_error=error,depleted=unmet_f>0))
(OUT/'DIRECT_CHECKS.json').write_text(json.dumps(direct_checks,indent=2)+'\n')

runs = {}
if not args.direct_only:
    old = runpy.run_path(str(ROOT/'integration/audits/verify_nut_original_full.py'),run_name='prior_full_caller')
    files = old['helper']()['capsule'](old['record']()['evidence'])
    prior = json.loads(files['actual/result.json'])
    sys.path.insert(0,str(ROOT/'tools/vq'))
    from b0_source_runner import select_dec_branches
    for opt in ['O0','O2']:
        build = OUT/('build-'+opt)
        event([sys.executable,'-B',ROOT/'tools/performance/build_swap431_perf01.py','--output',build,'--opt',opt],ROOT,'original_build')
        manifest = json.loads((build/'INPUTS.json').read_text())
        flags = manifest['flags']; bs=build/'swobj'; bt=build/'ttobj'
        for p in changed:
            target = build/'selected'/p
            target.write_bytes(select_dec_branches(corrected[p].decode('cp1252')).encode('cp1252'))
            event([*FC,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',bt,'-I',bs,'-c',target,'-o',bs/(Path(p).stem+'.o')],bs,'corrected_compile')
        event([*FC,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',bt,'-I',bs,'-c',build/'selected/swap_main.f90','-o',build/'swap_main.o'],bs,'main_compile')
        exe = build/'swap_corrected'
        event([*FC,*flags,*sorted(bs.glob('*.o')),build/'swap_main.o',bt/'libttutil.a','-o',exe],build,'main_link')
        names = list(old['NAMES'])+['fallow-both-low','fallow-both-high']
        for name in names:
            origin = name if name in old['NAMES'] else 'fallow-no-denitr'
            case = OUT/opt/name; case.mkdir(parents=True)
            prefix = 'actual/'+opt+'/'+origin+'/'
            for p,h in prior['runs'][opt+'/'+origin]['input_sha256'].items():
                raw = files[prefix+p]; assert sha(raw)==h
                (case/p).write_bytes(raw)
            if name.startswith('fallow-both-'):
                snm=case/'nut-main.snm'; s=snm.read_text()
                import re
                for k,v in {'cNH4N_top':.002,'cNH4_t':.04 if name.endswith('high') else 0.,
                            'cNO3_t':.05 if name.endswith('high') else 0.,
                            'RateConNitrif_ref':.2,'RateConDenitr_ref':.25}.items():
                    s,n=re.subn(r'(?m)^'+k+r'\s*=.*$',k+' = '+format(v,'.17e'),s);assert n==1
                snm.write_text(s)
            input_hashes = {p.name:sha(p.read_bytes()) for p in case.iterdir()}
            event([exe,'./swap.swp'],case,'corrected_native',expected=100)
            assert b'simulation succesfully terminated' in (case/'swap.ok').read_bytes()
            assert not (case/'swap.err').read_bytes().strip() if (case/'swap.err').exists() else True
            if name=='original-control-prefix':
                assert old['csvbody']((case/'result_output.csv').read_bytes())==old['csvbody'](files[prefix+'result_output.csv'])
                checks=[]
            else:
                assert old['csvbody']((case/'result_output.csv').read_bytes())==old['csvbody'](files[prefix+'result_output.csv']), 'hydraulic drift'
                import csv
                rows=list(csv.reader((case/'bounded_n_book.csv').read_text().splitlines()))
                assert len(rows)==10 and all(len(r)==len(FIELDS)+1 for r in rows)
                checks=[]
                for row in rows:
                    v=dict(zip(FIELDS,map(float,row[1:])))
                    nh4=v['nh4_old']+v['nh4_sources']+v['nh4_top_actual']+v['mineralisation']-v['nh4_uptake']-v['nh4_out']-v['nitrification']-v['nh4_end']
                    no3=v['no3_old']+v['no3_sources']+v['no3_top_actual']+v['nitrification']-v['no3_uptake']-v['no3_out']-v['denitrification']-v['no3_end']
                    organic=v['organic_old']+v['organic_sources']-v['mineralisation']-v['organic_end']
                    initial=sum(v[k+'_old']for k in ['nh4','no3','organic'])
                    final=sum(v[k+'_end']for k in ['nh4','no3','organic'])
                    external_in=sum(v[k+'_sources']for k in ['nh4','no3','organic'])+sum(max(0.,v[k+'_top_actual'])for k in ['nh4','no3'])
                    external_out=sum(v[k]for k in ['nh4_out','no3_out','denitrification','volatilisation'])+sum(max(0.,-v[k+'_top_actual'])for k in ['nh4','no3'])
                    soil=initial+external_in-external_out-v['nh4_uptake']-v['no3_uptake']-final
                    whole=initial+external_in-external_out-final
                    scale=max(initial+external_in,external_out+final,1e-30)
                    assert max(abs(nh4),abs(no3),abs(organic),abs(whole))<=1e-10, (name,row[0],nh4,no3,organic,whole)
                    assert abs(nh4+no3+organic-soil)<=1e-12
                    assert min(v[k+'_end']for k in ['nh4','no3','organic'])>=0
                    for form in ['nh4','no3']:
                        requested=v[form+'_top_requested']; actual=v[form+'_top_actual']; unmet=v[form+'_unmet']
                        assert actual>=requested-1e-14 and unmet>=0
                        assert abs(actual-requested-unmet)<=1e-13
                    checks.append(dict(date=row[0],nh4_residual=nh4,no3_residual=no3,organic_residual=organic,
                                       whole_residual=whole,relative_residual=abs(whole)/scale,
                                       initial=initial,final=final,external_in=external_in,external_out=external_out,
                                       unmet=v['nh4_unmet']+v['no3_unmet']))
            runs[opt+'/'+name]=dict(input_sha256=input_hashes,checks=checks)
            (OUT/'RUNS.json').write_text(json.dumps(runs,indent=2)+'\n')
    for name in names:
        for filename in ['result_output.csv','result_nut.csv','bounded_n_book.csv']:
            p=OUT/'O0'/name/filename; q=OUT/'O2'/name/filename
            if p.exists():assert old['csvbody'](p.read_bytes())==old['csvbody'](q.read_bytes()), (name,filename,'optimization drift')
        assert runs['O0/'+name]['checks']==runs['O2/'+name]['checks']

result=dict(status='BOUNDED_NEGATIVE_REFERENCE_LOCAL_PASS_NOT_PRODUCTION_ADMITTED',
            execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
            input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [HERE/'run.py',HERE/'apply.py',
              HERE/'negative_boundary.f90',HERE/'test_negative.f90',archive,ROOT/'tools/performance/build_swap431_perf01.py']},
            transform=changed,direct_cases=len(cases),valid_direct_cases=160,
            direct_max_abs_residual=max(abs(r.get('residual',0.))for r in direct_checks),
            direct_max_relative_residual=max(abs(r.get('residual',0.))/r.get('scale',1.)for r in direct_checks),
            direct_max_oracle_error=max(r.get('oracle_max_error',0.)for r in direct_checks),
            native_models=len(runs),native_N_steps=sum(len(r['checks'])for r in runs.values()),
            max_abs_n_residual=max([abs(c['whole_residual'])for r in runs.values()for c in r['checks']]+[0.]),
            max_relative_n_residual=max([c['relative_residual']for r in runs.values()for c in r['checks']]+[0.]),
            production_changed=False,full_capability=False)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
