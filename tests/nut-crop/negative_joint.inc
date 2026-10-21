 ! This fixture uses the existing real crop owner at its harvest boundary,
 ! then advances actual Richards and the same retained Soil-N owner in fallow.
 subroutine negative_joint()
  type(crop_soil_harvest_receipt_t)::hr
  type(crop_soil_harvest_observation_t)::ho
  type(crop_soil_n_joint_result_t)::r,rejected
  type(fmr_b110_physical_forcing_t)::forcing,harder
  type(soil_n_day_environment_t)::e,stale
  real(real64)::ledger(15),before,scale,initial_n(2),source,whole_residual
  integer::first,d,u,code
  character(32)::arg
  logical::high,bounded
  high=trim(selected)=='negative-high'
  sp%mineral%c_top=[.002d0,.005d0];sp%mineral%c_bottom=0d0;sp%mineral%c_lateral=0d0
  sp%organic_reference%ratecon_fom=0d0;sp%organic_reference%ratecon_hum=0d0
  sp%environment%nitrification_ref_per_day=.2d0;sp%environment%denitrification_ref_per_day=.25d0
  sp%environment%cdissi_half_kg_m2=1d-12
  cp%harvest%crop_end=-1d0
  cfg%tiles(1)%base_forcing%bottom_flux=0d0
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=0d0
  cfg%tiles(1)%base_forcing%root_extraction_sink=0d0
  cfg%tiles(1)%base_forcing%root_potential_transpiration=0d0
  call get_command_argument(5,arg)
  first=0;ledger=0d0
  if(trim(mode)=='resume')then
   read(arg,*)first
   call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
        670001_int64,9001_int64,9101_int64,sp,cp,water,state,code)
   call require(code==0,'negative native process reconstructs complete owners')
   open(newunit=u,file=trim(path)//'.ledger',status='old',form='unformatted',access='stream')
   read(u)ledger;close(u)
  else
   call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state, &
        0d0,ok,spread(0d0,1,numnod))
   call require(ok,'negative real Richards initial state')
   theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
   initial_n=[1d-5,2d-5]
   if(high)initial_n=[.001d0,.002d0]
   call initialize_soil_n_pool_state(sp%mineral%inventory,spread(0d0,1,8),1d-8,0d0, &
        initial_n(1),initial_n(2),pools,code)
   call require(code==0,'negative initial mineral stocks')
   call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,code)
   call require(code==0,'negative reaction owner initial state')
   call initialize_crop_soil(soil,crop,cp,9101_int64,state,code)
   call require(code==0,'negative real crop and soil owner')
   call harvest_crop_soil_boundary(state,hr);call require(hr%status==0,'negative real initial harvest')
   call consume_crop_soil_harvest_pending(state,hr);call require(hr%status==0,'negative retained residue transfer')
   call observe_crop_soil_harvest(state,ho,code);call require(code==0,'negative observe export')
   call acknowledge_crop_soil_harvest(state,ho,hr);call require(hr%status==0,'negative retired crop authority')
   ledger(1)=crop_soil_whole_n(state)
  end if
  do d=first,11
   forcing=cfg%tiles(1)%base_forcing
   forcing%top_flux=merge(-.03d0,.01d0,mod(d,3)==0)
   source=-.08d0
   if(d==0.or.d==6)source=.004d0
   bounded=source<0d0
   e=soil_n_day_environment_t(real(d,real64),real(d+1,real64),20d0)
   if(d==3.or.d==7)then
    write(arg,'(I0)')d
    call write_crop_soil_n_joint_restart_file(trim(path)//'.before-'//trim(arg),column, &
         cfg%tiles(1)%template,670001_int64,water,state,code)
    call require(code==0,'negative save committed before failures')
    harder=forcing;harder%top_flux=-.5d0
    cfg%numerical%max_committed_substeps=1
    call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
         water,harder,cfg%numerical,state,weather,e%t0,e%t1,rejected,e,fallow=.true., &
         atmospheric_n_surface=.true.,historical_top_water=source,finite_donor_top=bounded)
    cfg%numerical%max_committed_substeps=4096
    call require(rejected%status==JOINT_WATER_REJECTED,'negative rejected hydraulic trial')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.water-reject-'//trim(arg),column, &
         cfg%tiles(1)%template,670001_int64,water,state,code)
    call require(code==0,'negative save after water rejection')
    stale=e;stale%t1=stale%t1+1d0
    call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
         water,forcing,cfg%numerical,state,weather,e%t0,e%t1,rejected,stale,fallow=.true., &
         atmospheric_n_surface=.true.,historical_top_water=source,finite_donor_top=bounded)
    call require(rejected%status==JOINT_CHEMICAL_REJECTED.and.rejected%water%completed, &
         'negative rejected chemical trial after complete hydraulic candidate')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.chemical-reject-'//trim(arg),column, &
         cfg%tiles(1)%template,670001_int64,water,state,code)
    call require(code==0,'negative save after chemical rejection')
   end if
   before=crop_soil_whole_n(state)
   call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
        water,forcing,cfg%numerical,state,weather,e%t0,e%t1,r,e,fallow=.true., &
        atmospheric_n_surface=.true.,historical_top_water=source,finite_donor_top=bounded)
   if(r%status/=0)print *,'NEGATIVE_FAILURE',d,r%status,r%chemical%status,r%chemical%soil%status, &
        r%chemical%soil%process%status,r%chemical%soil%process%exchange%status
   call require(r%status==JOINT_OK,'negative real coupled accepted interval')
   call require(r%chemical%internal_supply_kg_m2==0d0,'negative retired crop cannot take up N')
   whole_residual=before+r%chemical%soil%external_in-r%chemical%soil%external_out-crop_soil_whole_n(state)
   call require(abs(whole_residual)<=1d-12,'negative daily whole N')
   ledger(2)=ledger(2)+r%chemical%soil%external_in
   ledger(3)=ledger(3)+r%chemical%soil%external_out
   ledger(4)=ledger(4)+r%chemical%internal_supply_kg_m2
   ledger(5)=ledger(5)+r%chemical%soil%process%exchange%nh4_nitrified_kg_m2
   ledger(6)=ledger(6)+r%chemical%soil%process%exchange%no3_denitrified_kg_m2
   ledger(7)=ledger(7)+r%chemical%soil%process%organic%nitrogen%mineralized_n_kg_m2
   ledger(8:9)=ledger(8:9)+r%chemical%soil%top_requested
   ledger(10:11)=ledger(10:11)+r%chemical%soil%top_actual
   ledger(12:13)=ledger(12:13)+r%chemical%soil%top_unmet
   ledger(14)=max(ledger(14),abs(whole_residual))
   ledger(15)=max(ledger(15),r%diagnostics%max_abs_step_mass_residual)
   if(d+1==1.or.d+1==6)then
    write(arg,'(I0)')d+1
    call write_crop_soil_n_joint_restart_file(trim(path)//'.'//trim(arg),column, &
         cfg%tiles(1)%template,670001_int64,water,state,code)
    call require(code==0,'negative persistent native checkpoint')
    open(newunit=u,file=trim(path)//'.'//trim(arg)//'.ledger',status='replace',form='unformatted',access='stream')
    write(u)ledger;close(u)
   end if
   print *,'NEGATIVE_DAY',d+1,before,r%chemical%soil%external_in,r%chemical%soil%external_out, &
        crop_soil_whole_n(state),whole_residual,r%chemical%soil%top_unmet, &
        r%diagnostics%accepted_substeps
  end do
  call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,code)
  call require(code==0,'negative persistent endpoint')
  open(newunit=u,file=trim(endpoint)//'.ledger',status='replace',form='unformatted',access='stream')
  write(u)ledger;close(u)
  whole_residual=ledger(1)+ledger(2)-ledger(3)-crop_soil_whole_n(state)
  scale=max(ledger(1)+ledger(2),ledger(3)+crop_soil_whole_n(state),1d-30)
  call require(abs(whole_residual)<=1d-10,'negative cumulative whole N')
  call require(sum(ledger(12:13))>0d0,'negative actual finite-donor exhaustion observed')
  print *,'NEGATIVE_BUDGET',ledger(1:3),crop_soil_whole_n(state),whole_residual,abs(whole_residual)/scale
  print '(A)','FINITE_DONOR_ACTUAL_RICHARDS_RETIRED_CROP_N_RESTART=PASS'
 end subroutine
