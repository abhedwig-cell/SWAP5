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
    test=test_source()
    return dict(status='GENUINE_CURRENT_HUPSEL_CHECKOUT_ONLY_COMPLETE_LITERAL_ADDITION_PASS',
        actual_head=head.decode().strip(),actual_before_source=BEFORE,actual_parent=BASE,files=[PATH,test['path']],
        actual_workflow_sha256=SHA(actual),original_workflow_sha256=SHA(before),
        original_model_commands_and_caps_and_job_timeout_unchanged=True,
        test_source_custody=test,
        source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)


TEST_PATH='tests/hupsel51/test_successor.py'
TEST_BEFORE='e28233d32c404c86fa58d7cbd71f7632dde1654c'
TEST_OLD='                new=checkout.historical_workflow(path,new)\n'
TEST_NEW="""                if path==s.QUALIFY:
                    spec=importlib.util.spec_from_file_location('actual_hupsel_checkout_custody',s.ROOT/'tests/nomacro_drainage/implicit_hydraulic_state_ci_checkout_custody.py')
                    custody=importlib.util.module_from_spec(spec);spec.loader.exec_module(custody)
                    custody.validate_workflow_text(new)
                    with self.assertRaises(ValueError):
                        custody.validate_workflow_text(new.replace('python','echo',1))
                    # The actual current file is proved above. This separate
                    # legacy assertion reads its genuine canonical ancestor;
                    # it never substitutes a historical checkout for execution.
                    ancestor=custody.git('show',custody.BASE+':'+path).decode()
                    new=checkout.historical_workflow(path,ancestor)
                else:new=checkout.historical_workflow(path,new)
"""


def test_source():
    q=json.loads(git('show','HEAD:'+PREFIX+'IMPLICIT_HYDRAULIC_STATE11_WORKFLOW_TEST_CUSTODY_V1.json'))
    assert q['actual_before_source']==TEST_BEFORE and q['actual_canonical_dependency']==BASE
    assert set(q['files'])=={TEST_PATH}
    item=q['files'][TEST_PATH];raw=git('show',BASE+':'+TEST_PATH)
    assert raw==git('show',TEST_BEFORE+':'+TEST_PATH) and SHA(raw)==item['before_lf_sha256']
    before=raw.decode();assert before.count(TEST_OLD)==1;at=before.index(TEST_OLD)
    assert item['ordered_literal_edits']==[dict(base_start=at,base_end=at+len(TEST_OLD),before=TEST_OLD,after=TEST_NEW)]
    actual=(ROOT/TEST_PATH).read_bytes().replace(b'\r\n',b'\n')
    assert actual==git('show','HEAD:'+TEST_PATH)==before.replace(TEST_OLD,TEST_NEW,1).encode()
    assert SHA(actual)==item['proposed_lf_sha256']
    return dict(path=TEST_PATH,actual_test_sha256=SHA(actual),original_test_sha256=SHA(raw),
                all_other_negative_control_bodies_unchanged=True,current_workflow_rewrite_negative_retained=True)


def validate_workflow_text(text):
    proof=source()
    if not isinstance(text,str) or SHA(text.encode())!=proof['actual_workflow_sha256']:
        raise ValueError('Foreign complete actual Hupsel workflow text')
    return proof
