program grass_growth_oracle_driver
 use iso_fortran_env,only:real64
 use MOD_wofost,only:p,read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost, &
      s_act,r_act,m_act,p_grs
 use plant_interface,only:unit_crp,crpfilnam,fl_start_cropemergence,dvs,tsum,kdif
 use atmosphere_interface,only:tav
 use MOD_swap_base,only:swcropsnm
 use mod_wofost_rate_parameters
 use mod_wofost_rate_table
 use mod_wofost_crop_owner_state
 use mod_wofost_emergence_initialization
 use mod_wofost_one_day_structural_evolution
 use mod_wofost_one_day_rate_state_view
 use mod_wofost_prepare_assimilation,only:wofost_prepare_assimilation_result_t
 use mod_wofost_finalize_rates,only:wofost_finalize_rate_forcing_t
 use mod_wofost_grass_development
 use mod_wofost_grass_daily_growth
 implicit none
 type(wofost_rate_scalar_parameters_t)::s
 type(wofost_rate_parameter_tables_t)::tables
 type(wofost_rate_parameter_bundle_t)::bundle
 type(wofost_crop_owner_state_t)::owner,candidate
 type(wofost_one_day_rate_state_view_t)::view
 type(wofost_one_day_window_context_t)::context
 type(wofost_one_day_update_parameters_t)::updates
 type(wofost_accepted_window_aggregates_t)::aggregates
 type(wofost_one_day_rate_packet_t)::rates
 type(wofost_prepare_assimilation_result_t)::assimilation
 type(wofost_finalize_rate_forcing_t)::forcing
 type(grass_development_parameters_t)::development_parameters
 type(grass_management_continuation_t)::management
 type(grass_development_candidate_t)::development
 real(real64)::maximum_error,err,source_values(7),candidate_values(7)
 integer::status,i
 logical::available
 unit_crp=74;crpfilnam='grass.crp';swcropsnm=0
 call read_wofost()
 s%grass_development=.true.
 s%diffuse_extinction_coefficient=kdif;s%initial_light_use_efficiency=p%eff
 s%co2_to_dry_matter_fraction=p%cfrdm;s%attainable_yield_multiplier=p%relmf
 s%conversion_efficiency_root=p%cvr;s%conversion_efficiency_stem=p%cvs
 s%conversion_efficiency_leaf=p%cvl;s%conversion_efficiency_storage=p%cvo
 s%respiration_temperature_q10=p%q10;s%maintenance_respiration_root=p%rmr
 s%maintenance_respiration_stem=p%rms;s%maintenance_respiration_leaf=p%rml;s%maintenance_respiration_storage=p%rmo
 s%maximum_leaf_relative_death_rate=p%perdl;s%leaf_age_base_temperature=p%tbase;s%maximum_relative_lai_growth_rate=p%rgrlai
 call rdinit(75,0,'grass.crp')
 call readtable('amaxtb',tables%maximum_assimilation)
 call readtable('tmpftb',tables%daytime_temperature_factor)
 call readtable('tmnftb',tables%minimum_temperature_factor)
 call readtable('rfsetb',tables%maintenance_respiration_factor)
 call readtable('frtb',tables%root_partition_fraction)
 call readtable('fltb',tables%leaf_partition_fraction)
 call readtable('fstb',tables%stem_partition_fraction)
 call readtable('fotb',tables%storage_partition_fraction)
 call readtable('rdrrtb',tables%relative_root_death_rate)
 call readtable('rdrstb',tables%relative_stem_death_rate)
 call readtable('slatb',tables%specific_leaf_area)
 call construct_wofost_rate_parameter_bundle(s,tables,bundle,status)
 if(status/=WOFOST_RATE_PARAMETER_OK)error stop 'original grass bundle'
 maximum_error=0d0
 do i=1,4
  fl_start_cropemergence=.true.;s_act%fl_potential=.false.
  call initialize_wofost(s_act)
  m_act%fl_potential=.false.
  call initialize_grass(m_act)
  call initialize_wofost_emergence_owner(p%tdwi,bundle,owner,status)
  if(status/=WOFOST_EMERGENCE_INIT_OK)error stop 'grass emergence owner'
  dvs=.4d0;tsum=210d0;tav=10d0;m_act%tdelay=0
  if(i==1)tsum=0d0
  if(i==3)m_act%tdelay=2
  if(i==4)dvs=.999d0
  owner%development_stage=dvs;owner%evolution_continuation%temperature_sum=tsum
  management%regrowth_delay_days=m_act%tdelay
  development_parameters%temperature_start_mode=p_grs%sw_tsum
  call prepare_grass_development_candidate(development_parameters,management,tsum,tav,0d0,development,status)
  if(status/=GRASS_DEVELOPMENT_OK)error stop 'grass source development'
  call assemble_wofost_one_day_rate_state_view(owner,p%ssa,p%spa,view,available,status)
  if(status/=WOFOST_RATE_STATE_VIEW_OK.or..not.available)error stop 'grass owner view'
  context%active=.true.;context%t0=0d0;context%t1=1d0
  updates%development_stage_end=p%dvsend;updates%leaf_lifespan=p%span;updates%grass_development=.true.
  aggregates%actual_root_uptake=.7d0;aggregates%potential_transpiration=1d0
  assimilation%actual_pgass=40d0;forcing%average_temperature=tav
  call complete_grass_daily_candidate(owner,context,view,bundle,assimilation,forcing,updates,aggregates,development, &
       candidate,rates,status)
  if(status/=GRASS_DAILY_OK)then
   write(*,*)'GRASS_FAIL',i,status;error stop 'grass native candidate'
  end if
  r_act%pgass=40d0
  call update_dvs_rate()
  call update_wofost(s_act,r_act,m_act,.7d0)
  source_values=[s_act%wrt,s_act%wst,s_act%wlv,s_act%wso,s_act%laiexp,dvs,tsum]
  candidate_values=[candidate%biomass%root_biomass,candidate%biomass%stem_biomass, &
       candidate%biomass%living_leaf_biomass(),candidate%biomass%storage_biomass, &
       candidate%biomass%exponential_leaf_area_index,candidate%development_stage, &
       candidate%evolution_continuation%temperature_sum]
  err=maxval(abs(source_values-candidate_values));maximum_error=max(maximum_error,err)
  write(*,*)'GRASS_BODY',i,err
  if(err>1d-10)then
   write(*,*)source_values;write(*,*)candidate_values;error stop 'grass body source difference'
  end if
  if(owner%evolution_continuation%temperature_sum/=merge(0d0,210d0,i==1))error stop 'grass rollback base'
 end do
 write(*,*)'ORIGINAL_GRASS_BIOMASS_CANDIDATE_PASS',maximum_error
contains
 subroutine readtable(key,table)
  character(*),intent(in)::key
  type(wofost_rate_table_t),intent(out)::table
  real(real64)::values(2048)
  integer::n,code
  call rdadou(key,values,2048,n)
  if(n<4.or.mod(n,2)/=0)error stop 'original crop table shape'
  call construct_wofost_rate_table(values(1:n:2),values(2:n:2),table,code)
  if(code/=WOFOST_RATE_TABLE_OK)error stop 'original crop table'
 end subroutine
end program
