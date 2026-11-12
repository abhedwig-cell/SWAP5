"""Standalone source provider for the three registered no-macro applications.

Builds original sources only. No original model, macro case or research capsule
is executed or required. The legacy Andelst preparation remains a separate route.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

import daily_host as h

PROJECTS = (h.GRASSGROWTH, h.HUPSEL, h.SALTFARM)


def toolchain():
    if sys.version_info < (3, 12):
        raise ValueError('Python 3.12 or later is required')
    tools = {}
    for name in ('gfortran', 'gcc', 'ar'):
        path = shutil.which(name)
        if not path:
            raise ValueError('Required GNU tool is missing from PATH: '+name)
        version = subprocess.check_output([path, '--version'], text=True, timeout=10).splitlines()[0]
        if 'GNU' not in version and name != 'gcc':
            raise ValueError('GNU toolchain required: '+version)
        tools[name] = dict(version=version, sha256=h.sha(Path(path)))
        if name != 'ar':
            major = int(subprocess.check_output([path, '-dumpfullversion'], text=True, timeout=10).split('.')[0])
            if major not in (15, 16):
                raise ValueError('Supported GNU compiler majors are 15 and 16: '+version)
            tools[name]['target'] = subprocess.check_output([path, '-dumpmachine'], text=True, timeout=10).strip()
    if tools['gcc']['target'] != tools['gfortran']['target']:
        raise ValueError('GCC and gfortran targets differ')
    return tools


def check_inputs(reference, project):
    case = Path(reference)/'distribution/SWAP_4.3.1/cases'/project.case
    pinned = h.ROOT/'reference/swap-4.3.1/projects'/project.case
    files = {p.relative_to(case).as_posix(): h.sha(p) for p in case.rglob('*') if p.is_file()}
    expected = {p.relative_to(pinned).as_posix() for p in pinned.rglob('*') if p.is_file()}
    if set(files) != expected:
        raise ValueError('Missing or unexpected registered original input: '+project.case)
    for name in files:
        if (case/name).read_bytes().replace(b'\r\n',b'\n') != (pinned/name).read_bytes().replace(b'\r\n',b'\n'):
            raise ValueError('Registered original input differs: '+project.case+'/'+name)
    text = (case/'swap.swp').read_text(encoding='cp1252')
    if re.findall(r'(?mi)^\s*SWMACRO\s*=\s*([^\s!]+)',text) != ['0']:
        raise ValueError('Registered no-macro input must explicitly retain SWMACRO=0')
    return files


def prepare(reference):
    """Create a fresh original object provider from repository-pinned ZIP bytes."""
    reference = Path(reference).resolve()
    if reference.exists():
        raise FileExistsError('Preparation directory must be new: '+str(reference))
    tools = toolchain()
    sources = h.ROOT/'reference/swap-4.3.1/source-archives'
    for name,digest in [('SWAP.ZIP',h.DONOR_SOURCE_SHA),('TTUTIL.ZIP',h.TTUTIL_SOURCE_SHA)]:
        if h.sha(sources/name) != digest:
            raise ValueError('Original source archive differs: '+name)
    reference.mkdir(parents=True)
    root = reference/'distribution/SWAP_4.3.1'
    target = root/'tools/SWAP/source';target.mkdir(parents=True)
    for name in ('SWAP.ZIP','TTUTIL.ZIP'):
        shutil.copyfile(sources/name,target/name)
    sys.path.insert(0,str(h.ROOT/'tools/solute'))
    from prepare_saltfarm import prepare as saltfarm
    for project in PROJECTS:
        case = root/'cases'/project.case
        if project == h.SALTFARM:
            saltfarm(case)
        else:
            case.parent.mkdir(parents=True,exist_ok=True)
            shutil.copytree(h.ROOT/'reference/swap-4.3.1/projects'/project.case,case)
    inputs = {p.model:check_inputs(reference,p) for p in PROJECTS}
    sys.path.insert(0,str(h.ROOT/'tools/vq'))
    from b0_source_runner import build_gfortran
    started = time.monotonic()
    _, logs = build_gfortran(root,reference/'build')
    (reference/'compile.log').write_text(''.join(logs))
    provider = {}
    for folder in ['swap-selected','swap-obj','ttutil-obj']:
        for path in sorted((reference/'build'/folder).iterdir()):
            if path.is_file():provider[path.relative_to(reference).as_posix()] = h.sha(path)
    record = dict(status='SOURCE_PROVIDER_READY_NO_MODEL_EXECUTED',
        toolchain=tools,python=sys.version,source_archives={n:h.sha(target/n) for n in ['SWAP.ZIP','TTUTIL.ZIP']},
        preparation_sources={n:h.sha(h.ROOT/n) for n in ['app/hybrid_water/user_prepare.py','tools/vq/b0_source_runner.py','tools/solute/prepare_saltfarm.py']},
        provider_files=provider,inputs=inputs,compile_seconds=time.monotonic()-started,
        original_model_executions=0,active_macro_executions=0)
    (reference/'PREPARED.json').write_text(json.dumps(record,indent=2)+'\n')
    return record


def validate(reference):
    reference = Path(reference)
    record = json.loads((reference/'PREPARED.json').read_text())
    if record['status'] != 'SOURCE_PROVIDER_READY_NO_MODEL_EXECUTED' or record['toolchain'] != toolchain():
        raise ValueError('Prepared provider or current compiler/library toolchain differs')
    h.verify_source(reference/'distribution/SWAP_4.3.1')
    for name,digest in record['preparation_sources'].items():
        if h.sha(h.ROOT/name) != digest:raise ValueError('Preparation source differs: '+name)
    inventory={p.relative_to(reference).as_posix() for folder in ('swap-selected','swap-obj','ttutil-obj')
               for p in (reference/'build'/folder).iterdir() if p.is_file()}
    if inventory != set(record['provider_files']):
        raise ValueError('Prepared source/object/library inventory differs')
    for name,digest in record['provider_files'].items():
        if h.sha(reference/name) != digest:raise ValueError('Prepared source/object/library differs: '+name)
    return record
