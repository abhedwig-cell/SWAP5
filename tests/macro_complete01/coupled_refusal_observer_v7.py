"""Pure original-context observation after corrected perched classification."""
from coupled_refusal_observer_v6_geometry import render_head as base

def render_head(source):
    return base(source).replace('35797.504d0','35797.121d0').replace('35797.506d0','35797.123d0')
