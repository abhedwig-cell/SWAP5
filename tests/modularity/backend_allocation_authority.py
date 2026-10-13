"""Exact source eligibility for optional configuration and beginning-ledger repairs.

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
PUBLICATION = 'src/runtime/mod_groundwater_multiswap_publication.f90'
PUBLICATION_PREIMAGE = 'b13e8a43210cb58dd1e6aa11d06967ae7b266d2a'
PUBLICATION_POSTIMAGE = 'ef2c293f9f826317dc0f072345abeb1c9c914c4a'


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


def validate_publication_change(old, new):
    """Only move the scalar beginning balance before publication; no arithmetic change."""
    assert blob(old) == PUBLICATION_PREIMAGE, 'unknown publication preimage'
    assert blob(new) == PUBLICATION_POSTIMAGE, 'unknown publication postimage'
    assignment = b'    initial_total = committed_ledger_total(result%ledger_snapshots, order)\n'
    boundary = b'    end do\n\n    do k = 1, n\n'
    assert old.count(assignment) == old.count(boundary) == 1
    expected = old.replace(assignment, b'').replace(
        boundary, b'    end do\n\n' + assignment + b'\n    do k = 1, n\n')
    assert expected == new, 'change outside beginning-balance timing'


def verify_source():
    assert git('merge-base', '--is-ancestor', BASE, 'HEAD') == ''
    assert not git('status', '--porcelain', '--', 'src', 'reference')
    changed = git('diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines()
    assert changed in [[BACKEND], sorted([BACKEND, PUBLICATION])], 'unknown production mutation'
    assert git('rev-parse', 'HEAD:reference') == git('rev-parse', BASE + ':reference')
    old = subprocess.check_output(['git', 'show', BASE + ':' + BACKEND], cwd=ROOT)
    new = (ROOT / BACKEND).read_bytes()
    validate_change(old, new)
    assert git('rev-parse', 'HEAD:' + BACKEND) == POSTIMAGE
    publication = (ROOT / PUBLICATION).read_bytes()
    if PUBLICATION in changed:
        validate_publication_change(subprocess.check_output(
            ['git', 'show', BASE + ':' + PUBLICATION], cwd=ROOT), publication)
    else:
        assert blob(publication) == PUBLICATION_PREIMAGE
    assert git('rev-parse', 'HEAD:' + PUBLICATION) == blob(publication)
    return {'baseline': BASE, 'backend_preimage': PREIMAGE,
            'backend_postimage': POSTIMAGE, 'source_tree': git('rev-parse', 'HEAD:src'),
            'publication_postimage': blob(publication), 'changed_paths': changed,
            'scope': 'source eligibility only; fresh owner and coupling science required'}


if __name__ == '__main__':
    import json
    print(json.dumps(verify_source(), sort_keys=True))
