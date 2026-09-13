program fmr43_forbidden_split_publication_attack
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepare_surface_evaporation_publication, &
       fmr_finalize_surface_evaporation_publication
  implicit none
  print *, 'unsafe split publication unexpectedly visible', &
       associated_split_surface_publication_symbols()
contains
  logical function associated_split_surface_publication_symbols()
    associated_split_surface_publication_symbols = .true.
  end function associated_split_surface_publication_symbols
end program fmr43_forbidden_split_publication_attack
