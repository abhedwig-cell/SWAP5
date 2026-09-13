program fvq72_forbidden_split_surface_publication
  use mod_fmr_surface_evaporation_accepted_publication, only: fmr_prepared_surface_evaporation_publication_t, &
       finalize_local_prepared
  implicit none
  type(fmr_prepared_surface_evaporation_publication_t) :: retained_trial_result
  print *, retained_trial_result
end program fvq72_forbidden_split_surface_publication
