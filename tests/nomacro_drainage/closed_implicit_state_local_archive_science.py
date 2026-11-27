"""Read the four actual repaired regression contexts without live build dependencies."""
from contextlib import ExitStack
from pathlib import PureWindowsPath
import json
from analytical_hydraulic_archives import Archive
from explicit_bottom9_archive_science import ReadView
from closed_implicit_state_science import observe,OriginalInputs
PRODUCER='ae8ddfbb9e029190baa0d4f42f9002cc3bce8b30'
W=PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600')


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_IMPLICIT_STATE13_REPAIRED_LOCAL_FOUR_RAW_V6',stack);assert store.record['sha256']=='bb345b239044957f390efd1bb193bff3cb89d36b9162aebe6fdc9ade67117f6f' and store.record['actual_scientific_producer_source']==PRODUCER
        original=OriginalInputs(stack);contexts=[]
        for opt in ['O0','O2']:
            root=ReadView(store,'actual/evidence/closure13-residual-feedback-v3/'+opt);summary=json.loads((root/'SUMMARY.json').read_text());assert len(summary['cases'])==2
            for entry in summary['cases']:
                assert entry['returncode']==entry['native_controls_returncode']==0
                profile=root/entry['case'];q=json.loads((profile/'RESULT.json').read_text());assert q['actual_source']==PRODUCER and q['optimization']==opt
                relative=PureWindowsPath(q['build_root']).relative_to(W);assert '..' not in relative.parts;build=ReadView(store,'actual/'+relative.as_posix())
                contexts.append(observe(profile,build=build,inputs=profile/'inputs',controls=root/(entry['case']+'-native-controls'),original_store=original))
        counts=dict(context_count=len(contexts),primary_days=sum(v['days'] for v in contexts),native_samples=sum(len(v['native_samples']) for v in contexts),exact_cold_windows=sum(len(v['exact_cold_windows']) for v in contexts),compiled_native_refusals=sum(v['compiled_native_refusals'] for v in contexts))
        assert tuple(counts.values())==(4,140,28,12,125)
        return dict(status='FOUR_ACTUAL_REPAIRED_CLOSED_IMPLICIT_LOCAL_CONTEXTS_STRICT_NATIVE_ARCHIVE_INDEPENDENT_PASS',actual_scientific_producer=PRODUCER,raw_sha256=store.record['sha256'],contexts=contexts,**counts,compiler_executions=0,model_executions=0,additional_local_contexts_counted_again=False,canonical_admission=False)
