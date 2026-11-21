"""Re-read the actual initial Ubuntu periods after a Python-only decoder fix."""
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from vapor_hydraulic_forensics import audit

ROOT=Path(__file__).resolve().parents[2]
INITIAL='effd77a2f326e9b8b0cee14181bc18b9c669f142'


def read_initial(proof,optimization):
    source=json.loads((proof/'source/RESULT.json').read_text());assert source['producer_head']==INITIAL
    changed=subprocess.check_output(['git','diff','--name-only',INITIAL,'HEAD','--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()
    assert changed==['app/hybrid_water/cde_native_receipt.py'],changed
    # This bridge accepts precisely the first checked decoder correction,
    # never an arbitrary later replacement of a private receipt validator.
    expected=subprocess.check_output(['git','show','daba94800:app/hybrid_water/cde_native_receipt.py'],cwd=ROOT)
    assert (ROOT/'app/hybrid_water/cde_native_receipt.py').read_bytes().replace(b'\r\n',b'\n')==expected
    projection=json.loads((proof/'COMPILED_PROJECTION_V1.json').read_text())
    class Reference:
        def __truediv__(self,name):
            assert name.startswith('build/')
            return proof/'original-provider-build'/name[6:]
    results=[]
    for kind in ('water','cde'):
        profile=proof/('vapor-hydraulic-family/8-'+kind+'-full');q=json.loads((profile/'RESULT.json').read_text())
        assert q['source']==INITIAL and q['kind']==kind and q['optimization']==optimization
        build=proof/projection[q['build_root']]['archive_prefix']
        observed=audit(profile,Reference(),locations=dict(build=build,inputs=profile/'input'))
        assert observed['days']==1096 and observed['cold_windows']==7
        results.append(observed)
    # Re-read the exact formerly refused private candidate; the stock check
    # remains exact. The raw failed control and its source identity stay intact.
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    from cde_native_receipt import decode
    raw=(proof/'vapor-hydraulic-family/8-cde-controls/transactions/external/trial-1/accepted-column-1-day-5.zip').read_bytes()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:stock=decode(archive.read('macro.bin'),34)
    warm=json.loads((proof/'vapor-hydraulic-family/8-cde-full/trajectory/daily.jsonl').read_text().splitlines()[4])
    assert stock==warm['solute_end_mg_cm2']
    return dict(status='INITIAL_TWO_FULL_PERIODS_14_EXACT_COLD_WINDOWS_REUSED_AFTER_PYTHON_ONLY_DECODER_FIX',
        original_source=INITIAL,observations=results,formerly_refused_candidate_exact_stock=stock,
        model_executions=0,compiler_executions=0,physical_source_changes=[],original_failed_control_preserved=True)
