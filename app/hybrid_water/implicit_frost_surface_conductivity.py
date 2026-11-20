"""Proposed Frost mean inputs; public/build selection remains closed.

Reuse the qualified ordinary implicit pond chain rule. Match the actual
original Boundtop conductivity inputs, for fitted Ksat only. This renderer
changes no physical equation, state, convergence or conservation criterion.
"""

POLICY = 'original-implicit-frost-exact-surface-conductivity-v1'
IMPORT_ANCHOR = '   use MOD_top,only:katm'
FLOOR_IMPORT = '   use MOD_MvG,only:hconode_vsmall\n'
EDITS = tuple(('k(1),' + value + ',dz(1)',
              'k(1),' + value + '*rfcp(1)+hconode_vsmall*(1d0-rfcp(1)),dz(1)')
             for value in ('katm', 'ksatfit(1)'))


def source(text):
    if text.count(IMPORT_ANCHOR) != 1 or 'ordinary_implicit_top_jacobian' not in text:
        raise ValueError('Missing qualified ordinary implicit surface composition')
    if FLOOR_IMPORT in text:
        raise ValueError('Ambiguous Frost surface conductivity import')
    for before, after in EDITS:
        if text.count(before) != 2 or after in text:
            raise ValueError('Foreign actual implicit surface mean input')
        text = text.replace(before, after)
    return text.replace(IMPORT_ANCHOR, FLOOR_IMPORT + IMPORT_ANCHOR, 1)


def restore(actual):
    if actual.count(FLOOR_IMPORT) != 1:
        raise ValueError('Foreign actual Frost conductivity floor provider')
    for before, after in reversed(EDITS):
        if actual.count(after) != 2 or before in actual:
            raise ValueError('Foreign actual Frost mean-input source')
        actual = actual.replace(after, before)
    return actual.replace(FLOOR_IMPORT, '', 1)


def validate(actual, original):
    if restore(actual) != original:
        raise ValueError('Qualified complete original implicit source changed')
