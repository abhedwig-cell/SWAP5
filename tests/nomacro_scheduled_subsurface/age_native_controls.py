"""Actual original reader and private binary age-state refusal controls."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('age_controls',Path(__file__).with_name('age_controls.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m
spec=importlib.util.spec_from_file_location('age_reference',Path(__file__).with_name('age_reference.py'))
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','input-root','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();checks=[]
    def save(status='RUNNING'):(a.output/'RESULT.json').write_text(json.dumps(dict(status=status,checks=checks),indent=2)+'\n')
    save()
    for opt in ('O0','O2'):
        build=a.evidence/('100-'+opt+'-build');project=m.e.load(a.input_root/'100')
        meta,case=m.validate_bundle(build,a.reference_work,project)
        for name,initial in [('negative',-1.),('above-input-domain',1001.),('nonfinite',float('nan')),('missing',0.)]:
            inputdir=a.output/(opt+'-input-'+name);f.fixture(inputdir,initial)
            if name=='missing':
                path=inputdir/'swap.swp';text=path.read_text(encoding='cp1252');text=text[:text.index('\nAGEMLTB =')];path.write_text(text,encoding='cp1252')
            invalid=m.e.load(inputdir);target=a.output/(opt+'-reader-'+name);target.mkdir()
            try:
                m.bounded(20,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),inputdir,target,1,
                    runtime=True,model=invalid.model,project=invalid))
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(errors='replace') for pattern in ('swap.err','donor.stderr') for p in target.rglob(pattern))
                expected='AGEMLTB' in diagnostic.upper() or (name=='nonfinite' and 'NAN' in diagnostic.upper() and 'Fatal execution error' in diagnostic)
                assert expected,(name,diagnostic,str(error))
                assert not list(target.glob('accepted-*.zip'))
                checks.append(dict(optimization=opt,test='reader-'+name,status='REFUSED',diagnostic=diagnostic));save()
            else:raise AssertionError('Invalid initial original age accepted: '+name)
        full=a.evidence/('100-'+opt+'-full');source=full/'accepted-column-1-day-367.zip';digest=m.sha(source)
        state=m.rows(full)[366]['age_state_cm_day'];nodes=project.nodes
        # The selected original Hupsel fixture has one drainage level. Verify
        # the actual stream's redundant total before interpreting its tail.
        for attack in ('negative-bulk','nonfinite-bulk','negative-age','negative-output-age','negative-pond',
                       'foreign-boundary','changed-production','negative-infiltration','wrong-stock',
                       'negative-day','negative-period','nonfinite-period','truncated','overflow-stock'):
            target=a.output/(opt+'-native-'+attack);target.mkdir();origin=target/'origin'
            receipt=m.h.verify_checkpoint(source,367,meta['binding'],origin)
            path=origin/'macro.bin';raw=bytearray(path.read_bytes());length=len(raw)
            assert list(struct.unpack_from('<3d',raw,length-44))==state[:3]
            start=length-24*nodes-8*26-20
            if attack=='truncated':raw=raw[:-1]
            else:
                offsets={'negative-bulk':start,'nonfinite-bulk':start,'negative-age':start+8*nodes,
                    'negative-output-age':start+16*nodes,'negative-pond':start+24*nodes,
                    'foreign-boundary':start+24*nodes+24,'changed-production':start+24*nodes+48,
                    'negative-infiltration':start+24*nodes+48+56,'wrong-stock':length-44,
                    'negative-day':length-20,'negative-period':length-16,'nonfinite-period':length-16,'overflow-stock':start}
                offset=offsets[attack]
                if attack=='negative-day':struct.pack_into('<i',raw,offset,-1)
                else:
                    value=float('nan') if attack.startswith('nonfinite') else 1e300 if attack=='overflow-stock' else -1. if attack.startswith('negative') else struct.unpack_from('<d',raw,offset)[0]+1.
                    struct.pack_into('<d',raw,offset,value)
            path.write_bytes(raw)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',367,origin,receipt)],runtime=True,checkpoint_enabled=True,
                        binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
                assert 'age' in diagnostic.lower() or 'age' in str(error).lower(),(attack,diagnostic,str(error))
                assert not list(target.glob('accepted-*.zip'))
                checks.append(dict(optimization=opt,test='native-'+attack,status='REFUSED',diagnostic=diagnostic,error=str(error)));save()
            else:raise AssertionError('Corrupt private age native accepted: '+attack)
            assert m.sha(source)==digest
    save('ORIGINAL_AGE_READER_AND_PRIVATE_NATIVE_REFUSALS_PASS');print('ORIGINAL_AGE_READER_AND_PRIVATE_NATIVE_REFUSALS_PASS',flush=True)


if __name__=='__main__':main()
