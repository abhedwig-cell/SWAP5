"""Separate pinned historical numerical evidence from current source eligibility."""
import pathlib, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
HISTORICAL='7e3a1c25f74d71b1bf8344ec36bbec86e66bd570'
JOINT='d10d2b860576c18fca5b7b60336b36b82c42ed8b'
BASE='c591205c5e03f1c96c6488eb53c562265f749556'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def verify_context(source_ref='HEAD'):
    tree=git('rev-parse',source_ref+':src')
    if tree not in {HISTORICAL,JOINT}:raise ValueError('unregistered numerical source context')
    if git('rev-parse',source_ref+':reference')!=git('rev-parse',BASE+':reference'):raise ValueError('reference authority drift')
    if source_ref=='HEAD':
        if tree==JOINT:
            sys.path.insert(0,str(ROOT/'tests/modularity'))
            from joint_admission_authority import verify_source
        else:
            sys.path.insert(0,str(ROOT/'tests/performance'))
            from low_air_successor_authority import verify_source
        verify_source()
    return {'source_tree':tree,'source_ref':source_ref,'binding':'CURRENT_EXACT_SOURCE' if source_ref=='HEAD' else 'HISTORICAL_PINNED_REF_NOT_CURRENT_QUALIFICATION','canonical_admission':False}
