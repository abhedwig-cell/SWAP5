program test_crop_lifecycle_daily_composition
  use mod_crop_preparation_sowing_preflight
  use mod_crop_germination_preflight
  use mod_crop_lifecycle_daily_composition
  implicit none
  type(crop_preparation_sowing_candidate_t) :: p
  type(crop_germination_candidate_t) :: g
  type(crop_daily_lifecycle_candidate_t) :: a,b
  integer :: st
  p%valid=.true.
  p%next_preparation_delay=2
  p%next_sowing_delay=2
  g%valid=.false.
  call compose_crop_lifecycle_daily_candidate(p,g,a,st)
  if(st/=CROP_DAILY_OK.or..not.a%valid.or.a%germination_evaluated) error stop 'blocked'
  if(a%emergence_eligible) error stop 'premature emergence'
  p%preparation_complete=.true.
  p%sowing_complete=.true.
  call compose_crop_lifecycle_daily_candidate(p,g,a,st)
  if(st/=CROP_DAILY_INVALID.or.a%valid) error stop 'unready germination accepted'
  g%valid=.true.
  g%complete=.false.
  call compose_crop_lifecycle_daily_candidate(p,g,a,st)
  if(st/=CROP_DAILY_OK.or..not.a%germination_evaluated.or.a%emergence_eligible) error stop 'unready'
  g%complete=.true.
  call compose_crop_lifecycle_daily_candidate(p,g,a,st)
  if(st/=CROP_DAILY_OK.or..not.a%emergence_eligible) error stop 'ready'
  call compose_crop_lifecycle_daily_candidate(p,g,b,st)
  if(a%emergence_eligible.neqv.b%emergence_eligible) error stop 'replay'
  if(a%preparation_delay/=b%preparation_delay.or.a%sowing_delay/=b%sowing_delay) error stop 'delays'
  print '(a)','SW431_CROP_DAILY_COMPOSITION=PASS'
end program
