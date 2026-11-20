"""Verification-only private initialization; production Solute_CDE(2) is literal.

Task97 initializes an explicit four-cell chemical fixture. It never performs
transport or drainage calculations. Removing the two unique insertions restores
the complete supplied original/corrected source byte for byte (LF text).
"""


def source(text):
    declaration = '   public :: solute_CDE, calc_AgeTracer'
    added = ('   real(8),save::frost_cde_probe_exponent=1d0\n'
             '   public::frost_cde_probe_exponent\n')
    assert text.count(declaration) == 1
    anchor = '      select case (task)\n      case (1)'
    start = text.index('submodule (MOD_Solute) MOD_Solute_CDE')
    end = text.index('      end subroutine solute_CDE', start)
    assert text[start:end].count(anchor) == 1
    setup = '''      case (97)
         if(.not.allocated(ldis))allocate(ldis(numlay))
         if(.not.allocated(thetav))allocate(thetav(numnod),diffus(numnod),dispr1(numnod),vpore2(numnod))
         if(.not.allocated(ddiffwcs))allocate(ddiffwcs(numnod),bdenskf(numnod),bdenskfcref(numnod),decpotfdepth(numnod))
         ldis=0d0;ddiffwcs=0d0;decpotfdepth=0d0
         bdenskf=0.2d0;bdenskfcref=0.2d0;cref=1d0
         frexp=frost_cde_probe_exponent
         swbotbc=0;swbr=0;swsba=0
         bexp=1d0;rtheta=0.2d0;gampar=0d0;tscf=0d0
         cdrain=0.007d0;cseep=0.011d0;cpre=0d0;csurf=0d0;cpond=0d0
         dectot=0d0;imdectot=0d0;rottot=0d0;imrottot=0d0
         sqbot=0d0;imsqbot=0d0;sqdra=0d0;imsqdra=0d0
         sqirrig=0d0;imsqirrig=0d0;sqprec=0d0;imsqprec=0d0;sqsur=0d0
         imqsol=0d0;rounderr=0d0
         do i=1,numnod
            cmsy(i)=theta(i)*cml(i)+bdenskfcref(i)*(cml(i)/cref)**frexp
         end do
         samini=sum(cmsy(1:numnod)*dz(1:numnod))
         sampro=samini;sampro0=samini
         return
'''
    actual = text.replace(declaration, added + declaration, 1)
    insertion = actual.index(anchor, actual.index('submodule (MOD_Solute) MOD_Solute_CDE'))
    actual = actual[:insertion] + actual[insertion:].replace(anchor, '      select case (task)\n' + setup + '      case (1)', 1)
    assert actual.replace(added, '', 1).replace(setup, '', 1) == text
    return actual
