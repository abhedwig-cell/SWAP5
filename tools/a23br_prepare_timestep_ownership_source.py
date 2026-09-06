#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, shutil, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import a23bp_prepare_worker_source as bp
import a23bq_prepare_numerical_control_source as bq

PARENT_MANIFEST = bp.EXPECTED_PARENT_MANIFEST


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise ValueError(f'{label}: expected one anchor, got {n}')
    return text.replace(old, new, 1)


def build_a23bq(source: Path, output: Path, ttutil_prefs: Path) -> None:
    parent = bp.manifest(source)
    if bp.sha256_bytes(parent) != PARENT_MANIFEST:
        raise ValueError('A23BR parent is not exact B1.6')
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(source, output)
    for p in output.glob('*.f90'):
        text = p.read_text(encoding='latin1')
        text = ''.join(bp.convert_dec(line) for line in text.splitlines(True))
        p.write_text(text, encoding='latin1', newline='')
    shutil.copy2(ttutil_prefs, output/'ttutilprefs.f90')
    bp.transform_headcalc(output/'headcalc.f90')
    bp.transform_soilwater(output/'soilwater.f90')
    bp.transform_timecontrol(output/'timecontrol.f90')
    bp.transform_swap(output/'swap.f90')
    bq.rename_context_refs(output)
    bq.transform_headcalc(output/'headcalc.f90')
    bq.transform_timecontrol(output/'timecontrol.f90')
    bq.transform_surfacewater(output/'surfacewater.f90')
    bq.transform_drain(output/'MOD_drainage.f90')
    bq.transform_swap(output/'swap.f90')
    bq.transform_variables(output/'variables.f90')
    bq.transform_initialize(output/'initialize.f90')


def rename_context_refs(root: Path) -> None:
    for p in root.glob('*.f90'):
        s = p.read_text(encoding='latin1')
        s = s.replace('mod_a23bq_worker_execution_context', 'mod_a23br_worker_execution_context')
        s = s.replace('a23bq_worker_context_t', 'a23br_worker_context_t')
        s = s.replace('a23bq_record_internal_retry', 'a23br_record_internal_retry')
        s = s.replace('a23bq_request_dt_reduction', 'a23br_request_dt_reduction')
        s = s.replace('a23bq_reset_numerical_control', 'a23br_reset_numerical_control')
        p.write_text(s, encoding='latin1', newline='')


def transform_headcalc(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldtmin,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldtmin\b', 'worker%control%at_min_dt', s, flags=re.I)
    code = '\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldtmin\b', code, re.I):
        raise ValueError('headcalc still references fldtmin')
    path.write_text(s, encoding='latin1', newline='')


def transform_surfacewater(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldtmin,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldtmin\b', 'worker%control%at_min_dt', s, flags=re.I)
    code = '\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldtmin\b', code, re.I):
        raise ValueError('surfacewater still references fldtmin')
    path.write_text(s, encoding='latin1', newline='')


def transform_timecontrol(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = s.replace('a23br_reset_numerical_control', 'a23br_reset_all_numerical_control')
    s = re.sub(r'\bfldtmin,\s*', '', s, count=1, flags=re.I)
    if s.count('      fldtmin = .FALSE.\n') != 2:
        raise ValueError('timecontrol expected two fldtmin false anchors')
    s = s.replace('      fldtmin = .FALSE.\n', '', 1)
    if s.count('            fldtmin = .TRUE.\n') != 2:
        raise ValueError('timecontrol expected two fldtmin true anchors')
    s = s.replace('            fldtmin = .TRUE.\n', '            worker%control%at_min_dt = .true.\n', 1)
    s = replace_once(s, '      if (dt > (1.0d0+dtCrit)*dtmin) fldtmin = .FALSE.\n',
                     '      if (present(worker)) then\n         if (dt > (1.0d0+dtCrit)*dtmin) worker%control%at_min_dt = .false.\n      end if\n',
                     'timecontrol min flag update')
    if s.count('         fldtmin = .FALSE.\n') != 1:
        raise ValueError('timecontrol day-end fldtmin anchor mismatch')
    s = s.replace('         fldtmin = .FALSE.\n',
                  '         if (present(worker)) worker%control%at_min_dt = .false.\n', 1)
    if s.count('            fldtmin = .TRUE.\n') != 1:
        raise ValueError('timecontrol retry fldtmin anchor mismatch')
    s = s.replace('            fldtmin = .TRUE.\n',
                  '            worker%control%at_min_dt = .true.\n', 1)
    code = '\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldtmin\b', code, re.I):
        raise ValueError('timecontrol still references fldtmin')
    path.write_text(s, encoding='latin1', newline='')


