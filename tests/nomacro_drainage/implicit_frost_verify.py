"""Bounded implicit Frost native2 source, neutral raw science and inherited authority."""
import ast
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import implicit_frost_science as science

PARENT='ffa7ef153a79aafb4cf098a4c0031845c795e83f'
RUNTIME='664596939f699ddbf0ebbdfdcfedcd37c5cc60e7'
READERS='2c1daa04e32ab37240ab376e763bb52a780aeb34'
SEALED='fffd3a1034c7eba2cbafdc894d9eeb43162879ad'
PORTABLE='a6e37763a689716ec505d5f5f71dda0e94667014'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/FROST_IMPLICIT_QUALIFICATION.json'
OLD='tests/nomacro_drainage/frost_drainage_verify.py'
GUARD_HOOK='    import implicit_frost_verify as implicit_frost\n    return implicit_frost.guard_previous_source()\n'
VERIFY_HOOK='    import implicit_frost_verify as implicit_frost\n    return implicit_frost.verify()\n'
PROJECTION_HOOK='    import implicit_frost_verify as implicit_frost\n    text=implicit_frost.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/FROST_IMPLICIT_*\n'
PARSERS=('implicit_frost_science.py','implicit_frost_portable_forensics.py','implicit_frost_boundary_forensics.py',
         'implicit_frost_root_forensics.py','implicit_frost_model_forensics.py','implicit_frost_parent_bridge.json')
COUNTS=dict(actual_full_periods=8,actual_days_per_full_period=1096,actual_full_cold_windows=56,
    actual_short_contexts=8,actual_short_cold_windows=24,actual_compiled_refusals=540,
    actual_descriptor_refusals=56,actual_source_refusals=56,actual_transaction_contexts=8,
    actual_unselected_contexts=16,actual_unselected_cold_windows=16,actual_boundary_states_per_variant=2880,
    actual_Jacobian_entries_per_variant=25920,actual_native_provider_roundtrips=8,actual_native_provider_refusals=56)


