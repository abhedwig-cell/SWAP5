program test_native_macro_geometry
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_geometry
 use mod_ppa_wu05a5_multi_domain_process
 implicit none
 type(macropore_geometry_config_t)::g
 type(macropore_geometry_result_t)::r
 real(real64),allocatable::fraction(:),dynamic(:)
 character(1024)::path
 call get_command_argument(1,path)
 call import_column_macro_geometry(trim(path),g,fraction)
 if(.not.g%valid())error stop 'original geometry not ready'
 allocate(dynamic(g%num_nodes));dynamic=0d0
 call evaluate_macropore_geometry(g,dynamic,r)
 if(.not.r%valid)error stop 'original source geometry rejected by production owner'
 if(maxval(abs(sum(r%volume_domain_cp,dim=1)-g%static_volume_cp))>1e-12_real64)error stop 'original domain volume partition'
 if(any(r%bottom_domain<g%top_node).or.any(r%bottom_domain>g%num_nodes))error stop 'original active domains'
 print '(a,i0,a,i0)','ORIGINAL_MACRO_GEOMETRY_PRODUCTION_PASS nodes=',g%num_nodes,' domains=',g%num_domains
 print '(a,*(es25.17e3,1x))','ORIGINAL_MACRO_GEOMETRY_STOCK=',sum(g%static_volume_cp),r%partition_residual_cm, &
  minval(fraction),maxval(fraction)
end program
