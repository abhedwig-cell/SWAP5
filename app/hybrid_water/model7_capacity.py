"""Exact original model7 capacity correction for bounded explicit analytical inputs."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
ORIGINAL_SHA='1d40c5ea7aa1b2344409275603a3a603a52355fe3928ad7af24eb3bbbf379dcc'
NAME='WC_K_models_04_11'


def enabled(project):
    if not project.input_directory or project.macro or project.age:return False
    from experimental_project import switches
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    selected=switches(active)
    if any(selected.get(name)!=0 for name in ('SWKIMPL','SWSOPHY','SWHYST','SWFROST','SWMACRO')):return False
    values=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    return len(values)==1 and re.fullmatch(r'7(?:[ \t]+7)*[ \t]*',values[0]) is not None


def source(original):
    raw=original.encode('cp1252') if isinstance(original,str) else original
    raw=raw.replace(b'\r\n',b'\n');folder=ROOT/'reference/swap-4.3.1/hydraulic-corrections/CAPACITY-MODEL7-01'
    q=json.loads((folder/'manifest.json').read_text(encoding='utf-8'));target=(folder/(NAME+'.f90')).read_bytes().replace(b'\r\n',b'\n')
    sha=lambda value:hashlib.sha256(value).hexdigest()
    if sha(raw)!=ORIGINAL_SHA or q['base_lf_sha256']!=ORIGINAL_SHA or sha(target)!=q['target_lf_sha256']:
        raise ValueError('Foreign complete original model7 capacity reference')
    expected=raw.decode('cp1252')
    if len(q['edits'])!=1:raise ValueError('Ambiguous model7 capacity correction')
    for edit in q['edits']:
        if expected.count(edit['before'])!=1:raise ValueError('Foreign original model7 capacity seam')
        expected=expected.replace(edit['before'],edit['after'],1)
    if expected.encode('cp1252')!=target:raise ValueError('Foreign complete corrected model7 capacity module')
    return expected


def metadata(project):
    if not enabled(project):return None
    folder=ROOT/'reference/swap-4.3.1/hydraulic-corrections/CAPACITY-MODEL7-01'
    return dict(policy='literal-original-model7-shared-normalization-capacity-v1',
        source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        manifest_sha256=hashlib.sha256((folder/'manifest.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        original_lf_sha256=ORIGINAL_SHA,corrected_lf_sha256=hashlib.sha256((folder/(NAME+'.f90')).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        SWKIMPL=0,IHWCKMODEL=7,physical_equations_changed=False,new_physical_state=False,tolerance_changed=False)


def apply_build(output,reference,project,patched):
    if not enabled(project):return patched
    if NAME in patched:raise ValueError('Multiple original hydraulic capacity source owners')
    original=(reference/'swap-selected'/(NAME+'.f90')).read_bytes()
    (output/(NAME+'.f90')).write_text(source(original),encoding='cp1252')
    patched.insert(0,NAME);return patched


def validate(bundle,reference,project,identity):
    expected=metadata(project)
    if identity.get('model7_capacity')!=expected:raise ValueError('Foreign original model7 capacity policy')
    if expected is None:
        if NAME+'.f90' in identity['donor_generated']:raise ValueError('Unselected model7 capacity source owner')
        return
    original=(reference/'build/swap-selected'/(NAME+'.f90')).read_bytes()
    if (bundle/(NAME+'.f90')).read_text(encoding='cp1252')!=source(original):
        raise ValueError('Foreign complete actual original model7 capacity source')
    if NAME+'.o' in identity['donor_objects']:raise ValueError('Original uncorrected model7 capacity object retained')