def strip_current_evidence(text):
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous implicit Frost proof checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual implicit Frost compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('implicit_frost_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign implicit Frost parent source bridge')
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected={line.split('\t')[1]:line.split('\t')[0] for line in changes}
    require(set(expected)==set(bridge['changes'])|set(bridge['added']) and
        all(expected[path]=='M' for path in bridge['changes']) and all(expected[path]=='A' for path in bridge['added']),
        'Incomplete complete-file implicit Frost source bridge')
    for path,items in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(items):
            at=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[at:at+len(after)]==after,'Actual implicit Frost source bridge differs')
            lines[at:at+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Admitted explicit Frost complete source parent changed')
    for path,value in bridge['added'].items():require(sha(blob(RUNTIME,path))==value,'Added implicit Frost source differs')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen implicit Frost observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous implicit Frost delegation');old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier explicit Frost scientific owner changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD},'Earlier scientific observer changed beyond implicit Frost delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),
            'Registered CI changed beyond implicit Frost proof checkout')
    for name in ('pub-me-d1-transition-authority.yml','pub-me-d3-origin-authority.yml','pub-p2e06-reference-local-balance-scaling.yml',
        'pub-p2e07-reference-cancellation-floor.yml','pub-p2e08-reference-valid-calibration-domain.yml',
        'pub-p2e09-reference-threshold-freeze.yml','pub-p2e10-e0-broad-paired-matrix.yml','vq-reference.yml'):
        path='.github/workflows/'+name
        require(norm((ROOT/path).read_bytes())==blob(PARENT,path),'Publication dependency workflow changed')
    path='.github/workflows/nomacro-water-snow-groundwater.yml'
    require(norm((ROOT/path).read_bytes())==blob(PORTABLE,path),'Actual selected portable campaign changed')
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral implicit Frost qualification changed')
    q=json.loads(raw)
    require(q['status']=='NEUTRAL_IMPLICIT_FROST_NATIVE2_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
        (q['runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,PARENT,READERS),'Foreign bounded implicit Frost qualification')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['global_family_and_gap_counts']=='UNKNOWN',
        'Whole historical authority promoted')
    for name in ('RC3_changed','implicit_Frost_admitted','AGE_admitted','broader_calendars_admitted','fully_frozen_front_admitted','new_physical_state','extra_fixed_absolute_global_water_prefix_is_owning_gate'):
        require(q[name] is False,'Unqualified authority or water guard promoted: '+name)
    require(all(q[key]==value for key,value in COUNTS.items()) and len(q['archives'])==10,'Neutral implicit Frost denominator differs')
    require(all(q[name]==1e-10 for name in ('daily_water_guard_cm','daily_CDE_guard_mg_cm2','every_prefix_CDE_guard_mg_cm2')) and
        q['scientific_FD_scaled_derivative_limit']==2e-6 and q['unaffected_full_periods_replayed']==0,'Scientific guard or reuse criterion changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    import groundwater_snow_verify as archives
    for label,item in q['archives'].items():archives.archive_identity(item,label)
    import frost_drainage_verify as previous
    previous.source()
    return True


def inherited():
    path=PROOF/'FROST_DRAINAGE_ADMISSION_RAW_V1.zip';record=read(path.with_suffix('.json'))
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256']==
        'e1aaccfb127d6864f4be7178434b0961f527b1a7fd8db8dc9970e85afc10e7d2','Inherited actual explicit Frost admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(record['members']),'Inherited explicit Frost admission inventory differs')
        for name,item in record['members'].items():
            raw=z.read(name);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Inherited explicit Frost raw evidence changed')
        receipts=[json.loads(z.read(name)) for name in z.namelist() if name.endswith('ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json')]
        require(len(receipts)==1,'Missing unique actual explicit Frost canonical public observation')
        receipt=receipts[0]
        observed=json.loads(z.read('FROST_DRAINAGE_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(observed['status']=='BOUNDED_FROST_DRAINAGE_SOURCE_RAW_ADMISSION_PASS','Actual inherited explicit Frost public science result differs')
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and receipt['before']['status']=='' and
            len(receipt['before']['sparse'])==31 and receipt['returncode']==receipt['compiler_executions']==receipt['model_executions']==0,
            'Actual inherited explicit Frost canonical public receipt differs')
    import frost_drainage_verify as previous
    functions=[node for node in ast.parse(blob(PARENT,OLD).decode()).body if isinstance(node,ast.FunctionDef) and node.name=='verify']
    require(len(functions)==1,'Missing actual admitted explicit Frost scientific function')
    namespace=dict(previous.__dict__);exec(compile(ast.Module(body=functions,type_ignores=[]),OLD,'exec'),namespace)
    observations=namespace['verify']()
    require(observations['status']=='BOUNDED_FROST_DRAINAGE_SOURCE_RAW_ADMISSION_PASS','Original accepted explicit Frost science did not pass')
    return dict(status='UNCHANGED_ACTUAL_ADMITTED_EXPLICIT_FROST_AND_EARLIER_SCIENCE_REUSED',prior_actual_canonical=PARENT,
        literal_original_verify_body_executed=True,actual_original_observations=observations,fresh_unaffected_full_periods=0,
        inherited_observations_counted_fresh=False)


def verify():
    source();retained=inherited();win=science.windows(PROOF);portable={opt:science.ubuntu(PROOF,opt) for opt in ('O0','O2')};postimages=science.unselected(PROOF)
    for key in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts','actual_short_cold_windows',
        'actual_compiled_refusals','actual_descriptor_refusals','actual_source_refusals','actual_transaction_contexts'):
        require(sum(item[key] for item in [win,*portable.values()])==COUNTS[key],'Actual implicit Frost denominator differs: '+key)
    require(all(postimages[key]==COUNTS[key] for key in ('actual_unselected_contexts','actual_unselected_cold_windows')),'Actual implicit Frost unselected denominator differs')
    boundary=list(win['boundaries'].values())+[item['observations']['boundary'] for item in portable.values()]
    roots=list(win['root_providers'].values())+[item['observations']['root_provider'] for item in portable.values()]
    require(len(boundary)==len(roots)==4,'Missing actual platform/optimizer component context')
    for variant in ('actual_qualified_ordinary_implicit_composition','diagnostic_frost_surface_conductivity'):
        require(sum(item['variants'][variant]['states'] for item in boundary)==COUNTS['actual_boundary_states_per_variant'] and
            sum(item['variants'][variant]['raw_matrix_entries'] for item in boundary)==COUNTS['actual_Jacobian_entries_per_variant'],
            'Actual raw Jacobian component denominator differs')
    require(sum(item['roundtrips'] for item in roots)==COUNTS['actual_native_provider_roundtrips'] and
        sum(item['compiled_refusals'] for item in roots)==COUNTS['actual_native_provider_refusals'],'Actual native provider component denominator differs')
    return dict(status='BOUNDED_IMPLICIT_FROST_NATIVE2_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**COUNTS,
        Windows=win,Ubuntu=portable,unselected=postimages,inherited_unchanged_owners=retained,
        compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False,AGE_admitted=False,implicit_Frost_admitted=False,broader_calendars_admitted=False,fully_frozen_front_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
