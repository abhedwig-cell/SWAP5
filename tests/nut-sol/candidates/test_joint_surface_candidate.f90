program test_joint_surface_candidate
 use iso_fortran_env,only:real64
 use mod_b111_surface_receipt_gate
 use mod_b111_surface_joint_candidate
 implicit none
 type(surface_gross_receipt_t)::w
 type(joint_candidate_receipt_t)::a,b
 real(real64)::start,total_input,total_export
 w%accepted=.true.;w%gross_available=.true.
 w%t0=0d0;w%t1=1d0;w%depth_begin=1d0;w%rain=0.4d0;w%runon=0.2d0
 w%irrigation=0.1d0;w%qtop=-0.3d0;w%evaporation=0.2d0;w%runoff=0.1d0
 w%depth_end=1.1d0
 start=2d0
 call evaluate_joint_surface_candidate(w,start,1d0,2d0,3d0,0.05d0,a)
 if(a%status/=JOINT_CANDIDATE_OK)error stop 'first substep'
 if(abs(a%mass_end+a%soil_input+a%runoff_export-start-a%external_input)>1d-11)error stop 'first balance'
 w%t0=1d0;w%t1=2d0;w%depth_begin=1.1d0
 w%rain=0d0;w%runon=0d0;w%irrigation=0d0;w%evaporation=0.3d0;w%qtop=-0.4d0;w%runoff=0.1d0
 w%depth_end=0.3d0
 call evaluate_joint_surface_candidate(w,a%mass_end,0d0,0d0,0d0,0d0,b)
 if(b%status/=JOINT_CANDIDATE_OK)error stop 'second substep'
 total_input=a%external_input+b%external_input
 total_export=a%soil_input+a%runoff_export+b%soil_input+b%runoff_export
 if(abs(b%mass_end+total_export-start-total_input)>1d-11)error stop 'whole mass'
 w%gross_available=.false.
 call evaluate_joint_surface_candidate(w,a%mass_end,0d0,0d0,0d0,0d0,b)
 if(b%status/=JOINT_CANDIDATE_REJECTED)error stop 'missing source accepted'
 w%gross_available=.true.;w%depth_end=0.4d0
 call evaluate_joint_surface_candidate(w,a%mass_end,0d0,0d0,0d0,0d0,b)
 if(b%status/=JOINT_CANDIDATE_REJECTED)error stop 'bad water accepted'
 print '(a)','JOINT_SURFACE_CANDIDATE_PASS'
end program
