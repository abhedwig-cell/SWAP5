"""Verification-only output of actual original private Divdra bookkeeping."""

ANCHOR='               KDuns = KDtot - KDsat\n'
OBSERVATION="""               write(*,'(a,5(1x,i0),*(1x,es25.17e3))')'ACTUAL_DIVDRA_INFILTRATION_BOOKKEEPING', &
                idr,icpbotdislay(idr),icpwlev,icpslev,numnod,gwlev,wlev,dmaxdislay(idr), &
                dzcpwlevsat,dzcpbotdislay(idr),dz(icpwlev),Khor(icpwlev),KDtot,KDsat,KDuns, &
                qdrain(idr),dzcpslevsat,drainl(idr)
               flush(6)
"""


def source(text):
    assert text.count(ANCHOR)==1 and 'ACTUAL_DIVDRA_INFILTRATION_BOOKKEEPING' not in text
    result=text.replace(ANCHOR,ANCHOR+OBSERVATION,1)
    assert result.replace(OBSERVATION,'',1)==text
    return result
