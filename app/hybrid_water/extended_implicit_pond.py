"""Compose the original implicit soil derivative with qualified pond response.

Not selected by an input route until its integrated owner is qualified.
The existing explicit tangent remains byte-for-byte in emitted source.
"""
import hashlib

ORIGINAL_TANGENT_SHA='f2414f18203ecfcdf986a1a8e23cb4910654dea73cdc770411bc159672506421'
FUNCTION='extended_implicit_top_jacobian'


def render(source):
    start='real(8) function extended_pond_top_jacobian(conductance,step) result(tangent)'
    assert source.count(start)==1
    first=source.index(start);last=source.index('\nend function',first)+len('\nend function')
    original=source[first:last]
    if hashlib.sha256(original.encode('cp1252')).hexdigest()!=ORIGINAL_TANGENT_SHA:
        raise ValueError('Changed qualified original extended pond tangent provider')
    current=original.replace('extended_pond_top_jacobian(conductance,step)',FUNCTION+'(conductance,soil_partial,step)',1)
    current=current.replace('real(8),intent(in)::conductance,step','real(8),intent(in)::conductance,soil_partial,step',1)
    old='tangent=conductance*(1d0+slope)/(1d0+step*conductance+slope)'
    assert current.count(old)==1
    current=current.replace(old,'tangent=soil_partial*(1d0+slope)/(1d0+step*conductance+slope)',1)
    anchor='end module MOD_top';assert source.count(anchor)==1
    source=source.replace(anchor,current+'\n'+anchor,1)
    anchor='public :: pondrunoff, q0, FlRunoff, ftoph, hsurf'
    assert source.count(anchor)==1
    return source.replace(anchor,anchor+', '+FUNCTION,1)
