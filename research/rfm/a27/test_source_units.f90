program test_a27_source_units
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_EXPLICIT_FLUX
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 use mod_rfm_matrix_source_provider,only:rfm_matrix_source_provider_t,bind_rfm_matrix_source_provider
 implicit none
 real(real64),parameter::dt=1e-3_real64,tol=1e-10_real64
 type(soil_water_parameter_set_t),target::params
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::base
 type(rfm_matrix_source_provider_t),target::rfm
 type(fixed_flux_top_boundary_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::w0,w1,w2
 type(soil_water_solve_request_t)::q,q0,q1,q2
 type(soil_water_solve_result_t)::r0,r1,r2
 real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:),source(:)
 real(real64),allocatable::cofgen(:,:),h0(:),t0(:)
 real(real64)::cond(numnod),cap(numnod),dkdh(numnod)
 real(real64)::amount,receipt,delta,bottom,duration
 integer::i,node
 logical::ok
 allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
 params%parameter_set_id=526_int64;params%active_nodes=numnod;params%z=z;params%dz=dz;params%node_distance=disnod(1:numnod)
 cofgen=0.0_real64
 do i=1,numnod
  cofgen(1,i)=0.02_real64;cofgen(2,i)=0.427494_real64;cofgen(3,i)=31.225016_real64
  cofgen(4,i)=0.021659_real64;cofgen(5,i)=0.98087_real64;cofgen(6,i)=1.734737_real64
  cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i);cofgen(10,i)=cofgen(3,i)
  cofgen(11,i)=0.999_real64;cofgen(12,i)=0.99_real64*cofgen(3,i);cofgen(22,i)=-1e6_real64;cofgen(23,i)=1e-12_real64
 end do
 call initialize_b110_default_mvg_parameters(hp,cofgen);call bind_b110_default_mvg_provider(hyd,hp,dt)
 allocate(h0(numnod),t0(numnod));h0=-100.0_real64;call hyd%evaluate(h0,t0,cond,cap,dkdh)
 allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod),source(numnod));qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64;source=0.0_real64
 call bind_b110_source_sink_provider(base,qdra,qssdi,qrot)
 node=max(1,numnod/2);amount=.02_real64;source(node)=amount/(dz(node)*dt)
 call bind_rfm_matrix_source_provider(rfm,base,source,ok);if(.not.ok)error stop 'bind'
 q%parameters=>params;q%base_state%active_nodes=numnod
 allocate(q%base_state%pressure_head(numnod),q%base_state%water_content(numnod));q%base_state%pressure_head=h0;q%base_state%water_content=t0
 q%base_state%ponding_depth=0.0_real64;q%base_state%groundwater_level=-200.0_real64
 q%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;q%boundary%bottom_mode=7;q%boundary%top_flux=0.0_real64;q%boundary%bottom_head=-100.0_real64
 q%physical%macropore_active=.false.;q%numerical%max_iterations=64;q%numerical%max_backtracking=24
 q%numerical%conductivity_implicit_mode=0;q%numerical%conductivity_mean_method=1;q%numerical%min_step_duration=1e-12_real64
 q%numerical%compartment_balance_tolerance=tol;q%numerical%total_balance_tolerance=tol;q%numerical%head_abs_tolerance=tol
 q%numerical%head_rel_tolerance=tol;q%numerical%ponding_tolerance=tol;q%evaluation%constitutive=>hyd;q%evaluation%top_boundary=>top;q%step_duration=dt
 q0=q;q0%evaluation%source_sink=>base;q1=q;q1%evaluation%source_sink=>rfm;q2=q;q2%evaluation%source_sink=>rfm
 call solver%solve(q0,w0,r0);call solver%solve(q1,w1,r1);call solver%solve(q2,w2,r2)
 if(r0%status/=SW_SOLVE_CONVERGED.or.r1%status/=SW_SOLVE_CONVERGED.or.r2%status/=SW_SOLVE_CONVERGED)error stop 'converge'
 if(all(transfer(r1%candidate_state%water_content,[0_int64],numnod)==transfer(r0%candidate_state%water_content,[0_int64],numnod)))error stop 'source no effect'
 if(any(transfer(r1%candidate_state%water_content,[0_int64],numnod)/=transfer(r2%candidate_state%water_content,[0_int64],numnod)))error stop 'replay theta'
 if(any(transfer(r1%candidate_state%pressure_head,[0_int64],numnod)/=transfer(r2%candidate_state%pressure_head,[0_int64],numnod)))error stop 'replay head'
 if(any(transfer(q%base_state%pressure_head,[0_int64],numnod)/=transfer(h0,[0_int64],numnod)))error stop 'accepted head'
 if(.not.r1%integrated_mass_balance_residual_available.or.abs(r1%integrated_mass_balance_residual_cm)>tol)error stop 'mass'
 delta=sum((r1%candidate_state%water_content-r0%candidate_state%water_content)*dz)
 bottom=(r1%bottom_flux-r0%bottom_flux)*dt
 receipt=delta-bottom
 print '(a)','intended_transfer_cm,cell_thickness_cm,measured_matrix_receipt_cm,expected_existing_receipt_cm'
 print '(4(es24.16,:,","))',amount,dz(node),receipt,amount/dz(node)
 if(abs(receipt-amount/dz(node))>1e-8_real64)error stop 'units probe oracle'
 if(abs(receipt-amount)<1e-4_real64)error stop 'dimension defect not exposed'
 print '(a)','A27_SOURCE_UNIT_MISMATCH_REPRODUCED=PASS' 
end program
