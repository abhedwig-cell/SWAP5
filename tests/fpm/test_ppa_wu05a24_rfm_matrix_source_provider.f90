program test_ppa_wu05a24_rfm_matrix_source_provider
 use, intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:source_sink_provider_t
 use mod_rfm_matrix_source_provider
 implicit none
 type,extends(source_sink_provider_t)::base_t
 contains
  procedure::evaluate=>base_eval
 end type
 type(base_t),target::base
 type(rfm_matrix_source_provider_t)::rfm
 real(real64),target::extra(3)
 real(real64)::h(3),theta(3),src(3),snk(3),src2(3),snk2(3)
 logical::ok
 h=-100.0_real64;theta=0.2_real64;extra=[0.0_real64,0.02_real64,0.03_real64]
 call bind_rfm_matrix_source_provider(rfm,base,extra,ok)
 if(.not.ok)error stop 'A24 bind'
 call rfm%evaluate(h,theta,src,snk)
 call rfm%evaluate(h,theta,src2,snk2)
 if(maxval(abs(src-[0.1_real64,0.22_real64,0.33_real64]))>1e-15_real64)error stop 'A24 source'
 if(maxval(abs(snk-[0.01_real64,0.02_real64,0.03_real64]))>1e-15_real64)error stop 'A24 sink'
 if(any(src/=src2).or.any(snk/=snk2))error stop 'A24 replay'
 extra(1)=-1.0_real64
 call bind_rfm_matrix_source_provider(rfm,base,extra,ok)
 if(ok)error stop 'A24 negative accepted'
 print '(a)','PPA_WU05A24_RFM_MATRIX_SOURCE_PROVIDER=PASS'
contains
 subroutine base_eval(self,pressure_head,water_content,source,sink)
  class(base_t),intent(in)::self
  real(real64),intent(in)::pressure_head(:),water_content(:)
  real(real64),intent(out)::source(:),sink(:)
  source=[0.1_real64,0.2_real64,0.3_real64]
  sink=[0.01_real64,0.02_real64,0.03_real64]
  if(.not.same_type_as(self,self).or.size(pressure_head)/=3.or.size(water_content)/=3)error stop 'base'
 end subroutine
end program
