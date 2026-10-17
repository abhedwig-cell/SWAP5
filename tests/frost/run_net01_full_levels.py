#!/usr/bin/env python3
"""All B1.11 drainage counts through full native source and real production."""
import argparse, hashlib, importlib.util, itertools, json, math, re, subprocess, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def sha(b):return hashlib.sha256(b).hexdigest()
def fixtures(out):
    original=(ROOT/'tests/frost/test_ppa_wu05b20_multilevel_globals.f90').read_text()
    globals=re.sub(r'\(3(?=[,)])','(25',original).replace('madr=3','madr=25')
    globals=globals.replace('[-3.d0,-4.7d0,-6.3d0]','0.d0').replace('[20.d0,40.d0,60.d0]','1.d0')
    owner=(ROOT/'tests/frost/test_ppa_wu05b20_multilevel_owner.f90').read_text()
    owner=owner.replace('(3)', '(25)').replace('(3,8)', '(25,8)').replace('>3)', '>25)')
    owner=owner.replace('raw,Lspacing,aniso','raw,Lspacing,zbotdr,aniso')
    owner=owner.replace('52(ES26.17E3,1X)', '*(ES26.17E3,1X)').replace('level=1,3','level=1,25')
    production=(ROOT/'tests/frost/test_net01_component.f90').read_text()
    for array in ('raw','spacing','rates'):
        production=production.replace(array+'(3)',array+'(25)')
    production=production.replace('final(3,8)', 'final(25,8)')
    production=production.replace('aniso,factor(8)', 'depth(25),aniso,factor(8)')
    production=production.replace('raw,spacing,aniso','raw,spacing,depth,aniso')
    lo=production.index('      select case(l)');hi=production.index('      p(l)%separate_infiltration',lo)
    production=production[:lo]+'      p(l)%drain_bottom_cm=depth(l)\n'+production[hi:]
    production=production.replace('28(ES26.17E3,1X)', '*(ES26.17E3,1X)').replace('l=1,3','l=1,25')
    production=production.replace('    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta,spread(.5_real64,1,8), &\n         raw(:levels),bottom,b)', '''    if(FROST_DIVDRA_MAX_LEVELS/=25)error stop 'source maximum changed'
    deallocate(bad);allocate(bad(26));q=spread(.001_real64,1,26)
    do k=1,26
      bad(k)=p(1);bad(k)%drain_bottom_cm=-.8_real64-6.4_real64*real(k-1,real64)/25._real64
    end do
    if(valid_multilevel_frost_divdra(bad))error stop '26 parameters accepted'
    call compose_multilevel_signed_frost_divdra(bad,view,factor,node,frost,theta,spread(.5_real64,1,8),q,bottom,r)
    if(r%available.or.allocated(r%final_scalar).or.allocated(r%final_nodal_sink))error stop '26 published'
    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta,spread(.5_real64,1,8), &
         raw(:levels),bottom,b)''')
    # Original 26 invalid and A/B/A controls execute at every count.
    for name,text in [('globals.f90',globals),('owner.f90',owner),('production.f90',production)]:
        (out/name).write_text(text)
    prop=module('proposal','tests/frost/run_ppa_wu05b20_net_transfer_proposal.py')
    frozen=ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90'
    (out/'frozen.f90').write_bytes(prop.proposal_source(frozen.read_bytes())[0])
    subprocess.run(['python',str(ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/apply.py'),
        str(ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90'),str(out/'divdra.f90')],check=True)

def cases():
    rows=[]
    for n,inf,air,frost,gw,kind,space,aniso,bot in itertools.product(
            range(2,26),(0,1),(.005,.02),(-.2,-3.5,-7.2),(-2.25,-5.25),range(4),(0,1),(1.,2.),(-.001,.001)):
        depth=[-(.8+6.4*l/(n-1))for l in range(n)]
        spacing=[20. if space==0 else 10.+2.*l for l in range(n)]
        raw=[.002*(l+1)/n for l in range(n)]
        if kind==1:raw=[q*(-1. if l%2 else 1.)for l,q in enumerate(raw)]
        if kind==2:raw=[0.]*n;raw[0]=.01;raw[-1]=-.01
        if kind==3:raw=[0.]*n
        pad=lambda x:x+[0.]*(25-n)
        rows.append([len(rows)+1,n,inf,gw,frost,air,bot,*pad(raw),*pad(spacing),*pad(depth),aniso])
    return rows

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
    # The proposal helper has a local precision-oracle import.
    import sys;sys.path.insert(0,str(ROOT/'tests/frost'))
    fixtures(out);rows=cases();payload=''.join(' '.join(map(str,r))+'\n'for r in rows).encode()
    (out/'inputs').write_bytes(payload)
    dep=module('dep','tests/support/augment_bartholomeus_backend_sources.py')
    ordered,_=dep.strict_closure(ROOT,['tests/frost/test_net01_component.f90'],[])
    production=[p for p in ordered if p.name!='test_net01_component.f90']+[out/'production.f90']
    reference=[out/p for p in ['globals.f90','divdra.f90','frozen.f90','owner.f90']]
    record={'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'compiler':subprocess.check_output(['gfortran','--version'],text=True),
            'source_sha256':{str(p.relative_to(ROOT)):sha(p.read_bytes())for p in ordered},
            'generated':{p.name:p.read_text()for p in out.glob('*.f90')},'executions':[],
            'inputs_sha256':sha(payload),'cases':len(rows),'counts':list(range(2,26))}
    outputs={};maxima={'unit_nodal':0.,'scalar':0.,'signed_net':0.};policy=0
    try:
        for opt in (0,2):
            for name,files in [('production',production),('reference',reference)]:
                d=out/f'{name}-o{opt}';d.mkdir()
                cmd=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all',
                     '-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),*map(str,files),'-o',str(d/'test')]
                t=time.perf_counter();p=subprocess.run(cmd,cwd=d,capture_output=True)
                entry={'name':name,'opt':opt,'command':cmd,'compile_link_seconds':time.perf_counter()-t,'build_exit':p.returncode}
                record['executions'].append(entry);(d/'build.stdout').write_bytes(p.stdout);(d/'build.stderr').write_bytes(p.stderr)
                assert p.returncode==0,p.stderr.decode()
                t=time.perf_counter();p=subprocess.run([str(d/'test')],input=payload,cwd=d,capture_output=True)
                entry.update(native_seconds=time.perf_counter()-t,exit=p.returncode,stdout_sha256=sha(p.stdout),executable_sha256=sha((d/'test').read_bytes()))
                (d/'stdout').write_bytes(p.stdout);(d/'stderr').write_bytes(p.stderr)
                assert p.returncode==0,p.stdout.decode()[-1000:]+p.stderr.decode()
                outputs[name,opt]=p.stdout
                if name=='production':
                    for n in range(2,26):
                        first=next(r for r in rows if r[1]==n and r[4]==-3.5)
                        q=subprocess.run([str(d/'test'),'contracts'],input=(' '.join(map(str,first))+'\n').encode(),capture_output=True,cwd=d)
                        (d/f'contracts-{n}.stdout').write_bytes(q.stdout);(d/f'contracts-{n}.stderr').write_bytes(q.stderr)
                        assert q.returncode==0 and b'NET01_INVALID_NONMUTATION_ABA_26=PASS'in q.stdout
                    entry['invalid_ABA_per_count']=26
                print(f'FULL_LEVELS_{name}_O{opt}={len(rows)}_PASS',flush=True)
        assert all(outputs[name,0]==outputs[name,2]for name in ('production','reference'))
        actual=outputs['production',0].decode().splitlines();native=outputs['reference',0].decode().splitlines()
        assert len(actual)==len(native)==len(rows)
        for case,x,y in zip(rows,actual,native):
            v=list(map(float,x.split()));w=list(map(float,y.split()));n=case[1]
            assert v[0]==w[0]==case[0] and v[-1]==w[-1]
            rates=v[1:26];nodes=v[26:226];expected_rates=w[201:226];expected_nodes=w[226:426]
            for l in range(n):
                err=abs(rates[l]-expected_rates[l]);maxima['scalar']=max(maxima['scalar'],err)
                unit=max(abs(a-b)/max(abs(rates[l]),1e-10)for a,b in zip(nodes[l*8:l*8+8],expected_nodes[l*8:l*8+8]))
                maxima['unit_nodal']=max(maxima['unit_nodal'],unit)
                assert err<1e-14 and unit<2e-12,(case[0],n,l,err,unit)
                assert abs(math.fsum(nodes[l*8:l*8+8])-rates[l])<1e-14
            if case[5]<.01 and case[4]<-1.5:
                retained=[q if case[4]>=z else 0. for q,z in zip(case[7:7+n],case[57:57+n])]
                if min(retained)<-1e-10 and max(retained)>1e-10:
                    err=abs(v[-1]-math.fsum(nodes)+math.fsum(retained));assert err<1e-14
                    maxima['signed_net']=max(maxima['signed_net'],err);policy+=1
        record.update(passed=True,maxima=maxima,active_net_cases=policy,optimization_identity=True)
        print(json.dumps({k:record[k]for k in ['passed','cases','maxima','active_net_cases']},indent=2))
    finally:(out/'result.json').write_text(json.dumps(record,indent=2)+'\n')
if __name__=='__main__':main()
