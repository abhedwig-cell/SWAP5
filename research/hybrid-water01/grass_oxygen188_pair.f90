! Research-only side evaluation of the two Bartholomeus implementations.
subroutine oxygen188_pair(label, clock, heads, water, temp, expected_deep)
  use MOD_grid, only: layer, numnod, dz
  use MOD_MvG, only: cofgen, watcon, swsophy
  use MOD_texture_orgmat, only: orgmat, psand, bdens
  use MOD_cropdevelopment, only: campbell_h100, campbell_h500, gfp_h100, &
       q10_microbial, specific_resp_humus, rootradius_m, srl, wroot_node_top
  use plant_interface, only: c_mroot, f_senes, q10_root, max_resp_factor, noddrz, sw_oxygen
  use atmosphere_interface, only: tav
  use variables, only: h, theta
  use MOD_SoilTemperature, only: tsoil
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, &
       BartholomeusCropParameters, construct_bartholomeus_dataset
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  use mod_bartholomeus_waterfilm_provider, only: BARTHOLOMEUS_WATERFILM_REFERENCE
  implicit none
  character(*), intent(in) :: label
  real(8), intent(in) :: clock, heads(113), water(113), temp(113), expected_deep
  type(BartholomeusImmutableDataset), save :: dataset
  type(BartholomeusCropParameters) :: crop
  type(bartholomeus_runtime_view_t) :: view
  real(8), allocatable :: native(:)
  real(8) :: prior_h(113), prior_water(113), prior_temp(113)
  real(8) :: first_respiration(4), respiration(4), first_density(113)
  real(8) :: b0(noddrz), t100(noddrz), t500(noddrz), tgfp(noddrz), ctop
  integer :: i, n
  logical :: ok
  save first_respiration, first_density

  if (numnod /= 113 .or. swsophy /= 0 .or. sw_oxygen /= 2) stop 74
  n = noddrz
  respiration = [c_mroot, f_senes, max_resp_factor, tav]
  if (.not. allocated(dataset%soil)) then
    first_respiration = respiration
    first_density(1:n) = wroot_node_top(1:n)
    do i = 1, n
      t100(i) = watcon(i, campbell_h100)
      t500(i) = watcon(i, campbell_h500)
      tgfp(i) = watcon(i, gfp_h100)
    end do
    call construct_bartholomeus_dataset(cofgen(:,1:n), dz(1:n), orgmat(layer(1:n)), &
         psand(layer(1:n)), bdens(layer(1:n)), t100, t500, tgfp, campbell_h100, &
         campbell_h500, 0, dataset, ok)
    if (.not. ok) stop 75
    write(*,'(a,i0,*(1x,es25.17e3))') 'PAIR_FORCING ', n, respiration, srl, wroot_node_top(1:n)
  end if
  if (n /= size(dataset%soil)) stop 76
  if (any(respiration /= first_respiration) .or. any(wroot_node_top(1:n) /= first_density(1:n))) stop 77

  prior_h = h(1:113)
  prior_water = theta(1:113)
  prior_temp = tsoil(1:113)
  h(1:113) = heads
  theta(1:113) = water
  tsoil(1:113) = temp
  do i = 1, n
    call OxygenStress(i, b0(i))
  end do
  h(1:113) = prior_h
  theta(1:113) = prior_water
  tsoil(1:113) = prior_temp
  if (expected_deep >= 0d0) then
    if (b0(n) /= expected_deep) stop 78
  end if

  crop = BartholomeusCropParameters(c_mroot, f_senes, q10_root, specific_resp_humus, &
       q10_microbial, 0.9d0, 0.9d0, rootradius_m, max_resp_factor)
  view%rooted_nodes = n
  view%pressure_head_cm = heads(1:n)
  view%water_content = water(1:n)
  view%soil_temperature_k = temp(1:n) + 273d0
  ctop = 672d0 / (8.314472d0 * (tav + 273d0))
  call evaluate_bartholomeus_factors_from_state(view, dataset, crop, spread(1d0/srl, 1, n), &
       wroot_node_top(1:n), ctop, BARTHOLOMEUS_WATERFILM_REFERENCE, native, ok)
  if (.not. ok) stop 79
  write(*,'(a,*(1x,es25.17e3))') 'PAIR_'//label, clock, b0, native
end subroutine

subroutine oxygen188_native_states()
  implicit none
  integer :: unit, ios
  real(8) :: clock, heads(113), water(113), temp(113)
  open(newunit=unit,file='native_states.txt',status='old',action='read')
  do
    read(unit,*,iostat=ios) clock, heads, water, temp
    if (is_iostat_end(ios)) exit
    if (ios /= 0) stop 80
    call oxygen188_pair('NATIVE', clock, heads, water, temp, -1d0)
  end do
  close(unit)
end subroutine
