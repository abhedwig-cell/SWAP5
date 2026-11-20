"""Retain modeled positive CDE cell mass below the old concentration cutoff.

The conservation update, fluxes and adsorption iteration remain literal. No
mass is added back and the original nonpositive-state handling is retained.
The bounded composition owner decides where this correction is installed.
"""
POLICY='original-cde-preserve-positive-cell-mass-v1'


def source(text):
    old='               if (cmsy(i) < vsmall) then'
    if text.count(old)!=1:raise ValueError('Changed original CDE positive-tail cutoff')
    return text.replace(old,'               if (cmsy(i) <= 0d0) then',1)