def transform_swap(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldtreduce,\s*', '', s, count=1, flags=re.I)
    s = s.replace('a23br_reset_numerical_control', 'a23br_reset_attempt_control')
    s = replace_once(s, 'logical :: flError\n', 'logical :: flError\nlogical :: repeat_current_step\n', 'swap local repeat flag')
    s = replace_once(s, '      fldtreduce = .TRUE.\n      do while(fldtreduce)\n         fldtreduce = .FALSE.\n',
                     '      repeat_current_step = .true.\n      do while(repeat_current_step)\n         repeat_current_step = .false.\n',
                     'swap retry loop localize')
    s = replace_once(s, '            fldtreduce = .TRUE.\n', '            repeat_current_step = .true.\n', 'swap retry repeat request')
    code = '\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldtreduce\b', code, re.I):
        raise ValueError('swap still references fldtreduce')
    path.write_text(s, encoding='latin1', newline='')


def transform_variables(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = replace_once(s, '   logical                    :: fldtmin            ! Flag indicating that the time step is equal to the minimum time step\n', '', 'variables remove fldtmin')
    s = replace_once(s, '   logical                    :: fldtreduce\n', '', 'variables remove fldtreduce')
    path.write_text(s, encoding='latin1', newline='')


def transform_initialize(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bfldtmin,\s*', '', s, count=1, flags=re.I)
    s = re.sub(r'\bfldtreduce,\s*', '', s, count=1, flags=re.I)
    s = replace_once(s, '      fldtmin            = .FALSE. \n', '', 'initialize remove fldtmin')
    s = replace_once(s, '      fldtreduce         = .FALSE. \n', '', 'initialize remove fldtreduce')
    code = '\n'.join(line.split('!')[0] for line in s.splitlines())
    if re.search(r'\bfldtmin\b|\bfldtreduce\b', code, re.I):
        raise ValueError('initialize still references removed flags')
    path.write_text(s, encoding='latin1', newline='')


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--ttutil-prefs', type=Path, required=True)
    ns = ap.parse_args()
    build_a23bq(ns.source, ns.output, ns.ttutil_prefs)
    rename_context_refs(ns.output)
    transform_headcalc(ns.output/'headcalc.f90')
    transform_surfacewater(ns.output/'surfacewater.f90')
    transform_timecontrol(ns.output/'timecontrol.f90')
    transform_swap(ns.output/'swap.f90')
    transform_variables(ns.output/'variables.f90')
    transform_initialize(ns.output/'initialize.f90')

    for p in ns.output.glob('*.f90'):
        code = '\n'.join(line.split('!')[0] for line in p.read_text(encoding='latin1').splitlines())
        if re.search(r'\bfldtmin\b|\bfldtreduce\b', code, re.I):
            raise ValueError(f'legacy timestep singleton remains active in {p.name}')

    targets = ['headcalc.f90','timecontrol.f90','swap.f90','surfacewater.f90','variables.f90','initialize.f90']
    hashes = {name: sha256_bytes((ns.output/name).read_bytes()) for name in targets}
    dt_refs = 0
    for p in ns.output.glob('*.f90'):
        code = '\n'.join(line.split('!')[0] for line in p.read_text(encoding='latin1').splitlines())
        dt_refs += len(re.findall(r'\bdt\b', code, re.I))
    print(json.dumps({
        'parent_manifest_sha256': PARENT_MANIFEST,
        'postimage_sha256': hashes,
        'removed_legacy_globals': ['variables%fldtmin','variables%fldtreduce'],
        'persistent_numerical_state': ['column%numerical%dt'],
        'worker_derived_control': ['worker%control%at_min_dt'],
        'local_orchestration_control': ['repeat_current_step'],
        'legacy_backend_dt_active_references': dt_refs,
    }, sort_keys=True, indent=2))

if __name__ == '__main__':
    main()
