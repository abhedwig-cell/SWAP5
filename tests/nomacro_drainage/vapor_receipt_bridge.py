"""Validate retained compiled bundles across precisely the Python receipt fix."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
INITIAL='effd77a2f326e9b8b0cee14181bc18b9c669f142'
PATH='app/hybrid_water/cde_native_receipt.py'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


@contextmanager
def receipt_bridge(build):
    import cde_native_receipt as current
    identity=json.loads((build/'BUILD.json').read_text())['identity']
    actual=identity.get('cde_native_receipt')
    if actual is None or actual==current.metadata():
        yield dict(status='ACTUAL_CURRENT_RECEIPT_IDENTITY');return
    assert identity['hydraulic_vapor']['native_codec']=='S5HVC003'
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
    assert git('diff','--name-only',INITIAL,'HEAD','--','app','src','tools/solute','tools/vq','reference/swap-4.3.1').decode().splitlines()==[PATH]
    assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==git('show','daba94800:'+PATH)
    frozen=git('show',INITIAL+':'+PATH)
    namespace={'__file__':str(ROOT/PATH)};exec(compile(frozen,PATH,'exec'),namespace)
    expected=namespace['metadata']();expected['source_sha256']=SHA(frozen)
    assert actual==expected
    # Only the validation namespace sees the exact historical descriptor.
    # All raw BUILD/checkpoint receipts stay untouched. Actual candidate
    # checking executes the new decoder, including the exact stock comparison.
    saved=current.metadata;current.metadata=lambda:expected
    try:
        yield dict(status='EXACT_HISTORICAL_DESCRIPTOR_AFTER_CHECKED_PYTHON_ONLY_DECODER_INVERSE',
            original_source=INITIAL,old_descriptor=expected,new_descriptor=saved(),
            actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),compiled_or_raw_bytes_changed=False)
    finally:current.metadata=saved
