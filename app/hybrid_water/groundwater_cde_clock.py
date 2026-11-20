"""Compose existing CDE clocks with original groundwater reaction and state.

No process equation or physical state is added. Distinct codec names prevent
the longer existing CDE interval tail from aliasing the old daily-only layout.
"""


def magic(project):
    from cde_clock_output import active_selection
    selected=active_selection(project)
    if selected is None or not selected.get('groundwater_cde_clock'):
        return None
    if selected.get('groundwater_snow_cde_output'):
        from groundwater_snow_cde import magic as snow_magic
        return snow_magic(selected,True)
    history=selected['swhyst']
    return b'S5GCC001' if history==0 else ('S5GCH'+f'{2*history-1:03d}').encode()


def trial_source(original,watstor):
    from age_groundwater_output import trial_source as original_groundwater_trial
    source=original_groundwater_trial(original,watstor)
    source=source.replace('hybrid_groundwater_age_trial','hybrid_groundwater_cde_clock_trial')
    return source.replace('Original AGE groundwater trial domain','Original CDE groundwater clock trial domain')


def integral(source,original,watstor,selected=None):
    start='real(8) function hybrid_ordinary_trial_residual('
    if selected is not None and selected.get('groundwater_snow_cde_output'):
        from groundwater_snow_cde import trial_source as snow_trial
        start='real(8) function hybrid_snow_soil_trial_residual('
        trial=snow_trial(original,watstor,selected)
    else:trial=trial_source(original,watstor)
    assert source.count(start)==1
    first=source.index(start);last=source.index('\nend function',first)+len('\nend function')
    return source[:first]+trial+source[last:]
