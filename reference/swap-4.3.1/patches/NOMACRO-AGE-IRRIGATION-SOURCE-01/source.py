"""Explicit current fixed irrigation age; original capture defect is separate."""
from pathlib import Path
import hashlib

ORIGINAL='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
BASE_ADAPTER='5c7f3654c323dae8c3e5f70cd12b4359eda3ecef771cad6afa37a0c16be642e7'
POLICY='original-fixed-current-irrigation-age-days-v1'


def source(original):
    if hashlib.sha256(original).hexdigest()!=ORIGINAL:raise ValueError('Foreign original fixed age source')
    text=original.decode('cp1252').replace('\r\n','\n');first=text.index('submodule (MOD_Solute) MOD_calc_AgeTracer');last=text.index('end submodule MOD_calc_AgeTracer',first)
    before,body,after=text[:first],text[first:last],text[last:]
    anchor='! === calculate Solute rate variables ========================'
    if body.count(anchor)!=1:raise ValueError('Changed original age source capture boundary')
    return (before+body.replace(anchor,anchor+'\n         Ageirr=cirr\n',1)+after).encode('cp1252')


def adapter(rendered):
    base=Path(__file__).parents[1]/'NOMACRO-AGE-SOURCE-01/source.py'
    if hashlib.sha256(base.read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=BASE_ADAPTER:raise ValueError('Changed admitted original age adapter')
    text=rendered.decode('cp1252').replace('\r\n','\n')
    anchor='         age_surface%irrigation_age_day=Ageirr'
    if text.count(anchor)!=1:raise ValueError('Changed actual age surface forcing boundary')
    # Keep static saved native parameters literal. Actual event age belongs to
    # the complete original irrigation state and is consumed at this handoff.
    return text.replace(anchor,'         age_surface%irrigation_age_day=cirr\n         call hybrid_age_irrigation_source_assert(cirr)',1).encode('cp1252')
