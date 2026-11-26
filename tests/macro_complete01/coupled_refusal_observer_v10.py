"""Pure observation of current incoming projection at the next refusal."""
from coupled_refusal_observer_v6_geometry import render_head as base

def render_head(source):
    return base(source).replace('35797.504d0','35797.697d0').replace('35797.506d0','35797.699d0')
