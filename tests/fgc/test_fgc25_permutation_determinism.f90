program test_fgc25_permutation_determinism
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, GW_MULTI_OK
  use mod_groundwater_multiswap_topology, only: build_canonical_tile_order, stable_ordered_sum
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: check
  implicit none

  integer :: failures
  type(groundwater_direct_tile_binding_t) :: a(3), b(3)
  real(real64) :: va(3), vb(3), sa, sb
  integer :: oa(3), ob(3), status_a, status_b

  failures = 0

  a(1)%groundwater_cell_id = 7001_int64
  a(1)%tile_id = 30_int64
  a(1)%area_fraction = 0.30_real64
  a(2)%groundwater_cell_id = 7001_int64
  a(2)%tile_id = 10_int64
  a(2)%area_fraction = 0.20_real64
  a(3)%groundwater_cell_id = 7001_int64
  a(3)%tile_id = 20_int64
  a(3)%area_fraction = 0.50_real64

  ! Values are tied to tile identity and chosen so a non-canonical three-term
  ! accumulation can round differently. Canonical tile order must remove caller
  ! input order as a numerical degree of freedom.
  va = [1.0_real64, 1.0e16_real64, -1.0e16_real64]
  b(1) = a(3)
  b(2) = a(1)
  b(3) = a(2)
  vb = [va(3), va(1), va(2)]

  call build_canonical_tile_order(a, oa, status_a)
  call build_canonical_tile_order(b, ob, status_b)
  call check(status_a == GW_MULTI_OK .and. status_b == GW_MULTI_OK, &
       'canonical-sum: both permutations accepted', failures)
  call check(a(oa(1))%tile_id == 10_int64 .and. a(oa(2))%tile_id == 20_int64 .and. &
       a(oa(3))%tile_id == 30_int64, 'canonical-sum: first input sorted by tile id', failures)
  call check(b(ob(1))%tile_id == 10_int64 .and. b(ob(2))%tile_id == 20_int64 .and. &
       b(ob(3))%tile_id == 30_int64, 'canonical-sum: permuted input sorted identically', failures)

  sa = stable_ordered_sum(va, oa)
  sb = stable_ordered_sum(vb, ob)
  call check(transfer(sa, 0_int64) == transfer(sb, 0_int64), &
       'canonical-sum: result bit-identical across caller permutation', failures)
  call check(transfer(sa, 0_int64) == transfer(1.0_real64, 0_int64), &
       'canonical-sum: adversarial sequence follows canonical tile order', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 CANONICAL SUM DETERMINISM FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 CANONICAL SUM DETERMINISM PASS'
end program test_fgc25_permutation_determinism
