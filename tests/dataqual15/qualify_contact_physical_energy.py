"""Actual Andelst linear-contact witness and conservative warm-energy research."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
RESEARCH='tests/dataqual15/research/'
SOURCES=['src/solver/mod_reference_linear_solver.f90','src/process/mod_linear_mixture_sensible_storage.f90',
         RESEARCH+'contact_constraint_driver.f90',RESEARCH+'mod_conservative_soil_heat_trial.f90',
         RESEARCH+'conservative_heat_driver.f90',RESEARCH+'contact_macro_exchange_driver.f90']
MACRO='src/process/macropore/mod_macropore_standard_storage.f90'
PATCH=RESEARCH+'macropore_stock_conservation.patch'


def contact_input():
    capsule=ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz'
    assert hashlib.sha256(capsule.read_bytes()).hexdigest()=='0e0c5a80e4481e98a4e74632a06cbdc813e8514a76508716c4d131f445b470e4'
    with tarfile.open(capsule) as t:
        lines=t.extractfile('run/andelst-richards-linearization.log').read().decode().splitlines()
    header=lines[0].split();assert header[0]=='TRIAL' and float(header[1])==6.008148201175345e-8
    assert int(header[4])==0, 'nonzero low-rank storage must not be silently omitted'
    rows=[list(map(float,l.split())) for l in lines[1:113]]
    assert [int(r[0]) for r in rows]==list(range(1,113))
    # Diagnostic columns: node,h,old_h,theta,old_theta,F,delta,upper,main,lower,...
    jump=.022332123569824055
    out=[f'112 26 27 {float(header[1]):.17g} {jump:.17g}']
    for row in rows:
        out.append(' '.join(format(row[i],'.17g') for i in [1,5,7,8,9]))
    return ('\n'.join(out)+'\n').encode(),rows,jump


def check_contact(stdout,rows,jump):
    import mpmath as mp
    mp.mp.dps=70
    a=mp.matrix(112);rhs=mp.matrix(112,1);force=mp.matrix(112,1)
    for i,row in enumerate(rows):
        a[i,i]=mp.mpf(row[8]);rhs[i]=mp.mpf(row[5])
        if i:a[i,i-1]=mp.mpf(row[7])
        if i<111:a[i,i+1]=mp.mpf(row[9])
    force[25]=mp.mpf(jump);u=mp.lu_solve(a,rhs);v=mp.lu_solve(a,force)
    psi=mp.mpf(rows[25][1])+mp.mpf(rows[26][1])
    fraction=(u[25]+u[26]-psi)/(v[25]+v[26])
    fields=next(l.split(',')[1:] for l in stdout.splitlines() if l.startswith('CONTACT,'))
    values=list(map(float,fields));assert abs(values[0]-float(fraction))<1e-15
    deltas={int(f[1]):float(f[2]) for f in (l.split(',') for l in stdout.splitlines()) if f[0]=='DELTA'}
    assert len(deltas)==112
    expected=u-fraction*v
    assert max(abs(deltas[i+1]-float(expected[i])) for i in range(112))<2e-18
    assert 0<float(fraction)<1 and psi-u[25]-u[26]<0 and psi-u[25]-u[26]+v[25]+v[26]>0
    return dict(contact_fraction=values[0],exchange_rate_cm_day=values[1],exchange_amount_cm=values[2],
                linear_residual=values[3],contact_residual=values[4],independent_precision_digits=70,
                nonlinear_accepted_step=False,full_original_complete=False)


def case_input(scenario):
    dz=[1.,2.,3.];theta=[.2,.25,.3];old=[10.,10.,10.]
    water=[.01,.008,.006,.004];roots=[.001,.002,.001];source=[0.,.003,0.]
    if scenario==4:water=[-x for x in water]
    gas=[-x for x in water];gas_source=[r-s for r,s in zip(roots,source)]
    if scenario==2:
        water=gas=[0.]*4;source=[0.]*3;gas_source=roots[:]
    if scenario==5:
        water=gas=[0.]*4;source=gas_source=roots=[0.]*3;old=[5.,10.,20.]
    end=[x+(water[i]-water[i+1]+source[i]-roots[i])/dz[i] for i,x in enumerate(theta)]
    wt=[10.,10.];gt=[10.,10.];ws=gs=[10.]*3;heat=[0.,0.]
    if scenario in (3,4):wt=[20.,30.];gt=[8.,7.];ws=[12.,15.,18.];gs=[6.,7.,8.];heat=[.1,-.03]
    return dz,theta,end,old,water,gas,roots,source,gas_source,wt,gt,ws,gs,heat


def check_heat(raw):
    cases={};temp={};faces={};refusals=[]
    for line in raw.decode().splitlines():
        f=line.split(',')
        if f[0]=='CASE':cases[int(f[1]),int(f[2])]=list(map(float,f[3:]))
        if f[0]=='TEMP':temp[tuple(map(int,f[1:4]))]=float(f[4])
        if f[0]=='FACE':faces[tuple(map(int,f[1:4]))]=list(map(float,f[4:]))
        if f[0]=='REFUSAL':refusals.append(int(f[1]))
    assert len(cases)==10 and len(temp)==30 and len(faces)==40
    assert refusals==[4,4,4,4,4,5,2,3,6,6,6]
    max_local=max_global=0.
    for (scenario,gauge),values in cases.items():
        dz,t0,t1,old,w,g,roots,ws,gs,wt,gt,wst,gst,heat=case_input(scenario)
        temperature=[temp[scenario,gauge,i+1] for i in range(3)];reference=5.*gauge
        c=lambda theta:1.2+4.18*theta+.001212*(.45-theta)
        stocks=[dz[i]*(c(t1[i])*(temperature[i]-reference)-c(t0[i])*(old[i]-reference)) for i in range(3)]
        def face_energy(q,cap,donor):
            result=[]
            for i,volume in enumerate(q):
                if not volume:result.append(0.);continue
                if i==0:t=donor[0] if volume>0 else temperature[0]
                elif i==3:t=temperature[2] if volume>0 else donor[1]
                else:t=temperature[i-1] if volume>0 else temperature[i]
                result.append(cap*volume*(t-reference))
            return result
        ew=face_energy(w,4.18,wt);eg=face_energy(g,.001212,gt)
        sw=[4.18*ws[i]*((wst[i] if ws[i]>0 else temperature[i])-reference) for i in range(3)]
        sg=[.001212*gs[i]*((gst[i] if gs[i]>0 else temperature[i])-reference) for i in range(3)]
        root=[4.18*roots[i]*(temperature[i]-reference) for i in range(3)]
        conduction=[.4*(temperature[0]-temperature[1]),.2*(temperature[1]-temperature[2])]
        for i in range(3):
            into=ew[i]-ew[i+1]+eg[i]-eg[i+1]+sw[i]+sg[i]-root[i]
            if i==0:into+=heat[0]
            if i==2:into+=heat[1]
            if i:into+=conduction[i-1]
            if i<2:into-=conduction[i]
            max_local=max(max_local,abs(stocks[i]-into))
            assert abs(stocks[i]-into)<5e-14,(scenario,gauge,i,stocks[i]-into)
        net=sum(heat)+ew[0]-ew[-1]+eg[0]-eg[-1]+sum(sw)+sum(sg)-sum(root)
        max_global=max(max_global,abs(sum(stocks)-net))
        expected=[sum(stocks),net,sum(stocks)-net,sum(root),sum(sw),sum(sg)]
        assert max(abs(a-b) for a,b in zip(expected,values))<5e-14
        for i in range(4):assert max(abs(a-b) for a,b in zip(faces[scenario,gauge,i+1],[ew[i],eg[i]]))<1e-15
        if gauge:assert max(abs(temp[scenario,0,i]-temp[scenario,1,i]) for i in range(1,4))<3e-14
    assert abs(cases[1,0][0]-.2089394)<5e-14
    assert abs(cases[2,0][0]+.16715152)<5e-14
    return dict(cases=10,refusals=len(refusals),max_nodal_energy_residual_j_cm2=max_local,
                max_column_energy_residual_j_cm2=max_global,explicit_isothermal_storage_gain_j_cm2=cases[1,0][0],
                root_extraction_storage_change_j_cm2=cases[2,0][0],full_swap_energy_balance=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    out=p.parse_args().output.resolve();out.mkdir(parents=True,exist_ok=False)
    assert not subprocess.check_output(['git','diff','HEAD','--',*SOURCES],cwd=ROOT), 'persist first'
    raw,rows,jump=contact_input();(out/'contact.dat').write_bytes(raw)
    compiler=shutil.which('gfortran');assert compiler
    spec=importlib.util.spec_from_file_location('closure',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
    closure=importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)
    macro_sources,_=closure.strict_closure(ROOT,[ROOT/SOURCES[5]])
    fixture=out/'macro-candidate';target=fixture/MACRO;target.parent.mkdir(parents=True)
    target.write_bytes((ROOT/MACRO).read_bytes().replace(b'\r\n',b'\n'))
    local_patch=out/'macro.patch';local_patch.write_bytes((ROOT/PATCH).read_bytes().replace(b'\r\n',b'\n'))
    subprocess.run(['git','init','-q',str(fixture)],check=True)
    subprocess.run(['git','-c','core.autocrlf=false','apply','--check',str(local_patch)],cwd=fixture,check=True)
    subprocess.run(['git','-c','core.autocrlf=false','apply',str(local_patch)],cwd=fixture,check=True)
    dependencies=list(dict.fromkeys([*SOURCES,*[p.relative_to(ROOT).as_posix() for p in macro_sources],PATCH,
        'tests/dataqual15/qualify_contact_physical_energy.py','tests/support/augment_bartholomeus_backend_sources.py']))
    assert not subprocess.check_output(['git','diff','HEAD','--',*dependencies],cwd=ROOT)
    report=dict(scope='RESEARCH_CONTACT_LINEARIZATION_AND_WARM_SENSIBLE_TRANSPORT_ONLY',
        measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        source_git_blob={s:subprocess.check_output(['git','rev-parse','HEAD:'+s],cwd=ROOT,text=True).strip() for s in dependencies},
        compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
        full_energy_balance_complete=False,nonlinear_contact_repair=False,builds={})
    for opt in ('O0','O2'):
        d=out/opt;d.mkdir()
        events={}
        for name,files in [('contact',[SOURCES[0],SOURCES[2]]),('heat',[SOURCES[0],SOURCES[1],SOURCES[3],SOURCES[4]])]:
            exe=d/(name+'.exe');command=[compiler,'-'+opt,'-g','-fcheck=all','-ffree-line-length-none',
                '-ffpe-trap=invalid,zero,overflow','-J'+str(d),'-I'+str(d),*[str(ROOT/f) for f in files],'-o',str(exe)]
            cp=subprocess.run(command,cwd=d,capture_output=True,text=True,timeout=90)
            assert cp.returncode==0,cp.stderr
            dest=out/'contact.dat' if name=='contact' else d/'heat.csv'
            cp=subprocess.run([str(exe),str(dest)],cwd=d,capture_output=True,text=True,timeout=30)
            (d/(name+'.stdout')).write_text(cp.stdout,encoding='utf-8');(d/(name+'.stderr')).write_text(cp.stderr,encoding='utf-8')
            assert cp.returncode==0,(name,cp.stdout,cp.stderr)
            result=check_contact(cp.stdout,rows,jump) if name=='contact' else check_heat(dest.read_bytes())
            events[name]=dict(command=command,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),**result)
        transfer=events['contact']['exchange_amount_cm'];macro={}
        for variant in ('production','candidate'):
            folder=d/('macro-'+variant);folder.mkdir();exe=folder/'exchange.exe'
            selected=[target if variant=='candidate' and p==ROOT/MACRO else p for p in macro_sources]
            command=[compiler,'-'+opt,'-fcheck=all','-ffree-line-length-none',
                '-J'+str(folder),'-I'+str(folder),*map(str,selected),'-o',str(exe)]
            cp=subprocess.run(command,cwd=folder,capture_output=True,text=True,timeout=90)
            assert cp.returncode==0,cp.stderr
            cp=subprocess.run([str(exe),format(transfer,'.17g')],cwd=folder,capture_output=True,text=True,timeout=30)
            (folder/'stdout').write_text(cp.stdout,encoding='utf-8');(folder/'stderr').write_text(cp.stderr,encoding='utf-8')
            assert cp.returncode==0,cp.stderr
            values=list(map(float,cp.stdout.strip().split(',')[1:]))
            assert len(values)==4 and values[0]==transfer
            if variant=='production':assert values[3]>transfer/2, 'old quantization failure not observed'
            else:assert abs(values[3])<64*2.220446049250313e-16*.1
            macro[variant]=dict(command=command,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                transfer_cm=transfer,stock_before_view_cm=values[1],stock_after_view_cm=values[2],
                combined_matrix_macro_water_residual_cm=values[3])
        events['macro_exchange']=macro
        report['builds'][opt]=events
    assert (out/'O0/contact.stdout').read_bytes()==(out/'O2/contact.stdout').read_bytes()
    assert (out/'O0/heat.csv').read_bytes()==(out/'O2/heat.csv').read_bytes()
    for variant in ('production','candidate'):
        assert (out/('O0/macro-'+variant)/'stdout').read_bytes()==(out/('O2/macro-'+variant)/'stdout').read_bytes()
    report['status']='BOUNDED_CONTACT_AND_CONSERVATIVE_HEAT_RESEARCH_PASS'
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
