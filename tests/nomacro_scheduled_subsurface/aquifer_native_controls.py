"""Actual input and binary native aquifer failures; no fabricated receipts."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('aq_controls',Path(__file__).with_name('aquifer_controls.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m
spec=importlib.util.spec_from_file_location('aq_reference',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/run.py')
ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)


def main():
    p=argparse.ArgumentParser()
    for key in ('evidence','input-root','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();checks=[]
    def save():(a.output/'RESULT.json').write_text(json.dumps(dict(status='RUNNING',checks=checks),indent=2)+'\n')
    save()
    for opt in ('O0','O2'):
        build=a.evidence/('sorption-decay-'+opt+'-build');project=m.e.load(a.input_root/'sorption-decay')
        meta,case=m.validate_bundle(build,a.reference_work,project)
        for field,value in [('DAQUIF','0.0'),('POROS','0.0'),('KFSAT','-1.0'),('DECSAT','-1.0'),('CDRAINI','-1.0'),('CDRAINI','NaN'),('BDENS','missing')]:
            name=opt+'-'+field+'-'+value;inputdir=a.output/(name+'-input');shutil.copytree(case,inputdir)
            path=inputdir/'swap.swp';text=path.read_text(encoding='cp1252')
            if field=='BDENS':
                text=text.replace('  BDENS','').replace(' BDENS\n','\n').replace(' 1315.0','')
                assert '1315.0' not in text
            else:
                text=ref.assignment(text,field,value)
                # Zero porosity must actually imply zero capacity.
                if field=='POROS':text=ref.assignment(text,'KFSAT','0.0')
            path.write_text(text,encoding='cp1252');target=a.output/name;target.mkdir()
            try:
                m.bounded(20,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),inputdir,target,1,runtime=True,model=project.model,project=project))
            except (RuntimeError,ValueError) as error:
                diagnostic='\n'.join(path.read_text(errors='replace') for pattern in ('donor.stderr','swap.err') for path in target.rglob(pattern))
                assert 'aquifer' in diagnostic.lower() or field in diagnostic.upper(),(field,diagnostic,str(error))
                assert not list(target.glob('accepted-*.zip'))
                checks.append(dict(optimization=opt,test='invalid-input-'+field+'-'+value,status='REFUSED',diagnostic=diagnostic));save()
            else:raise AssertionError('Invalid aquifer input accepted: '+name)
        full=a.evidence/('sorption-decay-'+opt+'-full');state=m.rows(full)[198]['aquifer_state']
        pack=lambda v:struct.pack('<6dq',*v[:6],int(v[6]))
        for attack in ('concentration','capacity','stock','soil-cumulative','surface-cumulative','decay-cumulative','count','nonfinite','truncated'):
            target=a.output/(opt+'-native-'+attack);target.mkdir();origin=target/'origin'
            receipt=m.h.verify_checkpoint(full/'accepted-column-1-day-199.zip',199,meta['binding'],origin)
            path=origin/'macro.bin';raw=path.read_bytes();needle=pack(state);assert raw.count(needle)==1
            offset=raw.index(needle);values=state.copy()
            if attack=='truncated':raw=raw[:offset+8]
            else:
                index={'concentration':0,'capacity':1,'stock':2,'soil-cumulative':3,'surface-cumulative':4,'decay-cumulative':5,'count':6,'nonfinite':0}[attack]
                values[index]=float('nan') if attack=='nonfinite' else values[index]+1
                raw=raw[:offset]+pack(values)+raw[offset+len(needle):]
            path.write_bytes(raw)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',199,origin,receipt)],runtime=True,checkpoint_enabled=True,
                        binding=meta['binding'],model=project.model,project=project)
            except (RuntimeError,ValueError) as error:
                diagnostic='\n'.join(path.read_text(errors='replace') for path in target.rglob('donor.stderr'))
                assert 'aquifer' in diagnostic.lower() or 'aquifer' in str(error).lower(),(attack,diagnostic,str(error))
                assert not list(target.glob('accepted-*.zip'))
                checks.append(dict(optimization=opt,test='native-'+attack,status='REFUSED',error=str(error),diagnostic=diagnostic));save()
            else:raise AssertionError('Corrupted private native aquifer accepted: '+attack)
    (a.output/'RESULT.json').write_text(json.dumps(dict(status='AQUIFER_INVALID_INPUT_AND_PRIVATE_NATIVE_REFUSALS_PASS',checks=checks),indent=2)+'\n')
    print('AQUIFER_INVALID_INPUT_AND_PRIVATE_NATIVE_REFUSALS_PASS',flush=True)


if __name__=='__main__':main()
