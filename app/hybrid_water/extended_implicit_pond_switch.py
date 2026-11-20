"""Continuous zero-pond switch for implicit secondary-only drainage.

The original positive-head deadband makes the soil residual discontinuous.
Keep the original pond equation and select its existing positive-pond branch
at zero. This reference correction needs separate numerical qualification.
"""


def source(text):
    old = '      if (h0 <= 1.0d-6) then'
    if text.count(old) != 1:
        raise ValueError('Changed original zero-pond boundary switch')
    return text.replace(old, '      if (h0 <= 0.0d0) then', 1)


def enabled(project):
    from extended_drainage import selection
    selected = selection(project)
    return bool(selected and selected.get('swkimpl') and selected['swsrf'] == 2)
