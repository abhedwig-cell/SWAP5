#!/usr/bin/env python3
"""All sealed B20 inputs through real production, compared with full-source NET01."""
import argparse, gzip, hashlib, importlib.util, json, math, subprocess, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('dependencies',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
    paths={
        'prior':('docs/audits/evidence/PPA_WU05B20_MULTILEVEL_REFERENCE_REPLAY.json.gz','b9722a11a7684247b90cd34e3c38e27337fbd7a9d36e43888f9893ec8bd6b368'),
        'proposal':('docs/audits/evidence/PPA_WU05B20_NET_TRANSFER_PROPOSAL.json.gz','2d09105252d3db72ba416545a7eff992a5ab32397998fb2a4445cf35439bad6d')}
    evidence={}
    for key,(path,identity)in paths.items():
        raw=(ROOT/path).read_bytes();assert sha(raw)==identity;evidence[key]=json.loads(gzip.decompress(raw))
    driver='tests/frost/test_net01_component.f90'
    ordered,_=dep.strict_closure(ROOT,[driver],[])
    inputs={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in ordered}
    flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow']
    result={'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'inputs':inputs,'parent_evidence':paths,'compiler':subprocess.check_output(['gfortran','--version'],text=True),'executions':[]}
    outputs=[]
    try:
        for opt in(0,2):
            build=out/f'o{opt}';build.mkdir();cmd=['gfortran',*flags,f'-O{opt}','-J',str(build),'-I',str(build),*map(str,ordered),'-o',str(build/'test')]
            start=time.perf_counter();c=subprocess.run(cmd,cwd=build,capture_output=True)
            (build/'build.stdout').write_bytes(c.stdout);(build/'build.stderr').write_bytes(c.stderr)
            entry={'opt':opt,'command':cmd,'compile_link_seconds':time.perf_counter()-start,'build_exit':c.returncode}
            result['executions'].append(entry);assert c.returncode==0,c.stderr.decode()
            start=time.perf_counter();p=subprocess.run([str(build/'test')],input=evidence['prior']['inputs'].encode(),capture_output=True,cwd=build)
            entry.update(native_seconds=time.perf_counter()-start,exit=p.returncode,stdout_sha256=sha(p.stdout),executable_sha256=sha((build/'test').read_bytes()))
            (build/'stdout').write_bytes(p.stdout);(build/'stderr').write_bytes(p.stderr)
            assert p.returncode==0,p.stdout.decode()[-1000:]+p.stderr.decode();outputs.append(p.stdout)
        assert outputs[0]==outputs[1]
        rows=outputs[0].decode().splitlines();expected=evidence['proposal']['output'].splitlines()
        assert len(rows)==len(expected)==9216
        max_unit=max_scalar=max_net=0.
        for line,reference,case in zip(rows,expected,evidence['prior']['inputs'].splitlines()):
            x=list(map(float,line.split()));y=list(map(float,reference.split()));c=list(map(float,case.split()))
            assert x[0]==y[0];n=int(c[1]);rates=x[1:4];nodes=x[4:28]
            # Full source prints initial24, final3 scalars, final24 nodes and bottom.
            assert x[-1]==y[-1]
            max_scalar=max(max_scalar,max(abs(v-w)for v,w in zip(rates,y[25:28])))
            for l in range(n):
                max_unit=max(max_unit,max(abs(v-w)/max(abs(rates[l]),1e-10)for v,w in zip(nodes[8*l:8*l+8],y[28+8*l:36+8*l])))
                assert abs(math.fsum(nodes[8*l:8*l+8])-rates[l])<1e-14
            assert max_scalar<1e-14 and max_unit<2e-12,(x[0],max_scalar,max_unit)
            if c[5]<.01:
                retained=[0. if c[4]<z else q for z,q in zip([-3.,-4.7,-6.3],c[7:7+n])]
                if min(retained)<-1e-10 and max(retained)>1e-10:
                    net=abs(x[-1]-math.fsum(nodes)+math.fsum(retained));max_net=max(max_net,net);assert net<1e-14
        result.update(passed=True,cases=9216,optimization_stdout_identity=True,max_unit_rate_difference=max_unit,
                      max_scalar_difference=max_scalar,max_signed_net_residual=max_net,providers=len(ordered)-1)
        print(json.dumps({k:v for k,v in result.items()if k not in('inputs','executions','parent_evidence','compiler')},indent=2))
    finally:
        (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
