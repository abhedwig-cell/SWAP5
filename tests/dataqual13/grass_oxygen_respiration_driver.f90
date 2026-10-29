program grass_oxygen_respiration_driver
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
 use mod_wofost_oxygen_respiration
 use plant_interface,only:q10_root,c_mroot,f_senes,max_resp_factor
 use mod_wofost_grass_daily_growth
 implicit none
 type(wofost_oxygen_respiration_t)::oxygen
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
 do i=1,6
  fl_start_cropemergence=.true.;s_act%fl_potential=.false.
  call initialize_wofost(s_act)
  call initialize_wofost_emergence_owner(p%tdwi,bundle,owner,status)
  if(status/=WOFOST_EMERGENCE_INIT_OK)error stop 'original emergence'
  dvs=.4d0;tav=10d0;m_act%tdelay=0;r_act%pgass=40d0
  if(i==2)r_act%pgass=0d0
  if(i==3)m_act%tdelay=2
  if(i==4)then
   s_act%wrt=0d0;owner%biomass%root_biomass=0d0
  end if
  if(i==5)then
   dvs=1.4d0;tav=-5d0;r_act%pgass=2d0
  end if
  if(i==6)then
   tav=35d0;r_act%pgass=400d0
  end if
  owner%development_stage=dvs
  call assemble_wofost_one_day_rate_state_view(owner,p%ssa,p%spa,view,available,status)
  if(status/=WOFOST_RATE_STATE_VIEW_OK.or..not.available)error stop 'owner oxygen view'
  assimilation%actual_pgass=r_act%pgass
  call prepare_wofost_oxygen_respiration(view,bundle,assimilation,tav,m_act%tdelay,oxygen,status)
  if(status/=WOFOST_OXYGEN_RESPIRATION_OK)error stop 'native respiration'
  call original_oxygen_respiration()
  err=maxval(abs([q10_root,c_mroot,f_senes,max_resp_factor]- &
    [oxygen%root_q10,oxygen%root_maintenance_coefficient,oxygen%senescence_factor,oxygen%maximum_respiration_factor]))
  maximum_error=max(maximum_error,err)
  if(err/=0d0)error stop 'original respiration differential'
  write(*,*)'OXYGEN_RESPIRATION_SOURCE',i,err,max_resp_factor
 end do
 call prepare_wofost_oxygen_respiration(view,bundle,assimilation,tav,-1,oxygen,status)
 if(status==WOFOST_OXYGEN_RESPIRATION_OK)error stop 'invalid regrowth delay'
 write(*,*)'ORIGINAL_OXYGEN_RESPIRATION_PASS',maximum_error
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
