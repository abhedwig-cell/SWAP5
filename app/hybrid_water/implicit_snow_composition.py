"""Bounded existing implicit/Snow composition; source closure precedes models."""
import hashlib
from pathlib import Path

POLICY='original-implicit-snow-existing-provider-composition-v1'


def input_domain(selectors,boundary,original_output):
    bottom=boundary.get('SWBOTB');drain=selectors.get('SWDRA')
    return bool(original_output is not False and selectors.get('SWKIMPL')==1 and
                selectors.get('SWSNOW')==1 and selectors.get('SWSOLU') in (0,1) and
                bottom in (1,5,8) and drain in (0,1) and (bottom==1 or drain==1))


def source_identity():
    return dict(implicit_snow_composition=True,implicit_snow_policy=POLICY,
                implicit_snow_composition_source_sha256=hashlib.sha256(
                    Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())
# Deliberately foreign actual source; negative branch must never merge.
