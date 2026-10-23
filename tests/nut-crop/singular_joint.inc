 subroutine singular_joint()
  type(crop_soil_n_joint_result_t)::r,rejected
  type(fmr_b110_physical_forcing_t)::forcing,harder
  type(soil_n_day_environment_t)::e,stale
  real(real64)::ledger(14),before,residual,external_in,external_out
  integer::first,d,u,code
  character(32)::arg
  logical::immobilise,limited,zero_pools,all_zero,bio_zero,hum_zero,resonant,repeated,singular,small_det
  real(real64)::p1,p2,p3,p4,p5
  real(real64)::available_before,demand_after
  zero_pools=trim(selected)=='zero_pools';all_zero=trim(selected)=='all_zero'
  bio_zero=trim(selected)=='bio_zero';hum_zero=trim(selected)=='hum_zero'
  resonant=trim(selected)=='resonant';repeated=trim(selected)=='repeated'
  singular=trim(selected)=='singular';small_det=trim(selected)=='small_det'
  immobilise=trim(selected)=='immobilise'.or.zero_pools.or.bio_zero.or.hum_zero.or.resonant.or.repeated.or.singular.or.small_det
  limited=trim(selected)=='limited'
  if(limited)cp%lai_crit_nupt=0d0
  sp%mineral%c_top=[.002d0,.005d0];sp%mineral%c_bottom=0d0;sp%mineral%c_lateral=0d0
  if(immobilise)then
   sp%mineral%inventory%nfrac_fom=.0001d0
   sp%mineral%inventory%nfrac_biomass=.08d0;sp%mineral%inventory%nfrac_humus=.06d0
  end if
  sp%organic_reference%ratecon_fom=1d-4;sp%organic_reference%ratecon_hum=1d-5
  if(immobilise)then
   sp%organic_reference%ratecon_bio=1d-4;sp%organic_reference%ratecon_hum=1d-5
  end if
  if(zero_pools.or.all_zero)then
   sp%organic_reference%ratecon_bio=0d0;sp%organic_reference%ratecon_hum=0d0
   if(all_zero)sp%organic_reference%ratecon_fom=0d0
  end if
  if(bio_zero)sp%organic_reference%ratecon_bio=0d0
  if(hum_zero)sp%organic_reference%ratecon_hum=0d0
  if(resonant)then
   sp%organic_reference%ratecon_bio=2d-4;sp%organic_reference%ratecon_hum=1d-4
   p1=(1d0-sp%organic_reference%asfa_bio)*sp%organic_reference%ratecon_bio
   p2=sp%organic_reference%asfa_bio*sp%organic_reference%ratecon_hum
   p3=sp%organic_reference%asfa_hum*sp%organic_reference%ratecon_bio
   p4=(1d0-sp%organic_reference%asfa_hum)*sp%organic_reference%ratecon_hum
   p5=sqrt((p1-p4)**2+4d0*p2*p3)
   sp%organic_reference%ratecon_fom=(p1+p4-p5)/2d0
  end if
  if(repeated)then
   sp%organic_reference%asfa_bio=0d0;sp%organic_reference%asfa_hum=0d0
   sp%organic_reference%ratecon_bio=1d-4;sp%organic_reference%ratecon_hum=1d-4
   sp%organic_reference%ratecon_fom=1d-4
  end if
  if(singular)then
   sp%organic_reference%asfa_bio=.5d0;sp%organic_reference%asfa_hum=.5d0
  end if
  if(small_det)then
   sp%organic_reference%ratecon_bio=1d-7;sp%organic_reference%ratecon_hum=2d-7
  end if
  sp%environment%nitrification_ref_per_day=.02d0;sp%environment%denitrification_ref_per_day=.025d0
  sp%environment%cdissi_half_kg_m2=1d-12
  cfg%tiles(1)%base_forcing%bottom_flux=0d0;cfg%tiles(1)%base_forcing%drainage_flux_by_level=0d0
  cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
  cfg%tiles(1)%base_forcing%root_potential_transpiration=.0008d0
  call get_command_argument(5,arg);first=0;ledger=0d0
  if(trim(mode)=='resume')then
   read(arg,*)first
   call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
    670001_int64,9001_int64,9101_int64,sp,cp,water,state,code)
   call require(code==0,'competing process restart restores real crop/soil/water')
   open(newunit=u,file=trim(path)//'.ledger',status='old',form='unformatted',access='stream');read(u)ledger;close(u)
  else
   call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state, &
    0d0,ok,spread(0d0,1,numnod));call require(ok,'competing real Richards initialization')
   theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
   call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),.1d0,.1d0,.02d0,.03d0,pools,code)
   if(limited)then
    call initialize_soil_n_pool_state(sp%mineral%inventory,spread(0d0,1,8),1d-4,0d0,2d-7,3d-7,pools,code)
   end if
   call require(code==0,'competing organic and mineral inventories')
   call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,code);call require(code==0,'competing reactive init')
   call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0,'competing crop init')
   ledger(1)=crop_soil_whole_n(state)
  end if
  do d=first,7
   forcing=cfg%tiles(1)%base_forcing;forcing%top_flux=merge(-.03d0,.01d0,mod(d,2)==0)
   e=soil_n_day_environment_t(real(d,real64),real(d+1,real64),20d0)
   if(d==2.or.d==5)then
    write(arg,'(I0)')d
    call write_crop_soil_n_joint_restart_file(trim(path)//'.before-'//trim(arg),column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'competing save before rejection')
    ! Exhaustion rejects instead of allocating among the competing sinks.
    call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     water,forcing,cfg%numerical,state,weather,e%t0,e%t1,rejected,e,atmospheric_n_surface=.true., &
     historical_top_water=-100d0,nondepleting_top=.true.)
    call require(rejected%status==JOINT_CHEMICAL_REJECTED.and.rejected%water%completed,'competing exhausted chemistry rejects completed water trial')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.exhaust-reject-'//trim(arg),column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'competing save after exhaustion rejection')
    stale=e;stale%t1=stale%t1+1d0
    call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     water,forcing,cfg%numerical,state,weather,e%t0,e%t1,rejected,stale,atmospheric_n_surface=.true., &
     historical_top_water=merge(-.000002d0,-.002d0,limited),nondepleting_top=.true.)
    call require(rejected%status==JOINT_CHEMICAL_REJECTED.and.rejected%water%completed,'competing stale chemical trial')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.stale-reject-'//trim(arg),column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'competing save after stale trial')
    harder=forcing;harder%top_flux=-.5d0;cfg%numerical%max_committed_substeps=1
    call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     water,harder,cfg%numerical,state,weather,e%t0,e%t1,rejected,e,atmospheric_n_surface=.true., &
     historical_top_water=merge(-.000002d0,-.002d0,limited),nondepleting_top=.true.)
    cfg%numerical%max_committed_substeps=4096
    call require(rejected%status==JOINT_WATER_REJECTED,'competing hydraulic rejection')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.water-reject-'//trim(arg),column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'competing save after water rejection')
   end if
   call state%snapshot(soil,crop)
   call soil%snapshot(time,theta,pools,revision)
   available_before=pools%ammonium_n_kg_m2+pools%nitrate_n_kg_m2
   before=crop_soil_whole_n(state)
   if(trim(mode)=='probe')then
    call write_crop_soil_n_joint_restart_file(trim(path)//'.probe-before',column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'preimage before-state')
   end if
   call run_crop_soil_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
    water,forcing,cfg%numerical,state,weather,e%t0,e%t1,r,e,atmospheric_n_surface=.true., &
    historical_top_water=merge(-.000002d0,-.002d0,limited),nondepleting_top=.true.)
   if(trim(mode)=='probe')then
    call require((singular.or.small_det).and.r%status==JOINT_CHEMICAL_REJECTED.and.r%water%completed,'preimage rejected receiving determinant')
    call write_crop_soil_n_joint_restart_file(trim(path)//'.probe-after',column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'preimage rejected state')
    print *,'PREIMAGE_DETERMINANT_REJECTION_PASS'
    return
   end if
   if(r%status/=0)print *,'COMPETING_FAILURE',d,r%status,r%chemical%status,r%chemical%soil%status, &
    r%chemical%soil%process%status,r%chemical%soil%process%exchange%status
   call require(r%status==JOINT_OK,'competing accepted actual Richards crop soil interval')
   if(limited)then
    demand_after=r%chemical%prepared%nitrogen_request%soil_request*1d-4
    call require(demand_after>available_before+max(0d0,r%chemical%soil%process%organic%nitrogen%mineralized_n_kg_m2), &
     'both unused demand branches exceed all available mineral N')
   end if
   if(all_zero)then
    call require(r%chemical%soil%process%organic%nitrogen%mineralized_n_kg_m2==0d0,'all zero organic N transfer')
    call require(r%chemical%soil%process%dissimilation%carbon_dissimilation_kg_m2==0d0,'all zero organic carbon loss')
   end if
   call require(r%chemical%internal_supply_kg_m2>0d0,'live plant receives actual soil N')
   call require(all(r%chemical%soil%top_unmet==0d0),'nondepleting top has no unmet extraction')
   call require(all(r%chemical%soil%top_actual==r%chemical%soil%top_requested),'all requested top extraction realised')
   external_in=r%chemical%soil%external_in+r%chemical%fixation_kg_m2
   external_out=r%chemical%soil%external_out-r%chemical%internal_supply_kg_m2+r%chemical%crop_loss_kg_m2
   residual=before+external_in-external_out-crop_soil_whole_n(state)
   call require(abs(residual)<1d-12,'competing daily whole crop soil nitrogen')
   ledger(2)=ledger(2)+external_in;ledger(3)=ledger(3)+external_out
   ledger(4)=ledger(4)+r%chemical%internal_supply_kg_m2
   ledger(5)=ledger(5)+r%chemical%soil%process%organic%nitrogen%mineralized_n_kg_m2
   ledger(6)=ledger(6)+r%chemical%soil%process%exchange%nh4_nitrified_kg_m2
   ledger(7)=ledger(7)+r%chemical%soil%process%exchange%no3_denitrified_kg_m2
   ledger(8:9)=ledger(8:9)+r%chemical%soil%top_actual
   ledger(10:11)=ledger(10:11)+r%chemical%soil%top_unmet
   ledger(12)=max(ledger(12),abs(residual));ledger(13)=max(ledger(13),r%diagnostics%max_abs_step_mass_residual)
   ledger(14)=crop_soil_whole_n(state)
   if(d+1==1.or.d+1==4)then
    write(arg,'(I0)')d+1
    call write_crop_soil_n_joint_restart_file(trim(path)//'.'//trim(arg),column,cfg%tiles(1)%template, &
     670001_int64,water,state,code);call require(code==0,'competing persistent checkpoint')
    open(newunit=u,file=trim(path)//'.'//trim(arg)//'.ledger',status='replace',form='unformatted',access='stream');write(u)ledger;close(u)
   end if
   print *,'COMPETING_DAY',d+1,r%chemical%internal_supply_kg_m2,r%chemical%soil%process%organic%nitrogen%mineralized_n_kg_m2, &
    r%chemical%soil%top_actual,residual,r%diagnostics%max_abs_step_mass_residual
  end do
  call require(abs(ledger(1)+ledger(2)-ledger(3)-ledger(14))<1d-12,'competing integrated whole N')
  if(immobilise)call require(ledger(5)<0d0,'actual organic immobilisation competes for NH4')
  call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,code)
  call require(code==0,'competing complete persistent endpoint')
  open(newunit=u,file=trim(endpoint)//'.ledger',status='replace',form='unformatted',access='stream');write(u)ledger;close(u)
  print *,'NONDEPLETING_COMPETING_JOINT_PASS',trim(selected),ledger
 end subroutine
