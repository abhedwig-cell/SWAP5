"""Extend the real Frost rate fixture with literal production CDE task2 calls."""


def source(text):
    text = text.replace('  use,intrinsic::ieee_arithmetic', '''  use MOD_Solute,only:solute_CDE,frost_cde_probe_exponent,cml,cmsy,sampro,sqdra,imsqdra,sqbot,imsqbot,sbaldev
  use MOD_grid,only:numlay,inpola,inpolb
  use MOD_meteo,only:nraidt
  use MOD_irrigation,only:nird,cirr
  use MOD_swap_mp,only:armpss
  use MOD_SoilTemperature,only:tsoil
  use MOD_swap_base,only:swhea
  use variables,only:q,qtop,qrot,dt,dtmin,pond,flzerointr,flzerocumu
  use,intrinsic::ieee_arithmetic''', 1)
    text = text.replace('  integer::profile', '''  real(8)::before_mass(4),before_cml(4),initial_total,exponents(3)
  integer::exponent_index
  integer::profile''', 1)
    text = text.replace('  cases=0\n', '''  cases=0
  exponents=[0.5d0,1d0,2d0]
  numlay=2;swhea=1
  do exponent_index=1,3
  frost_cde_probe_exponent=exponents(exponent_index)
''', 1)
    anchor = '            cases=cases+1\n'
    added = '''            ! Supply the actual Frost-projected lower and lateral fluxes.
            ! Task97 only initializes private chemical fixture state; task2 is literal production.
            theta(5)=theta(4);inpola=0.5d0;inpolb=0.5d0
            tsoil(1:4)=temperature(1:4)
            q=0d0;q(5)=qbot;qtop=0d0;qrot=0d0
            dt=0.025d0;dtmin=1d-8;pond=0d0
            nraidt=0d0;nird=0d0;cirr=0d0;armpss=0d0
            flzerointr=.true.;flzerocumu=.true.
            cml(1:4)=[0.01d0,0.02d0,0.03d0,0.04d0]
            call solute_CDE(97)
            before_mass=cmsy(1:4);before_cml=cml(1:4);initial_total=sampro
            call solute_CDE(2)
            if(.not.all(ieee_is_finite([cmsy(1:4),cml(1:4),sampro,sqdra,imsqdra,sqbot,imsqbot,sbaldev]))) &
              error stop 'Nonfinite actual CDE task2 output'
            if(abs(sbaldev)>1d-10)error stop 'Actual CDE intermediate mass balance failed'
            if(any(cmsy(1:4)<=0d0))error stop 'Nonpositive actual CDE component mass'
'''
    assert text.count(anchor) == 1
    text = text.replace(anchor, added + anchor + '''            write(*,'(a,2(1x,i0),*(1x,es25.17e3))')'ACTUAL_FROST_CDE_TASK2',cases,levels, &
              frost_cde_probe_exponent,dt,qbot,initial_total,sampro,sqdra,imsqdra,sqbot,imsqbot,sbaldev, &
              before_mass,before_cml,cmsy(1:4),cml(1:4),qdra(1:levels,1:4)
''', 1)
    text = text.replace("  if(cases/=84)", "  end do\n  if(cases/=252)", 1)
    text = text.replace('ACTUAL_FROZENBOUNDS_DIVDRA_84_RATE_INTERFACE_CASES_PASS_NOT_CDE_QUALIFIED',
                        'ACTUAL_FROZENBOUNDS_DIVDRA_CDE_TASK2_252_COMPONENT_CASES_PASS_NOT_MODEL_QUALIFIED')
    return text
