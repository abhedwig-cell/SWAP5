"""Actual compiled calendar/implicit-root-tail refusals; no accepted model days."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/nomacro_drainage'))
import frost_cde_drainage_controls as previous
m = previous.inherited.m


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'profile', 'output'):
        p.add_argument('--'+key, type=Path, required=True)
    a = p.parse_args(); a.output.mkdir()
    profile = json.loads((a.profile/'RESULT.json').read_text(encoding='utf-8'))
    build = Path(profile['build_root'])
    project = m.e.load(profile['input_root'], original_output=True,
                       time_step_policy='original-adaptive-event-closure-v1')
    meta, case = m.validate_bundle(build, a.reference_work, project)
    source = a.profile/'trajectory/accepted-column-1-day-4.zip'; before = m.sha(source)
    with zipfile.ZipFile(source) as archive: raw = archive.read('macro.bin')
    from frost_calendar_output import codec
    expected = codec(project)
    assert raw[:8] == expected
    offset = len(raw)-96
    selected=m.e.switches((Path(profile['input_root'])/'swap.swp').read_text(encoding='cp1252'))
    mode=selected['SWHYST'];bottom=selected['SWBOTB'];assert bottom in (5,6,8)
    assert mode in (0,1,2)
    assert list(struct.unpack_from('<8i', raw, offset)) == [4,project.nodes,int(project.solute),1,mode,bottom,1,0]
    attacks = [(label,None) for label in ('prior-implicit-codec','explicit-parent-codec',
               'missing-tail','truncated-tail','extra-tail')]
    attacks += [('domain-'+str(i),i) for i in range(8)]
    attacks += [('domain-witness-'+str(i),i) for i in range(8)]
    attacks += [('nan-'+str(i),i) for i in range(2)]
    attacks += [('value-witness-'+str(i),i) for i in range(2)]
    q = dict(status='RUNNING', source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        actual_BUILD_sha256=m.sha(build/'BUILD.json'), original_checkpoint_sha256=before,
        expected_compiled_refusals=len(attacks), refusals=[], accepted_model_days=0)
    def save(): (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for label,index in attacks:
            target=a.output/label; target.mkdir(); origin=target/'origin'
            receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
            bad=bytearray(raw)
            if label=='prior-implicit-codec': bad[:8]=b'S5FIC002' if project.solute else b'S5FIW002'
            elif label=='explicit-parent-codec': bad[:8]=b'S5FCC001' if project.solute else b'S5FCW001'
            elif label=='missing-tail': del bad[-96:]
            elif label=='truncated-tail': del bad[-1:]
            elif label=='extra-tail': bad.extend(b'X')
            elif label.startswith('domain-'):
                value=struct.unpack_from('<i',bad,offset+4*index)[0]+1
                struct.pack_into('<i',bad,offset+4*index,value)
                if not label.startswith('domain-witness-'): struct.pack_into('<i',bad,offset+32+4*index,value)
            else:
                position=offset+64+8*index
                value=float('nan') if label.startswith('nan-') else struct.unpack_from('<d',bad,position)[0]+1
                struct.pack_into('<d',bad,position,value)
                if label.startswith('nan-'): struct.pack_into('<d',bad,position+16,value)
            (origin/'macro.bin').write_bytes(bad)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                        binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(path.read_text(encoding='utf-8',errors='replace') for path in target.rglob('donor.stderr'))
                assert 'ERROR STOP' in diagnostic and not list(target.rglob('accepted-*.zip')), (label,str(error),diagnostic)
                q['refusals'].append(dict(attack=label,status='REFUSED',authority='compiled_native',
                    error=str(error),diagnostic=diagnostic))
            else: raise AssertionError('Malformed implicit Frost root native accepted: '+label)
            assert m.sha(source)==before; save()
        assert len(q['refusals'])==25
        q['status']='ACTUAL_COMPILED_IMPLICIT_FROST_ROOT_NATIVE_REFUSALS_PASS'
    except Exception as error: q.update(status='FAILED',error=repr(error)); raise
    finally: save()
    print(q['status'],len(q['refusals']))


if __name__=='__main__': main()
