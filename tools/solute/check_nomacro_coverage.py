"""Actual source-bound experimental input/process qualification, O0/O2.

No tolerance changes and no promotion of inherited scientific FAILs.
Run on a dedicated hosted runner; every output is owned by this work unit.
"""
import argparse
import contextlib
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import struct
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import CoupledDailyColumn, validate_bundle
from prepare_saltfarm import prepare as saltfarm


def physical(row):
    return {k: v for k, v in row.items() if k not in ('column', 'revision')}


def rows(directory):
    return [json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines()]


def payload(path):
    with zipfile.ZipFile(path) as z:
        return {name: z.read(name) for name in ('result.end', 'macro.bin')}


def management_end(aux,project):
    selected=e.inspect(project.input_directory)['selectors']
    count=(5*project.nodes+4 if selected['SWHYST'] else 0)+(2*project.nodes+2 if selected['SWSNOW'] else 0)
    return len(aux)-8*count


def native_temperatures(checkpoint,project):
    # Read the original GNU sequential native prefix by its actual record
    # boundaries, in the documented read_ini order. Full endpoint equality
    # below still compares every native byte, not only these diagnostics.
    with zipfile.ZipFile(checkpoint) as z:raw=z.read('result.end')
    records=[];offset=0
    while offset<len(raw):
        size=struct.unpack_from('=i',raw,offset)[0]
        assert size>=0 and offset+size+8<=len(raw)
        assert struct.unpack_from('=i',raw,offset+size+4)[0]==size
        records.append(raw[offset+4:offset+size+4]);offset+=size+8
    integer=lambda i:struct.unpack('=i',records[i])[0]
    cursor=3 if integer(0)==2 else 2
    assert integer(1)==0 and integer(cursor)==project.nodes
    cursor+=3 # NUMNOD, H, POND
    snow=integer(cursor);cursor+=1+2*snow
    reduction=integer(cursor);cursor+=1+(1 if reduction==1 else 2)
    hysteresis=integer(cursor);cursor+=1+4*int(hysteresis>0)
    assert integer(cursor)==1
    values=struct.unpack('='+str(project.nodes)+'d',records[cursor+1])
    assert all(math.isfinite(v) and -50<=v<=80 for v in values)
    return list(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    group=parser.add_mutually_exclusive_group()
    group.add_argument('--extended', action='store_true', help='Snow/hysteresis and sorption/decomposition block')
    group.add_argument('--basic-options', action='store_true', help='Original no-crop/no-heat and prescribed bottom fluxes')
    group.add_argument('--crop-options', action='store_true', help='Water-only crop/management and independent root/interception controls')
    group.add_argument('--process-options',action='store_true',help='Original thermal boundaries/analytic heat and canopy/root families')
    group.add_argument('--hydraulic-options',action='store_true',help='Original hydraulic tables, geometric/harmonic means and Darcy evaporation')
    args = parser.parse_args()
    extra = args.extended or args.basic_options or args.crop_options or args.process_options or args.hydraulic_options
    active_options = args.crop_options or args.process_options or args.hydraulic_options
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    reference = out/'provider'
    events, reports = [], []

    def call(label, arguments, *, refuse=False, absent=None, timeout=300):
        cmd = [sys.executable, '-B', str(ROOT/'tools/solute/run_water.py'), *map(str, arguments)]
        start = time.monotonic()
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        (out/(label+'.log')).write_text(proc.stdout+proc.stderr)
        events.append(dict(label=label, command=cmd, seconds=time.monotonic()-start,
                           returncode=proc.returncode, expected_refusal=refuse))
        (out/'EVENTS.json').write_text(json.dumps(events, indent=2)+'\n')
        assert (proc.returncode != 0) == refuse, (label, proc.stdout, proc.stderr)
        if absent is not None:
            assert not absent.exists(), label+' wrote output before refusal'
        print(label, 'REFUSED' if refuse else 'PASS', round(events[-1]['seconds'], 2), flush=True)

    call('prepare', ['--no-macro-release', '--prepare-sources', '--reference-work', reference])
    cases = {}
    for key, run_id in ([] if extra else [('salt08', 2), ('salt16', 3)]):
        case = out/('input-'+key)
        saltfarm(case, run_id)
        cases[key] = case
    for key, name, value in ([] if extra else [('hupsel-free', 'SWBOTB', 7), ('hupsel-nodrain', 'SWDRA', 0)]):
        case = out/('input-'+key)
        shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook', case)
        path = case/'swap.swp'
        text, count = re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',
                              lambda m: m[1]+str(value), path.read_text(encoding='cp1252'))
        assert count == 1
        path.write_text(text, encoding='cp1252')
        cases[key] = case

    if args.extended:
        for key, switches in [('hupsel-hyst1', {'SWHYST':1}), ('hupsel-hyst2', {'SWHYST':2}),
                              ('hupsel-snow', {'SWSNOW':1}), ('hupsel-snow-hyst', {'SWSNOW':1,'SWHYST':1}),
                              ('salt-adsorption', {'SWSP':1}),
                              ('salt-decay', {'SWDC':1}), ('salt-reactions', {'SWSP':1,'SWDC':1})]:
            case = out/('input-'+key)
            if key.startswith('salt'):
                saltfarm(case, 2)
            else:
                shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook', case)
            path = case/'swap.swp';text=path.read_text(encoding='cp1252')
            for name,value in switches.items():
                text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text)
                assert count==1
            if switches.get('SWSP'):
                text+='\nFREXP = 0.9\nCREF = 1.0\nKF = 0.0001389 0.0001378\n'
            if switches.get('SWDC'):
                text+='\nGAMPAR = 0.0\nRTHETA = 0.3\nBEXP = 0.7\nDECPOT = 0.001 0.001\nFDEPTH = 1.0 0.65\n'
            path.write_text(text,encoding='cp1252');cases[key]=case
    if args.basic_options:
        for key, changes in [('bare',{'SWCROP':0,'SWBOTB':7}), ('noheat',{'SWHEA':0,'SWCROP':0,'SWBOTB':7}),
                             ('noheat-maize',{'SWHEA':0}),
                             ('undrained-free',{'SWDRA':0,'SWBOTB':7}),
                             ('prescribed-bottom',{'SWBOTB':2}), ('sine-bottom',{'SWBOTB':2,'SW2':1}),
                             ('head-flux-bottom',{'SWBOTB':4})]:
            case=out/('input-'+key);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',case)
            path=case/'swap.swp';text=path.read_text(encoding='cp1252')
            for name,value in changes.items():
                text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text)
                assert count==1
            if key=='prescribed-bottom':
                text,count=re.subn(r'(?m)^([ \t]*DATE2[ \t]+QBOT2[^\n]*\n)(?:[ \t]*\d{4}-\d{2}-\d{2}[^\n]*\n)+',
                                   r'\g<1> 2002-01-01 -0.05\n 2003-01-01 -0.10\n 2004-12-31 -0.075\n',text)
                assert count==1
            if key=='sine-bottom':
                for name,value in [('SINAVE',-0.05),('SINAMP',0.02)]:
                    text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)[^\s!]+',lambda m:m[1]+str(value),text)
                    assert count==1
            if key=='noheat-maize':
                text,count=re.subn(r"(?m)^([ \t]*\d{4}-\d{2}-\d{2}[ \t]+\d{4}-\d{2}-\d{2}[ \t]+)'[^']+'[ \t]+[12][ \t]*$",
                                   r"\1'maize' 1",text)
                assert count==3
            path.write_text(text,encoding='cp1252');cases[key]=case
        invalid=out/'invalid-noheat-oxygen'
        shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',invalid)
        path=invalid/'swap.swp';path.write_text(path.read_text(encoding='cp1252').replace('SWHEA = 1','SWHEA = 0'),encoding='cp1252')
        target=out/'refused-noheat-oxygen'
        call('future-oxygen-heat-refusal',['--model',e.MODEL,'--experimental-project',invalid,'--reference-work',reference,
                                         '--build-only','--output',target],refuse=True,absent=target)
    if args.crop_options:
        specs=[('water-hupsel',False,{'SWSOLU':0},{'SWSALINITY':0}),
               ('water-salt',True,{'SWSOLU':0},{'SWSALINITY':0}),
               ('no-interception',False,{}, {'SWINTER':0}),
               ('no-oxygen',False,{}, {'SWOXYGEN':0,'SWWRTNONOX':0}),
               ('no-salt-stress',True,{}, {'SWSALINITY':0}),
               ('no-compensation',False,{}, {'SWCOMPENSATE':0})]
        for key,salt,main_options,crop_options in specs:
            case=out/('input-'+key)
            if salt:saltfarm(case,2)
            else:shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',case)
            for path,options in [(case/'swap.swp',main_options)]+[(p,crop_options) for p in case.glob('*.crp')]:
                text=path.read_text(encoding='cp1252')
                for name,value in options.items():
                    text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text)
                    assert count==1
                path.write_text(text,encoding='cp1252')
            if key=='water-salt':
                # This derived no-chemistry input must explicitly change its
                # text native-initialization tag as well as its SWP selector.
                path=case/'swap.ini'
                text,count=re.subn(r'(?m)^([ \t]*SWSOLU[ \t]*=[ \t]*)1',r'\g<1>0',path.read_text(encoding='cp1252'))
                assert count==1
                path.write_text(text,encoding='cp1252')
            cases[key]=case

        control=cases['water-hupsel']/'potato.crp';saved=control.read_bytes()
        target=out/'refused-water-only-salinity'
        try:
            control.write_bytes(saved.replace(b'SWSALINITY = 0',b'SWSALINITY = 1'))
            call('future-salinity-without-transport-refusal',['--model',e.MODEL,'--experimental-project',cases['water-hupsel'],
                 '--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
        finally:control.write_bytes(saved)

        control=cases['water-hupsel']/'swap.swp';saved=control.read_bytes()
        for selector in ('SWHYST','SWSNOW'):
            target=out/('refused-water-only-'+selector.lower())
            try:
                changed,count=re.subn(rb'(?m)^([ \t]*'+selector.encode()+rb'[ \t]*=[ \t]*)0',rb'\g<1>1',saved)
                assert count==1
                control.write_bytes(changed)
                call('water-only-history-refusal-'+selector,['--model',e.MODEL,'--experimental-project',cases['water-hupsel'],
                     '--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
            finally:control.write_bytes(saved)

    if args.process_options:
        specs=[('analytic-heat',{'SWCALT':1},{'SWOXYGEN':0,'SWWRTNONOX':0}),
               ('bottom-temperature',{'SWBOTBHEA':2},{}),
               ('top-temperature',{'SWTOPBHEA':2},{}),
               ('top-heat-flux',{'SWTOPBHEA':3},{}),
               ('top-mixed',{'SWTOPBHEA':4},{}),
               ('gash-interception',{}, {'SWINTER':2}),
               ('feddes-oxygen',{}, {'SWOXYGEN':1}),
               ('drought-potential',{}, {'SWDROUGHT':2,'SWCOMPENSATE':0}),
               ('walsum-compensation',{}, {'SWCOMPENSATE':2,'SWDROUGHT':1})]
        for key,main_options,crop_options in specs:
            case=out/('input-'+key);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',case)
            for path,options in [(case/'swap.swp',main_options)]+[(p,crop_options) for p in case.glob('*.crp')]:
                text=path.read_text(encoding='cp1252')
                for name,value in options.items():
                    text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text)
                    assert count==1
                path.write_text(text,encoding='cp1252')
            if key=='drought-potential':
                # Original dormant iMicro2 defaults have xylem >= root radius.
                # Use the original reader's explicit example for this derived
                # geometry; preserve its constraints and original physical law.
                for path in case.glob('*.crp'):
                    text=path.read_text(encoding='cp1252')
                    radius=float(e.one(text,'ROOTRADIUS',r'[0-9.]+'))
                    text,count=re.subn(r'(?m)^([ \t]*ROOTXYLEM[ \t]*=[ \t]*)[^\s!]+',lambda m:m[1]+repr(0.4*radius),text)
                    assert count==1;path.write_text(text,encoding='cp1252')
            if key=='gash-interception':
                path=case/'swap.swp';text=path.read_text(encoding='cp1252')
                text,count=re.subn(r"(?m)^([ \t]*\d{4}-\d{2}-\d{2}[ \t]+\d{4}-\d{2}-\d{2}[ \t]+)'[^']+'[ \t]+[12][ \t]*$",r"\1'maize' 1",text)
                assert count==3;path.write_text(text,encoding='cp1252')
            if key=='bottom-temperature':
                path=case/'swap.swp';text=path.read_text(encoding='cp1252')
                text,count=re.subn(r'(?m)^([ \t]*DATET[ \t]+TBOT[^\n]*\n)(?:[ \t]*\d{4}-\d{2}-\d{2}[^\n]*\n)+',
                                   r'\g<1> 2002-01-01 10.0\n 2003-06-30 15.0\n 2004-12-31 8.0\n',text)
                assert count==1;path.write_text(text,encoding='cp1252')
            if main_options.get('SWTOPBHEA') in (2,4):
                (case/'swap.tss').write_text('DATET TTOP\n2002-01-01 5.0\n2003-06-30 22.0\n2004-12-31 7.0\n')
            if main_options.get('SWTOPBHEA') in (3,4):
                path=case/'swap.swp';path.write_text(path.read_text(encoding='cp1252')+"\nTGSOILFILE = 'swap'\n",encoding='cp1252')
                (case/'swap.tgs').write_text('GC = 1.0\nDATET TGTOP\n2002-01-01 0.25\n2003-06-30 -0.25\n2004-12-31 0.25\n')
            cases[key]=case
        # Future crop physical oxygen cannot be smuggled into analytical heat.
        control=cases['analytic-heat']/'potato.crp';saved=control.read_bytes()
        target=out/'refused-analytic-physical-oxygen'
        try:
            control.write_bytes(saved.replace(b'SWOXYGEN = 0',b'SWOXYGEN = 2'))
            call('analytic-physical-oxygen-refusal',['--model',e.MODEL,'--experimental-project',cases['analytic-heat'],
                 '--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
        finally:control.write_bytes(saved)
        control=cases['gash-interception']/'swap.swp';saved=control.read_bytes()
        target=out/'refused-gash-future-wofost'
        try:
            text,count=re.subn(rb"(?m)^( *2003-\d{2}-\d{2} +\d{4}-\d{2}-\d{2} +)'maize' 1",rb"\1'potato' 2",saved)
            assert count==1;control.write_bytes(text)
            call('gash-future-wofost-refusal',['--model',e.MODEL,'--experimental-project',cases['gash-interception'],
                 '--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
        finally:control.write_bytes(saved)
        control=cases['drought-potential']/'potato.crp';saved=control.read_bytes()
        target=out/'refused-microscopic-compensation'
        try:
            control.write_bytes(saved.replace(b'SWCOMPENSATE = 0',b'SWCOMPENSATE = 1'))
            call('microscopic-compensation-refusal',['--model',e.MODEL,'--experimental-project',cases['drought-potential'],
                 '--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
        finally:control.write_bytes(saved)

    if args.hydraulic_options:
        specs=[('soil-tables',{'SWSOPHY':1}),('water-soil-tables',{'SWSOPHY':1,'SWSOLU':0}),
               ('geometric-mean',{'SWKMEAN':3}),('weighted-geometric-mean',{'SWKMEAN':4}),
               ('harmonic-mean',{'SWKMEAN':5}),('weighted-harmonic-mean',{'SWKMEAN':6}),
               ('darcy-evaporation',{'SWREDU':0})]
        for key,changes in specs:
            case=out/('input-'+key);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',case)
            path=case/'swap.swp';text=path.read_text(encoding='cp1252')
            for name,value in changes.items():
                text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert count==1
            path.write_text(text,encoding='cp1252')
            if not changes.get('SWSOLU',1):
                for path in case.glob('*.crp'):
                    text,count=re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)1',r'\g<1>0',path.read_text(encoding='cp1252'));assert count==1
                    path.write_text(text,encoding='cp1252')
            if changes.get('SWSOPHY'):
                # Explicit independent physical data, not a reimplementation
                # of MvG. The unchanged original reader/interpolator owns it.
                heads=[-1e6,-1e5,-1e4,-1000.,-300.,-100.,-30.,-10.,-1.,0.]
                tables=[('topsoil_sand_b2.csv',[.025,.028,.07,.128,.20,.30,.38,.42,.433,.433878],
                         [1e-14,1e-12,1e-9,1e-6,.0001,.01,.5,5.,40.,83.]),
                        ('subsoil_sand_o2.csv',[.025,.03,.05,.11,.18,.26,.34,.375,.386,.387064],
                         [1e-14,1e-12,1e-9,1e-6,.0001,.005,.05,.4,10.,22.])]
                for name,theta,conductivity in tables:
                    (case/name).write_text('HEADTAB THETATAB CONDUCTAB\n'+''.join(f'{head!r} {water!r} {cond!r}\n' for head,water,cond in zip(heads,theta,conductivity,strict=True)))
            cases[key]=case
        for name,value in [('SWKMEAN',7),('SWKMEAN',8),('SWREDU',3)]:
            control=cases['soil-tables']/'swap.swp';saved=control.read_bytes();target=out/('refused-'+name+'-'+str(value))
            try:
                text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),saved.decode('cp1252'));assert count==1
                control.write_text(text,encoding='cp1252')
                call('unsupported-'+name+'-'+str(value),['--model',e.MODEL,'--experimental-project',control.parent,'--reference-work',reference,'--build-only','--output',target],refuse=True,absent=target)
            finally:control.write_bytes(saved)

    for key, case in cases.items():
        project = e.load(case)
        full_rows = None
        for opt in ('O0', 'O2'):
            label = key+'-'+opt
            bundle = out/(label+'-build')
            base = ['--model', e.MODEL, '--experimental-project', case, '--reference-work', reference]
            generated_opt=opt if active_options else 'O2'
            call(label+'-build', base+['--build-only', '--output', bundle, '--kernel-opt', opt]+(['--donor-opt',generated_opt] if active_options else []))
            reuse = base+['--build-bundle', bundle, '--timeout-seconds', 180]
            partial = key == 'hupsel-nodrain' and opt == 'O2'
            failure_day = 212 if project.time_step_policy=='configured-dtmax-daily-v1' else 51
            cut, end = (2, 5) if opt == 'O0' else ((failure_day-2, project.last_day) if partial else (365, project.last_day))
            control, resumed, endpoint = [out/(label+'-'+n) for n in ('control', 'resumed', 'endpoint')]
            call(label+'-control', reuse+['--output', control, '--days', end, '--checkpoint-at', cut], refuse=partial)
            data = rows(control)
            if partial:
                assert len(data) == failure_day and data[-1]['day'] == failure_day and not data[-1]['committed']
                assert 1e-10 < abs(data[-1]['independent_residual_cm']) < 1.01e-10
            else:
                assert len(data) == end and all(r['committed'] for r in data)
            accepted = [r for r in data if r['committed']]
            if args.extended and opt=='O2':
                if key in ('hupsel-snow','hupsel-snow-hyst'):assert max(r['stock_end_cm'][2] for r in accepted)>0
                if key in ('salt-decay','salt-reactions'):
                    assert sum(r['solute_ledger_mg_cm2'][6] for r in accepted)>0
            assert all(abs(r['independent_residual_cm']) <= 1e-10 and abs(r['kernel_residual_cm']) <= 1e-10
                       and abs(r.get('solute_independent_residual_mg_cm2', 0)) <= 1e-10 for r in accepted)
            origin = control/f'accepted-column-1-day-{cut}.zip'
            before = h.sha(origin)
            call(label+'-resumed', reuse+['--output', resumed, '--days', cut+2, '--checkpoint-at', cut+2,
                                        '--restart', origin, '--restart-day', cut], refuse=partial)
            # Fresh cold control through the same endpoint is needed to compare
            # complete native bytes, including output counters, not just stocks.
            call(label+'-endpoint', reuse+['--output', endpoint, '--days', cut+2, '--checkpoint-at', cut+2], refuse=partial)
            assert list(map(physical, rows(resumed))) == list(map(physical, data[cut:cut+2]))
            if partial:
                assert not (resumed/f'accepted-column-1-day-{cut+2}.zip').exists()
                assert not (endpoint/f'accepted-column-1-day-{cut+2}.zip').exists()
                assert rows(resumed)[-1]['revision'] == 1
            else:
                assert payload(resumed/f'accepted-column-1-day-{cut+2}.zip') == payload(endpoint/f'accepted-column-1-day-{cut+2}.zip')
            assert h.sha(origin) == before
            report = dict(configuration=key, optimization=opt, completed_days=len(accepted), requested_days=end,
                          solute_active=project.solute,
                          generated_donor_optimization=generated_opt,original_provider_optimization='O2',
                          full_period_pass=len(accepted)==project.last_day, retained_failure=data[-1] if partial else None,
                          original_retained_failure_day=51 if partial else None,
                          maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in accepted),
                          maximum_solute_residual_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2', 0)) for r in accepted) if project.solute else None,
                          restart_window=[cut, cut+2], exact_day_suffix=True, exact_native_auxiliary=not partial,
                          original_input_sha256=dict(project.input_inventory), build_sha256=h.sha(bundle/'BUILD.json'),
                          scope='Experimental functional evidence; not scientific equivalence')
            reports.append(report)
            (out/'PROFILES.json').write_text(json.dumps(reports, indent=2)+'\n')
            if active_options:
                active_cut=200 if 'salt' in key else 530
                prefix=out/(label+'-active-prefix');active=out/(label+'-active-restart');endstate=out/(label+'-active-end')
                call(label+'-active-prefix',reuse+['--output',prefix,'--days',active_cut+2,'--checkpoint-at',active_cut])
                accepted_origin=prefix/f'accepted-column-1-day-{active_cut}.zip';origin_hash=h.sha(accepted_origin)
                with zipfile.ZipFile(accepted_origin) as z:aux=z.read('macro.bin')
                terminal=management_end(aux,project)
                assert struct.unpack_from('=i',aux,terminal-404)[0]==1, label+' did not checkpoint an emerged crop'
                if key=='gash-interception':
                    assert rows(prefix)[active_cut]['external_flux_cm'][9]>0, label+' did not exercise active simple-crop uptake'
                    report['active_growth_kind']='Original simple crop with positive root uptake; no WOFOST rate claim'
                else:
                    assert any(value!=0 for value in struct.unpack_from('=50d',aux,terminal-400)), label+' did not checkpoint active growth rates'
                call(label+'-active-restart',reuse+['--output',active,'--days',active_cut+2,'--checkpoint-at',active_cut+2,
                                                 '--restart',accepted_origin,'--restart-day',active_cut])
                call(label+'-active-end',reuse+['--output',endstate,'--days',active_cut+2,'--checkpoint-at',active_cut+2])
                assert list(map(physical,rows(active)))==list(map(physical,(data if opt=='O2' else rows(prefix))[active_cut:active_cut+2]))
                assert payload(active/f'accepted-column-1-day-{active_cut+2}.zip')==payload(endstate/f'accepted-column-1-day-{active_cut+2}.zip')
                assert h.sha(accepted_origin)==origin_hash
                report['active_crop_exact_native_window']=[active_cut,active_cut+2]
                if args.process_options:
                    report['active_native_soil_temperature_C']=native_temperatures(endstate/f'accepted-column-1-day-{active_cut+2}.zip',project)
                    report['thermal_scope']='Original temperature state and exact continuation; whole physical energy NOT_QUALIFIED'
                    (out/'PROFILES.json').write_text(json.dumps(reports,indent=2)+'\n')
            if opt == 'O2':
                full_rows = data
                # Two independent original workers under one kernel, at two
                # different physical/calendar origins, stepped in alternating order.
                short = out/(label+'-short')
                call(label+'-short', reuse+['--output', short, '--days', 5, '--checkpoint-at', 2])
                # A known different numerical policy cannot silently reuse this build.
                if key==next(iter(cases)):
                    target=out/'refused-numerical-policy-binding'
                    call('negative-numerical-policy-binding',base+['--build-bundle',bundle,
                         '--experimental-time-step-policy',h.NO_MACRO_TIME_POLICY,'--output',target,'--days',1],
                         refuse=True,absent=target)
                meta, actual = validate_bundle(bundle, reference, project)
                isolated = out/(label+'-isolated'); isolated.mkdir()
                restored = out/(label+'-isolation-origin')
                receipt = h.verify_checkpoint(short/'accepted-column-1-day-2.zip', 2, meta['binding'], restored)
                with contextlib.ExitStack() as stack:
                    host = h.DailyHost(stack, h.executable(bundle, 'day_donor'), h.executable(bundle, 'day_kernel'),
                                       actual, isolated, [h.ColumnStart(name='cold'), h.ColumnStart(day=2, origin=restored, receipt=receipt, name='warm')],
                                       runtime=True, checkpoint_enabled=True, project=project)
                    for offset in range(3):
                        for column, index in [(2, offset+2), (1, offset)]:
                            assert physical(host.step(column)) == physical(full_rows[index])
                    host.close()
                refused = out/(label+'-mass-refused'); refused.mkdir()
                with contextlib.ExitStack() as stack:
                    host = h.DailyHost(stack, h.executable(bundle, 'day_donor'), h.executable(bundle, 'day_kernel'),
                                       actual, refused, [h.ColumnStart()], runtime=True, checkpoint_enabled=True, project=project)
                    origin_stocks = host.columns[0].stocks.copy()
                    send = h.send
                    def inconsistent_flux(process, line):
                        values = line.split()
                        if process is host.host and len(values) == project.nodes+12:
                            values[2] = str(float(values[2])+1.0)
                            line = ' '.join(values)
                        return send(process, line)
                    try:
                        h.send = inconsistent_flux
                        rejected = host.step(1)
                    finally:
                        h.send = send
                    assert not rejected['committed'] and rejected['revision'] == 0
                    assert host.columns[0].day == 0 and host.columns[0].stocks == origin_stocks
                    assert not list(refused.glob('accepted-*.zip'))
                    host.close()
                external = CoupledDailyColumn(bundle, reference, out/(label+'-external'), project, 'coverage-'+key)
                first = external.prepare(); external.discard(first)
                assert external.day == external.revision == 0 and external.checkpoint is None
                replay = external.prepare()
                assert replay.budget == first.budget
                external.accept(replay)
                accepted = external.checkpoint; digest = h.sha(accepted)
                second = external.prepare(); external.discard(second)
                assert external.day == 1 and h.sha(accepted) == digest
                repeat = external.prepare(); assert repeat.budget == second.budget
                external.accept(repeat)
                recovered = CoupledDailyColumn(bundle, reference, out/(label+'-recovered'), project, 'coverage-'+key,
                                               origin=external.checkpoint, day=2)
                third = recovered.prepare()
                assert physical({k:v for k,v in third.budget.items() if k != 'candidate_only'} | {'committed':True}) == physical(full_rows[2])
                recovered.discard(third)
                report.update(independent_distinct_origins=True, external_discard_replay_exact=True, external_disk_recovery=True,
                              inconsistent_mass_refused_without_commit=True)
                if (args.extended and key.startswith('hupsel')) or (args.crop_options and key.startswith('water-')):
                    with zipfile.ZipFile(origin) as z:
                        members={name:z.read(name) for name in z.namelist()}
                    original_aux=members['macro.bin']
                    thermal='snow' in key
                    index=len(original_aux)-(8*(2*project.nodes+2) if thermal else 8)
                    if not project.solute:index=management_end(original_aux,project)-8
                    controls=[('wrong-format',b'S5HUP012'+original_aux[8:]),
                              ('short',original_aux[:-1]),
                              ('nan',original_aux[:index]+struct.pack('=d',float('nan'))+original_aux[index+8:]),
                              ('negative',original_aux[:index]+struct.pack('=d',-1.0)+original_aux[index+8:])]
                    if not project.solute:
                        flag=management_end(original_aux,project)-404
                        controls[-1]=('invalid-crop-flag',original_aux[:flag]+struct.pack('=i',99)+original_aux[flag+4:])
                    for mutation,data in controls:
                        changed=dict(members);changed['macro.bin']=data
                        manifest=json.loads(changed['checkpoint.json']);manifest['files']['macro.bin']=hashlib.sha256(data).hexdigest()
                        changed['checkpoint.json']=json.dumps(manifest).encode()
                        checkpoint=out/(label+'-'+mutation+'.zip')
                        with zipfile.ZipFile(checkpoint,'w') as z:
                            for name,value in changed.items():z.writestr(name,value)
                        target=out/(label+'-refused-'+mutation)
                        call(label+'-native-'+mutation,reuse+['--output',target,'--days',cut+2,'--checkpoint-at',cut+2,
                                                             '--restart',checkpoint,'--restart-day',cut],refuse=True)
                        assert not list(target.glob('accepted-*.zip'))
                        assert h.sha(origin)==before
                    report['resealed_native_history_refusals']=len(controls)
                (out/'PROFILES.json').write_text(json.dumps(reports, indent=2)+'\n')

        # The unchanged original executable is a comparison reference, never
        # patched or reused as an acceptance oracle for its known defects.
        donor = h.executable(reference/'build', 'swap_b0_gfortran')
        original = out/(key+'-original'); shutil.copytree(case, original)
        started = time.monotonic()
        with (original/'stdout').open('wb') as log:
            result = subprocess.run([str(donor), './swap.swp'], cwd=original, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        comparison = dict(returncode=result.returncode, seconds=time.monotonic()-started,
                          swap_ok=(original/'swap.ok').is_file(),
                          error=(original/'swap.err').read_text(encoding='cp1252') if (original/'swap.err').exists() else '',
                          scientific_equivalence='NOT_QUALIFIED', original_executable_sha256=h.sha(donor))
        (out/(key+'-LITERAL_REFERENCE.json')).write_text(json.dumps(comparison, indent=2)+'\n')
        if not comparison['swap_ok']:
            # The distributed SaltFarm template requests nonexistent S_CONC.
            # Preserve that literal FAIL; rerun the unchanged executable with
            # the already admitted output-only CSV spelling/precision adapter.
            assert 'Item S_CONC in userlist not known' in comparison['error']
        compat = out/(key+'-reference-csv'); shutil.copytree(case, compat)
        path = compat/'swap.swp'
        text, count = re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",
                              r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'", path.read_text(encoding='cp1252'))
        assert count == 1
        text = re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1', r'\g<1>0', text)
        path.write_text(text+'\nNUM_DECIMALS = 12\n', encoding='cp1252')
        with (compat/'stdout').open('wb') as log:
            result = subprocess.run([str(donor), './swap.swp'], cwd=compat, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        comparison['output_compatible_reference'] = dict(returncode=result.returncode, swap_ok=(compat/'swap.ok').is_file(),
            error=(compat/'swap.err').read_text(encoding='cp1252') if (compat/'swap.err').exists() else '',
            changes=['INLIST_CSV valid original groups', 'SWMONTH=0', 'NUM_DECIMALS=12'], physical_changes=False,
            input_sha256={p.name:h.sha(p) for p in case.iterdir() if p.is_file()}, prepared_swp_sha256=h.sha(path))
        # Report numerical differences on actual common CSV fields without
        # assigning new scientific tolerances or relabelling inherited FAILs.
        def csv_rows(path):
            lines = [line for line in path.read_text(encoding='cp1252').splitlines() if line.strip() and not line.startswith('*')]
            return list(csv.DictReader(lines))
        left = csv_rows(compat/'result_output.csv')
        right = csv_rows(out/(key+'-O2-control')/'original/result_output.csv')
        comparison['original_output_rows'] = len(left)
        comparison['hybrid_output_rows'] = len(right)
        if len(left) == len(right):
            deltas = {}
            for field in left[0]:
                try:
                    deltas[field] = max(abs(float(a[field])-float(b[field])) for a,b in zip(left,right,strict=True))
                except (ValueError, KeyError, TypeError):
                    pass
            comparison['maximum_numeric_csv_differences'] = deltas
        (out/(key+'-COMPARISON.json')).write_text(json.dumps(comparison, indent=2)+'\n')
        checked = comparison['output_compatible_reference']
        assert checked['swap_ok'] and not checked['error'].strip() and checked['returncode'] in (0, 100)

    # All refusals occur before any model/output ownership is acquired.
    key = 'salt-adsorption' if args.extended else ('bare' if args.basic_options else ('no-interception' if args.crop_options else ('analytic-heat' if args.process_options else 'salt08')))
    case = cases[key]; control = case/'swap.swp'; saved = control.read_bytes()
    base = ['--model', e.MODEL, '--experimental-project', case, '--reference-work', reference,
            '--build-bundle', out/(key+'-O2-build')]
    bad = [('macro', 'SWMACRO', 1), ('snow', 'SWSNOW', 2), ('frost', 'SWFROST', 1),
           ('hysteresis', 'SWHYST', 3), ('solute', 'SWSOLU', 2), ('adsorption', 'SWSP', 2),
           ('decay', 'SWDC', 2), ('reservoir', 'SWBR', 1), ('surfacewater', 'SWDRA', 2),
           ('heat', 'SWHEA', 2), ('other-bottom', 'SWBOTB', 9),
           ('reconstructed-groundwater', 'SWBOTB', 1), ('reconstructed-head', 'SWBOTB', 5)]
    for label, name, value in bad:
        target = out/('refused-'+label)
        try:
            text, count = re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+', lambda m:m[1]+str(value), saved.decode('cp1252'))
            assert count == 1
            control.write_text(text, encoding='cp1252')
            call('negative-'+label, base+['--output', target, '--days', 1], refuse=True, absent=target)
        finally:
            control.write_bytes(saved)
    for label, suffix in [('duplicate', b'\nSWMACRO = 0\n'), ('changed-input', b'\n! changed input binding\n')]:
        target=out/('refused-'+label)
        try:
            control.write_bytes(saved+suffix)
            call('negative-'+label, base+['--output', target, '--days', 1], refuse=True, absent=target)
        finally:
            control.write_bytes(saved)
    target=out/'refused-release-claim'
    call('negative-release-claim', base+['--no-macro-release','--output',target], refuse=True, absent=target)
    result = dict(status='EXPERIMENTAL_HYDRAULIC_OPTIONS_PASS' if args.hydraulic_options else 'EXPERIMENTAL_PROCESS_OPTIONS_PASS' if args.process_options else 'EXPERIMENTAL_CROP_OPTIONS_PASS' if args.crop_options else ('EXPERIMENTAL_BASIC_OPTIONS_PASS' if args.basic_options else ('EXPERIMENTAL_EXTENDED_COVERAGE_PASS' if args.extended else 'EXPERIMENTAL_FUNCTIONAL_COVERAGE_WITH_RETAINED_REFUSAL')), source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  configurations=reports, independent_new_historical_projects=0,
                  new_original_workbook_configurations=0 if extra else 2, new_derived_process_configurations=7 if args.hydraulic_options else (9 if args.process_options else (6 if args.crop_options else (7 if args.extended or args.basic_options else 2))),
                  science='NOT_QUALIFIED; inherited FAILs/reference limits retained', events=events)
    (out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
    print(result['status'], flush=True)


if __name__ == '__main__':
    main()
