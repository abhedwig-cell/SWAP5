#!/usr/bin/env python3
"""Original B18 assertions, complete original B17 corpus, immutable B20 evidence."""
import argparse, gzip, hashlib, json, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
    status=json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_STATUS.json').read_text())
    data=(ROOT/status['evidence']['path']).read_bytes();assert sha(data)==status['evidence']['sha256']
    old=json.loads(gzip.decompress(data));payload=old['manifest']['actual/cases.txt']['content'].encode()
    expected=old['manifest']['actual/corrected/o0/output.txt']['content'].splitlines()
    common=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',
            'src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90',
            'tests/frost/test_ppa_wu05b16_divdra_globals.f90',
            'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90',
            'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90',
            'tests/frost/test_ppa_wu05b18_divdra_component.f90']
    record={'source_sha256':{p:sha((ROOT/p).read_bytes())for p in common},'executions':[]}
    outputs=[]
    try:
        for opt in(0,2):
            build=out/f'o{opt}';build.mkdir()
            cmd=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',
                 f'-O{opt}','-J',str(build),'-I',str(build),*[str(ROOT/p)for p in common],'-o',str(build/'test')]
            start=time.perf_counter();cp=subprocess.run(cmd,capture_output=True,cwd=build)
            (build/'build.stdout').write_bytes(cp.stdout);(build/'build.stderr').write_bytes(cp.stderr)
            e={'optimization':opt,'command':cmd,'compile_link_seconds':time.perf_counter()-start,'compile_exit':cp.returncode}
            record['executions'].append(e);assert cp.returncode==0,cp.stderr.decode()
            start=time.perf_counter();cp=subprocess.run([str(build/'test')],input=payload,capture_output=True,cwd=build)
            e.update(native_seconds=time.perf_counter()-start,exit=cp.returncode,stdout_sha256=sha(cp.stdout),executable_sha256=sha((build/'test').read_bytes()))
            (build/'stdout').write_bytes(cp.stdout);(build/'stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode()
            outputs.append(cp.stdout);rows=cp.stdout.decode().splitlines()
            assert rows[-2:]==['B18_INVALID_DOMAIN_UNAVAILABLE_CASES=32','B18_ACTUAL_REFERENCE_BOUNDARY_AND_BEYOND_OFFSET_CASES=2']
            accepted=held=0
            for case,actual,reference in zip(payload.decode().splitlines(),rows[:-2],expected):
                c=list(map(float,case.split()));t=list(map(float,actual.split()));r=list(map(float,reference.split()))
                assert c[0]==t[0]==r[0]
                if 0.<abs(c[5])<=1e-10:
                    assert t[1]==2 and t[2]==0 and t[3:13]==[0.]*10;held+=1
                else:
                    assert t[1]==0 and t[2]==1 and t[12]==r[19]
                    assert abs(t[3]-r[10])<1e-14
                    assert max(abs(x-y)for x,y in zip(t[4:12],r[11:19]))<1e-14
                    assert abs(sum(t[4:12])-t[3])<1e-14;accepted+=1
            assert len(rows)==4538 and accepted==3240 and held==1296
        assert outputs[0]==outputs[1]
        record.update(passed=True,cases=4536,accepted=3240,held=1296,invalid=32,boundary=2)
        print('NET01_ORIGINAL_B18_COMPLETE_O0_O2=PASS')
    finally:(out/'result.json').write_text(json.dumps(record,indent=2)+'\n')
if __name__=='__main__':main()
