"""Exact genuine checkout-only Hupsel workflow custody; no identity projection."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
BEFORE='fdea74b3914fe37c05a6a5301af6661773e1e5e3'
PREFIX='integration/f-ci/nomacro-complete01/'
PATH='.github/workflows/hupsel51-water-balance.yml'
ADDITION=('        with:\n'
          '          filter: blob:none\n'
          '          sparse-checkout-cone-mode: false\n'
          '          sparse-checkout: |\n'
          '            /*\n'
          '            !/integration/**/*.zip\n'
          '            !/integration/**/*.zip.part*\n'
          '            !/integration/**/*.tar.xz\n'
          '            !/integration/**/*.tar.xz.part*\n'
          '            !/integration/**/*.tar.gz\n'
          '            !/integration/**/*.tar.gz.part*\n')
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
SHA=lambda b:hashlib.sha256(b).hexdigest()

def source():
    head=git('rev-parse','HEAD')
    q=json.loads(git('show','HEAD:'+PREFIX+'IMPLICIT_HYDRAULIC_STATE11_HUPSEL_CHECKOUT_CONTRACT_V1.json'))
    assert q['actual_before_source']==BEFORE and q['actual_canonical_dependency']==BASE and set(q['files'])=={PATH}
    item=q['files'][PATH];before=git('show',BASE+':'+PATH)
    assert before==git('show',BEFORE+':'+PATH) and SHA(before)==item['before_lf_sha256']
    edits=item['ordered_literal_edits'];assert len(edits)==1;edit=edits[0];text=before.decode()
    anchor='    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-python@v5'
    assert text.count(anchor)==1
    at=text.index(anchor)+len('    steps:\n      - uses: actions/checkout@v4\n')
    assert edit==dict(base_start=at,base_end=at,before='',after=ADDITION)
    actual=(ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')
    assert actual==git('show','HEAD:'+PATH)==(text[:at]+ADDITION+text[at:]).encode()
    assert SHA(actual)==item['proposed_lf_sha256']
    # This is a complete literal insertion proof, never an old workflow returned
    # under a new identity or used in place of the actual current workflow.
    assert actual.replace(ADDITION.encode(),b'',1)==before and git('rev-parse','HEAD')==head
    return dict(status='GENUINE_CURRENT_HUPSEL_CHECKOUT_ONLY_COMPLETE_LITERAL_ADDITION_PASS',
        actual_head=head.decode().strip(),actual_before_source=BEFORE,actual_parent=BASE,files=[PATH],
        actual_workflow_sha256=SHA(actual),original_workflow_sha256=SHA(before),
        original_model_commands_and_caps_and_job_timeout_unchanged=True,
        source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)
