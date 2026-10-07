program test_swap431_hyd_analytical
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_analytical_hydraulic_provider, only: b111_analytical_hydraulic_parameters_t, &
       b111_analytical_hydraulic_provider_t, initialize_b111_analytical_hydraulic_parameters, &
       bind_b111_analytical_hydraulic_provider, B111_HYD_EXPONENTIAL, B111_HYD_BIMODAL_MVG, &
       B111_HYD_BIMODAL_MVG_WCK
  implicit none
  type(b111_analytical_hydraulic_parameters_t), target :: parameters, parameters6
  type(b111_analytical_hydraulic_provider_t) :: provider, provider6
  real(real64) :: cofgen(16,2), head(2), theta(2), conductivity(2), capacity(2), dkdh(2)
  real(real64) :: eps, kplus, kminus, cofgen6(16,1), head6(1), theta6(1), conductivity6(1), capacity6(1), dkdh6(1)
  integer :: model_kind(2), model_kind6(1)
  logical :: available

  cofgen=0.0_real64
  model_kind=[B111_HYD_EXPONENTIAL,B111_HYD_BIMODAL_MVG]
  cofgen(1,:)=[0.05_real64,0.05_real64]
  cofgen(2,:)=[0.45_real64,0.45_real64]
  cofgen(3,:)=[10.0_real64,12.0_real64]
  cofgen(4,:)=[0.02_real64,0.015_real64]
  cofgen(5,:)=[0.5_real64,0.5_real64]
  cofgen(6,:)=[2.0_real64,1.8_real64]
  cofgen(7,:)=[0.5_real64,1.0_real64-1.0_real64/1.8_real64]
  cofgen(13,2)=0.05_real64
  cofgen(14,2)=2.2_real64
  cofgen(15,2)=1.0_real64-1.0_real64/2.2_real64
  cofgen(16,2)=0.65_real64

  call initialize_b111_analytical_hydraulic_parameters(parameters,model_kind,cofgen)
  call bind_b111_analytical_hydraulic_provider(provider,parameters)

  head=[-100.0_real64,-75.0_real64]
  call provider%evaluate(head,theta,conductivity,capacity,dkdh)
  call assert_close(theta(1),0.05_real64+0.4_real64*exp(-2.0_real64),1.0e-13_real64,'model2 theta')
  call assert_close(conductivity(1),10.0_real64*(theta(1)-0.05_real64)/0.4_real64,1.0e-13_real64,'model2 K')
  call assert_close(capacity(1),0.02_real64*0.4_real64*exp(-2.0_real64),1.0e-13_real64,'model2 C')
  call assert_close(dkdh(1),0.02_real64*10.0_real64*exp(-2.0_real64),1.0e-13_real64,'model2 dKdh')

  eps=1.0e-5_real64
  call provider%evaluate_point_conductivity(2,head(2)+eps,0.0_real64,kplus,available)
  if(.not.available) error stop 'model3 point K plus unavailable'
  call provider%evaluate_point_conductivity(2,head(2)-eps,0.0_real64,kminus,available)
  if(.not.available) error stop 'model3 point K minus unavailable'
  call assert_close(dkdh(2),(kplus-kminus)/(2.0_real64*eps), &
       2.0e-7_real64*max(1.0_real64,abs(dkdh(2))),'model3 derivative oracle')

  head=[0.0_real64,0.0_real64]
  call provider%evaluate(head,theta,conductivity,capacity,dkdh)
  call assert_close(theta(2),0.45_real64,0.0_real64,'model3 saturated theta')
  call assert_close(conductivity(2),12.0_real64,0.0_real64,'model3 saturated K')
  call assert_close(capacity(2),0.0_real64,0.0_real64,'model3 saturated C')
  call assert_close(dkdh(2),1.0e-12_real64,0.0_real64,'model3 saturated dKdh')

  ! Legacy selector 6 is the WC_K representation of the same unscaled bimodal MvG family as selector 3.
  cofgen6=cofgen(:,2:2); model_kind6=[B111_HYD_BIMODAL_MVG_WCK]
  call initialize_b111_analytical_hydraulic_parameters(parameters6,model_kind6,cofgen6)
  call bind_b111_analytical_hydraulic_provider(provider6,parameters6)
  head=[-75.0_real64,-75.0_real64]
  call provider%evaluate(head,theta,conductivity,capacity,dkdh)
  head6=[-75.0_real64]
  call provider6%evaluate(head6,theta6,conductivity6,capacity6,dkdh6)
  call assert_close(theta6(1),theta(2),0.0_real64,'model6/model3 theta identity')
  call assert_close(conductivity6(1),conductivity(2),0.0_real64,'model6/model3 K identity')
  call assert_close(capacity6(1),capacity(2),0.0_real64,'model6/model3 C identity')
  call assert_close(dkdh6(1),dkdh(2),0.0_real64,'model6/model3 dKdh identity')
  print '(a)','PASS swap431 hyd analytical'
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
