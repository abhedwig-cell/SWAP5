"""Preserve positive original interception in the selected extended domain."""

def render(source):
    old='      use MOD_params,      only: small\n      use plant_interface, only: sw_inter'
    assert source.count(old)==1
    source=source.replace(old,'      use MOD_swap_base,only:swmacro,swdra\n'+old,1)
    old='      if (aintcdt < small) then'
    assert source.count(old)==1
    return source.replace(old,'''      if (aintcdt < small.and..not.(swmacro==0.and.swdra==2.and.aintcdt>0d0)) then''',1)
