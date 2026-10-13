"""Exact source authority for optional Boesten/macropore configuration repair.

Source eligibility alone is never scientific qualification. Fresh owner and
moving preservation evidence is required separately before admission.
"""
from pathlib import Path
import hashlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = 'cfc728c42b38026ba548f6250afec00969ccda67'
BACKEND = 'src/runtime/mod_fmr_serialized_reference_backend.f90'
PREIMAGE = '01d1981cc7aebb1553463b1cee955bb21da05fe6'
POSTIMAGE = '7dd238a0c9fae518beba9eb9dbac5fde1bbd5c18'


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def validate_change(old, new):
    assert blob(old) == PREIMAGE, 'unknown backend preimage'
    assert blob(new) == POSTIMAGE, 'unknown backend postimage'
    old_block = b'''          if(self%macropore_config%surface_pond_inflow_enabled)then
            boesten_top_provider%macropore_pond_donor_active=.true.
            boesten_top_provider%macropore_pond_threshold=self%macropore_config%surface_pond_threshold_cm
            boesten_top_provider%macropore_surface_conductivity= &
                 self%macropore_config%surface_macropore_conductivity_cm_per_day
          end if'''
    new_block = b'''          ! Boesten is valid without macropores. The optional configuration is
          ! allocated only for active macropores; Fortran does not guarantee
          ! short-circuit evaluation of a combined ALLOCATED/.AND. condition.
          if (allocated(self%macropore_config)) then
            if(self%macropore_config%surface_pond_inflow_enabled)then
              boesten_top_provider%macropore_pond_donor_active=.true.
              boesten_top_provider%macropore_pond_threshold=self%macropore_config%surface_pond_threshold_cm
              boesten_top_provider%macropore_surface_conductivity= &
                   self%macropore_config%surface_macropore_conductivity_cm_per_day
            end if
          end if'''
    assert old.count(old_block) == new.count(new_block) == 1
    assert old.replace(old_block, new_block) == new, 'change outside optional guard'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def verify_source():
    assert git('merge-base', '--is-ancestor', BASE, 'HEAD') == ''
    assert not git('status', '--porcelain', '--', 'src', 'reference')
    assert git('diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines() == [BACKEND]
    assert git('rev-parse', 'HEAD:reference') == git('rev-parse', BASE + ':reference')
    old = subprocess.check_output(['git', 'show', BASE + ':' + BACKEND], cwd=ROOT)
    new = (ROOT / BACKEND).read_bytes()
    validate_change(old, new)
    assert git('rev-parse', 'HEAD:' + BACKEND) == POSTIMAGE
    return {'baseline': BASE, 'backend_preimage': PREIMAGE,
            'backend_postimage': POSTIMAGE, 'source_tree': git('rev-parse', 'HEAD:src'),
            'scope': 'source eligibility only; no inherited backend science'}


if __name__ == '__main__':
    import json
    print(json.dumps(verify_source(), sort_keys=True))
