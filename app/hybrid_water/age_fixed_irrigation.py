"""Explicit original young-water fixed input contract; no age equation."""
from pathlib import Path
import hashlib

POLICY='original-fixed-young-water-age-zero-days-v1'


def enabled(project):
    if not project.age or not project.input_directory or project.macro:return False
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWIRFIX']==1


def metadata():
    return dict(policy=POLICY,irrigation_age_day=0.,units='days',
                source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())


def render_irrigation(source):
    anchor='      subroutine read_irrigation_fixed()'
    read="         if (swsolu > 0) call rdfdor ('irconc',0.d0,1000.d0,irconc,mairg,ifnd)"
    if source.count(anchor)!=1 or source.count(read)!=1:raise ValueError('Changed original fixed age reader')
    source=source.replace(anchor,anchor+'\n         use,intrinsic::ieee_arithmetic,only:ieee_is_finite')
    return source.replace(read,read+"""
         if(swsolu==2)then
            if(.not.all(ieee_is_finite(irconc(1:ifnd))))error stop 'Nonfinite original fixed young-water age input'
            if(any(abs(irconc(1:ifnd))>0d0))error stop 'Fixed original age input requires zero-day young water'
         end if""")
