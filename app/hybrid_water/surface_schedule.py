"""Preserve the original full-period input domain for a scheduled pond threshold."""
POLICY='original-full-period-pond-table-validation-v1'


def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWPONDMX']==1


def render_readswap(source,original_start_clock):
    import math
    if not math.isfinite(original_start_clock):raise ValueError('Invalid original validation clock')
    anchor="call checkdate(ifnd,datepmx,tend,tstart,'datepmx ', 'readswap/swpondmx=1')"
    if source.count(anchor)!=1:raise ValueError('Changed original pond threshold table validation anchor')
    return source.replace(anchor,
        f"call checkdate(ifnd,datepmx,tend,{original_start_clock:.17g}d0,'datepmx ', 'readswap/swpondmx=1')")
