#!/usr/bin/env python3
from pathlib import Path

p = Path('tests/fwof/test_fwof42_crop_persistence_layouts.f90')
s = p.read_text(encoding='utf-8')
if 'logical function same_real_bits' in s:
    print('FWOF42_BIT_EXACT_ORACLE_ALREADY_MATERIALIZED=PASS')
    raise SystemExit(0)

replacements = [
    ("call require(allocated_zero%biomass%living_leaf_biomass() == canonical_zero%biomass%living_leaf_biomass(), &\n         'zero edge living leaf biomass equivalent')",
     "call require(same_real_bits(allocated_zero%biomass%living_leaf_biomass(), &\n         canonical_zero%biomass%living_leaf_biomass()), 'zero edge living leaf biomass equivalent')"),
    ("call require(allocated_zero%biomass%leaf_area_sum() == canonical_zero%biomass%leaf_area_sum(), &\n         'zero edge leaf area equivalent')",
     "call require(same_real_bits(allocated_zero%biomass%leaf_area_sum(), &\n         canonical_zero%biomass%leaf_area_sum()), 'zero edge leaf area equivalent')"),
    ("if (left%development_stage /= right%development_stage) return",
     "if (.not. same_real_bits(left%development_stage, right%development_stage)) return"),
    ("if (left%biomass%root_biomass /= right%biomass%root_biomass) return",
     "if (.not. same_real_bits(left%biomass%root_biomass, right%biomass%root_biomass)) return"),
    ("if (left%biomass%stem_biomass /= right%biomass%stem_biomass) return",
     "if (.not. same_real_bits(left%biomass%stem_biomass, right%biomass%stem_biomass)) return"),
    ("if (left%biomass%storage_biomass /= right%biomass%storage_biomass) return",
     "if (.not. same_real_bits(left%biomass%storage_biomass, right%biomass%storage_biomass)) return"),
    ("if (left%biomass%exponential_leaf_area_index /= right%biomass%exponential_leaf_area_index) return",
     "if (.not. same_real_bits(left%biomass%exponential_leaf_area_index, &\n          right%biomass%exponential_leaf_area_index)) return"),
    ("if (any(left%biomass%leaf_biomass /= right%biomass%leaf_biomass)) return",
     "if (.not. same_real_vector_bits(left%biomass%leaf_biomass, right%biomass%leaf_biomass)) return"),
    ("if (any(left%biomass%specific_leaf_area /= right%biomass%specific_leaf_area)) return",
     "if (.not. same_real_vector_bits(left%biomass%specific_leaf_area, right%biomass%specific_leaf_area)) return"),
    ("if (any(left%biomass%leaf_age /= right%biomass%leaf_age)) return",
     "if (.not. same_real_vector_bits(left%biomass%leaf_age, right%biomass%leaf_age)) return"),
    ("if (left%evolution_continuation%temperature_sum /= right%evolution_continuation%temperature_sum) return",
     "if (.not. same_real_bits(left%evolution_continuation%temperature_sum, &\n          right%evolution_continuation%temperature_sum)) return"),
    ("if (any(left%evolution_continuation%minimum_temperature_history /= &\n          right%evolution_continuation%minimum_temperature_history)) return",
     "if (.not. same_real_vector_bits(left%evolution_continuation%minimum_temperature_history, &\n          right%evolution_continuation%minimum_temperature_history)) return"),
    ("if (left%b110_reference_compatibility%lai_exponential_rate_carryover /= &\n          right%b110_reference_compatibility%lai_exponential_rate_carryover) return",
     "if (.not. same_real_bits(left%b110_reference_compatibility%lai_exponential_rate_carryover, &\n          right%b110_reference_compatibility%lai_exponential_rate_carryover)) return"),
]
for old, new in replacements:
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'F-WOF42 bit-exact replacement count={count}: {old[:100]}')
    s = s.replace(old, new, 1)

anchor = "  logical function same_owner_exact(left, right) result(same)\n"
helper = """  pure logical function same_real_bits(left, right) result(same)
    real(real64), intent(in) :: left, right
    same = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_real_bits

  pure logical function same_real_vector_bits(left, right) result(same)
    real(real64), intent(in) :: left(:), right(:)
    integer :: i
    same = .false.
    if (size(left) /= size(right)) return
    do i = 1, size(left)
      if (.not. same_real_bits(left(i), right(i))) return
    end do
    same = .true.
  end function same_real_vector_bits

"""
if s.count(anchor) != 1:
    raise SystemExit(f'F-WOF42 helper anchor count={s.count(anchor)}')
s = s.replace(anchor, helper + anchor, 1)
p.write_text(s, encoding='utf-8')
print('FWOF42_BIT_EXACT_REAL_ORACLE_MATERIALIZED=PASS')
