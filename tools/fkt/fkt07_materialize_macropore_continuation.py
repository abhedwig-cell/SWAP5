#!/usr/bin/env python3
from pathlib import Path

PATH = Path('src/adapter/mod_b1_10_process_checkpoint.f90')
text = PATH.read_text()
marker = 'type, public :: b1_10_macropore_continuation_t'
if marker in text:
    print('F-KT07 materialization already present')
    raise SystemExit(0)

replacements = [
    (
"""  type, public :: b1_10_irrigation_state_t
    integer :: dayfix = 0
    integer :: nirri = 0
  end type
""",
"""  type, public :: b1_10_irrigation_state_t
    integer :: dayfix = 0
    integer :: nirri = 0
  end type

  ! Compact optional cross-call continuation for the B1.10 macropore route.
  ! This is physical/process continuation, not solver scratch or reporting history.
  type, public :: b1_10_macropore_continuation_t
    integer :: nstep = 0
  end type
"""
    ),
    (
"""    type(b1_10_crop_common_state_t), allocatable :: crop
    type(b1_10_wofost_state_t), allocatable :: wofost
""",
"""    type(b1_10_crop_common_state_t), allocatable :: crop
    type(b1_10_wofost_state_t), allocatable :: wofost
    type(b1_10_macropore_continuation_t), allocatable :: macropore
"""
    ),
    (
"""  public :: capture_b1_10_process_state, restore_b1_10_process_state
""",
"""  public :: capture_b1_10_process_state, restore_b1_10_process_state
  public :: bind_b1_10_macropore_continuation, read_b1_10_macropore_continuation
  public :: clear_b1_10_macropore_continuation, b1_10_macropore_continuation_complete
"""
    ),
    (
"""  subroutine b1_10_process_clone(self, copy)
""",
"""  subroutine bind_b1_10_macropore_continuation(state, nstep, accepted)
    type(b1_10_process_state_t), intent(inout) :: state
    integer, intent(in) :: nstep
    logical, intent(out) :: accepted

    accepted = .false.
    if (nstep < 0) return
    if (.not. allocated(state%macropore)) allocate(state%macropore)
    state%macropore%nstep = nstep
    accepted = .true.
  end subroutine bind_b1_10_macropore_continuation

  subroutine read_b1_10_macropore_continuation(state, nstep, available)
    type(b1_10_process_state_t), intent(in) :: state
    integer, intent(out) :: nstep
    logical, intent(out) :: available

    available = allocated(state%macropore)
    if (available) then
      nstep = state%macropore%nstep
    else
      nstep = 0
    end if
  end subroutine read_b1_10_macropore_continuation

  subroutine clear_b1_10_macropore_continuation(state)
    type(b1_10_process_state_t), intent(inout) :: state
    if (allocated(state%macropore)) deallocate(state%macropore)
  end subroutine clear_b1_10_macropore_continuation

  logical function b1_10_macropore_continuation_complete(state, macropore_active) result(complete)
    type(b1_10_process_state_t), intent(in) :: state
    logical, intent(in) :: macropore_active

    if (macropore_active) then
      complete = allocated(state%macropore)
      if (complete) complete = state%macropore%nstep >= 0
    else
      complete = .not. allocated(state%macropore)
    end if
  end function b1_10_macropore_continuation_complete

  subroutine b1_10_process_clone(self, copy)
"""
    ),
    (
"""      target%crop = self%crop
      target%wofost = self%wofost
""",
"""      target%crop = self%crop
      target%wofost = self%wofost
      target%macropore = self%macropore
"""
    ),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-KT07 exact anchor count {count}, expected 1: {old.splitlines()[0]}')
    text = text.replace(old, new, 1)

PATH.write_text(text)
print('F-KT07 macropore continuation materialized')
