"""Check raw native evidence for the bounded wet4 saturation diagnosis."""
import argparse
import csv
import hashlib
import json
from pathlib import Path


def assess(root):
    def js(p): return json.loads((root/p).read_text())
    def lines(p, prefix):
        return [s.split()[1:] for s in (root/p/'stdout').read_text().splitlines() if s.strip().startswith(prefix+' ')]
    def rows(p):
        return [{k:v.strip() for k,v in r.items() if k!='core_cpu_s'} for r in csv.DictReader((root/p/'daily.csv').open())]
    def flux(p):
        return [s for s in (root/p/'stdout').read_text().splitlines() if s.startswith('PERF01_')]
    for p in root.rglob('RESULT.json'):
        r=json.loads(p.read_text())
        if 'raw_sha256' not in r: continue
        assert not r['timed_out'],p
        for name,h in r['raw_sha256'].items():
            assert hashlib.sha256((p.parent/name).read_bytes()).hexdigest()==h,(p,name)
    for label in ('normal','coarse','strict'):
        a,b=Path('runs')/label,Path('original')/label
        assert js(a/'RESULT.json')['completed_days']==34
        assert rows(a)==rows(b) and flux(a)==flux(b),label
    for label in ('normal','coarse'):
        a,b=Path('runs')/label,Path('checked')/label
        assert (root/a/'stdout').read_bytes()==(root/b/'stdout').read_bytes(),label
        assert rows(a)==rows(b)
        states=lines(a,'D4_EXTERNAL_STATE')
        assert len(states)==2 and states[0]==states[1],'rejected interval changed external state'
        assert lines(a,'D4_EXTERNAL_FAILURE')[0][:5]==['34','0','10','2','-1']
    assert (root/'checked/final-recipe/stdout').read_bytes()==(root/'runs/normal/stdout').read_bytes()
    assert (root/'build/final-recipe-O0/weather.999').read_bytes()==(root/'build/O2/weather.999').read_bytes()
    base_driver=(root/'build/O2/driver.f90').read_text()
    retry_driver=(root/'build/retries48/driver.f90').read_text()
    assert retry_driver==base_driver.replace('config%numerical%transaction%max_retries=32',
                                           'config%numerical%transaction%max_retries=48')
    terminal={}
    for label in ('normal','strict','coarse'):
        p=Path('runs')/label
        tx=lines(p,'D4_TRANSACTION')[-1]
        assert tx[2]=='1' and tx[4]=='33','terminal retry exhaustion'
        r=dict(cursor_day=float(tx[0]),seconds_into_day=(float(tx[0])-34)*86400,
               attempts=int(tx[4]),solver_rejections=int(tx[5]),mass_rejections=int(tx[6]),temporal_rejections=int(tx[7]))
        if label!='coarse':
            m=lines(p,'D4_MASS')[-1]
            assert m[7]=='T' and m[9]=='T' and abs(float(m[4]))<=float(m[5]) and float(m[8])>1
            r.update(mass_residual_cm=float(m[4]),mass_tolerance_cm=float(m[5]),normalized_temporal_indicator=float(m[8]),last_step_days=float(lines(p,'D4_TRIAL')[-1][2]))
            assert r['temporal_rejections']>0
        else:
            assert r['solver_rejections']==33 and r['mass_rejections']==r['temporal_rejections']==0
            h=lines(p,'D4_HEADCALC_FAILURE')[-1]
            assert abs(float(h[3]))>float(h[4])
            r.update(final_equation_balance_rate_cm_per_day=float(h[3]),balance_rate_threshold_cm_per_day=float(h[4]),final_heads_cm=list(map(float,lines(p,'D4_FINAL_HEAD')[-1])))
        terminal[label]=r
    controls={}
    for label in ('rain475-normal','rain475-coarse','rain470-normal','rain400-normal','rain0-normal','retries48'):
        p=Path('controls')/label;r=js(p/'RESULT.json')
        controls[label]=dict(status=r['status'],days=r['completed_days'])
        complete=label in ('rain400-normal','rain0-normal')
        assert (r['returncode']==0)==complete and r['completed_days']==(35 if complete else 34)
        if label!='retries48':
            parent=Path('original')/('coarse' if label.endswith('coarse') else 'normal')
            assert rows(p)[:34]==rows(parent),'rain control changed history'
            assert flux(p)[:len(flux(parent))]==flux(parent)
    # Controls alter one rainfall token only, preserving every prior forcing.
    original=(root/'build/O2/weather.999').read_text().splitlines()
    for label,rain in [('rain475','47.5'),('rain470','47.0'),('rain400','40'),('rain0','0')]:
        changed=[]
        for a,b in zip(original,(root/'input'/label/'weather.999').read_text().splitlines(),strict=True):
            if a!=b:
                x,y=a.split(),b.split();assert x[1:4]==['23','2','1999'] and x[9]=='48.4' and y[9]==rain
                assert x[:9]==y[:9] and x[10:]==y[10:];changed.append(x)
        assert len(changed)==1
    tx=lines(Path('controls/retries48'),'D4_TRANSACTION')[-1]
    assert tx[2]=='1' and tx[4]=='49'
    controls['retries48'].update(cursor_day=float(tx[0]),attempts=int(tx[4]),last_step_days=float(lines(Path('controls/retries48'),'D4_TRIAL')[-1][2]))
    good=rows(Path('controls/rain400-normal'))[-1]
    assert abs(float(good['residual_mm']))<1e-10
    assert js('source-selection.json')['source_diff']==''
    preservation=js('preservation.json')
    assert preservation['current_parent_qualification']['status']=='JOINT_OUTPUT_SOURCE_AND_EVIDENCE_PASS'
    return dict(status='BOUNDED_WET4_CAUSAL_DIAGNOSIS_VERIFIED',terminal=terminal,controls=controls,
                exact_original_prefixes=3,exact_O0_O2_full_traces=2,rejected_external_states_exact=2,
                control400_last_day=good,production_changed=False,
                standalone_preexisting_owner_wrapper='BLOCKED_KEYERROR_qualified; unchanged baseline; component source/evidence and successor owner checks pass')


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('evidence',type=Path)
    a=ap.parse_args();print(json.dumps(assess(a.evidence),indent=2))
