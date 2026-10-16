program test_swap431_hyd_power
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_hconduc, b110_default_mvg_parameters_t, &
       b110_default_mvg_provider_t, initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: provider
  real(real64) :: c(42), cofgen(24,1), h, theta, kbase, kpower, expected, relsat, term1
  real(real64) :: heads(1), water(1), conductivity(1), capacity(1), dkdh(1)
  c=0.0_real64
  c(1)=0.05_real64; c(2)=0.45_real64; c(3)=10.0_real64
  c(4)=0.02_real64; c(5)=0.5_real64; c(6)=2.0_real64; c(7)=0.5_real64
  c(9)=0.0_real64; c(22)=-100.0_real64
  c(25)=c(2)-c(1); c(32)=1.0_real64/c(7); c(33)=c(6)*(2.0_real64+c(7)*c(5))
  h=c(22)
  theta=c(1)+c(25)/(1.0_real64+abs(c(4)*h)**c(6))**c(7)
  relsat=(theta-c(1))/c(25)
  term1=(1.0_real64-relsat**c(32))**c(7)
  c(23)=c(3)*relsat**c(5)*(1.0_real64-term1)**2

  kbase=b110_hconduc(c,h,theta,.false.)
  kpower=b110_hconduc(c,h,theta,.false.,.true.)
  call assert_close(kbase,c(23),1.0e-13_real64,'continuity base')
  call assert_close(kpower,c(23),1.0e-13_real64,'continuity power')

  h=-1000.0_real64
  theta=c(1)+c(25)/(1.0_real64+abs(c(4)*h)**c(6))**c(7)
  expected=c(23)*(abs(c(22))/abs(h))**c(33)
  kpower=b110_hconduc(c,h,theta,.false.,.true.)
  call assert_close(kpower,expected,1.0e-13_real64,'dry power tail')

  kbase=b110_hconduc(c,h,theta,.false.)
  if (abs(kbase-kpower)<=1.0e-14_real64) error stop 'power-disabled preservation not discriminated'

  ! The demand-specific provider path must carry the same power-tail option.
  cofgen(:,1)=c(1:24)
  call initialize_b110_default_mvg_parameters(parameters,cofgen,enable_conductivity_power_tail=.true.)
  call bind_b110_default_mvg_provider(provider,parameters,1.0_real64)
  heads=[h]; water=0.0_real64; conductivity=0.0_real64; capacity=0.0_real64; dkdh=0.0_real64
  call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_CONDUCTIVITY+CONSTITUTIVE_DEMAND_CAPACITY, &
       water,conductivity,capacity,dkdh)
  call assert_close(conductivity(1),expected,1.0e-13_real64,'demand K+capacity power tail')
  call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_CONDUCTIVITY,water,conductivity,capacity,dkdh)
  call assert_close(conductivity(1),expected,1.0e-13_real64,'demand K power tail')
  print '(a)','PASS swap431 hyd power'
contains
  subroutine assert_close(actual,expected,tolerance,label)
    real(real64),intent(in)::actual,expected,tolerance
    character(len=*),intent(in)::label
    if(abs(actual-expected)>tolerance)then
      write(*,'(a,2es24.16)') trim(label)//' mismatch ',actual,expected
      error stop 1
    end if
  end subroutine
end program
