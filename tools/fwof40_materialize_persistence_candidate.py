#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 5:
    raise SystemExit('usage: materializer <lineage_in> <tx_in> <lineage_out> <tx_out>')

lineage = Path(sys.argv[1]).read_text(encoding='utf-8')
tx = Path(sys.argv[2]).read_text(encoding='utf-8')

# The candidate API is materialized from source-bound F-WOF39 owners. It is
# intentionally explicit. No TRANSFER/object-memory serialization is allowed.
status_anchor = '  integer, parameter, public :: FMR_WOFOST_LINEAGE_TRIAL_WINDOW_MISMATCH = 12\n'
status_insert = status_anchor + '  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE = 13\n'
if lineage.count(status_anchor) != 1:
    raise SystemExit(f'lineage status anchor count={lineage.count(status_anchor)}')
lineage = lineage.replace(status_anchor, status_insert, 1)

type_anchor = '''  end type fmr_wofost_crop_event_identity_t

  public :: certify_fkt_accepted_interval
'''
type_insert = '''  end type fmr_wofost_crop_event_identity_t

  ! Serialization-neutral owner view of the committed crop-event receipt.
  ! This is data, not commit authority. External adapters may encode these
  ! fields, but reconstruction is validated by this owner module.
  type, public :: fmr_wofost_crop_event_identity_persistence_t
    logical :: valid = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
  contains
    procedure, public :: ready => crop_event_identity_persistence_ready
  end type fmr_wofost_crop_event_identity_persistence_t

  public :: certify_fkt_accepted_interval
'''
if lineage.count(type_anchor) != 1:
    raise SystemExit(f'lineage type anchor count={lineage.count(type_anchor)}')
lineage = lineage.replace(type_anchor, type_insert, 1)

public_anchor = '''  public :: crop_event_identity_matches_interval

contains
'''
public_insert = '''  public :: crop_event_identity_matches_interval
  public :: export_wofost_crop_event_identity_persistence
  public :: reconstruct_wofost_crop_event_identity_from_persistence

contains

  logical function crop_event_identity_persistence_ready(self) result(ready)
    class(fmr_wofost_crop_event_identity_persistence_t), intent(in) :: self
    ready = .false.
    if (.not. self%valid) return
    if (self%lineage_id <= 0_int64 .or. self%final_revision < 0_int64) return
    if (.not. ieee_is_finite(self%t0) .or. .not. ieee_is_finite(self%t1)) return
    if (self%t1 <= self%t0) return
    if (.not. ieee_is_finite(self%actual_root_uptake_integral)) return
    if (.not. ieee_is_finite(self%potential_transpiration_integral)) return
    if (self%actual_root_uptake_integral < 0.0_real64) return
    if (self%potential_transpiration_integral < 0.0_real64) return
    ready = .true.
  end function crop_event_identity_persistence_ready

  subroutine export_wofost_crop_event_identity_persistence(identity, view, exported)
    type(fmr_wofost_crop_event_identity_t), intent(in) :: identity
    type(fmr_wofost_crop_event_identity_persistence_t), intent(out) :: view
    logical, intent(out) :: exported

    view = fmr_wofost_crop_event_identity_persistence_t()
    exported = .false.
    if (.not. identity%ready()) return
    view%lineage_id = identity%lineage_id
    view%final_revision = identity%final_revision
    view%t0 = identity%t0
    view%t1 = identity%t1
    view%actual_root_uptake_integral = identity%actual_root_uptake_integral
    view%potential_transpiration_integral = identity%potential_transpiration_integral
    view%valid = .true.
    exported = view%ready()
    if (.not. exported) view = fmr_wofost_crop_event_identity_persistence_t()
  end subroutine export_wofost_crop_event_identity_persistence

  subroutine reconstruct_wofost_crop_event_identity_from_persistence(view, identity, status)
    type(fmr_wofost_crop_event_identity_persistence_t), intent(in) :: view
    type(fmr_wofost_crop_event_identity_t), intent(out) :: identity
    integer, intent(out) :: status

    identity = fmr_wofost_crop_event_identity_t()
    status = FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE
    if (.not. view%ready()) return
    identity%lineage_id = view%lineage_id
    identity%final_revision = view%final_revision
    identity%t0 = view%t0
    identity%t1 = view%t1
    identity%actual_root_uptake_integral = view%actual_root_uptake_integral
    identity%potential_transpiration_integral = view%potential_transpiration_integral
    identity%initialized = .true.
    if (.not. identity%ready()) then
      identity = fmr_wofost_crop_event_identity_t()
      return
    end if
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine reconstruct_wofost_crop_event_identity_from_persistence
'''
if lineage.count(public_anchor) != 1:
    raise SystemExit(f'lineage public anchor count={lineage.count(public_anchor)}')
lineage = lineage.replace(public_anchor, public_insert, 1)

use_anchor = '''  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       prepare_wofost_crop_event_delivery, identify_wofost_crop_event, &
       same_wofost_crop_event_identity, crop_event_identity_matches_interval, FMR_WOFOST_LINEAGE_OK
'''
use_insert = '''  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, &
       prepare_wofost_crop_event_delivery, identify_wofost_crop_event, &
       same_wofost_crop_event_identity, crop_event_identity_matches_interval, FMR_WOFOST_LINEAGE_OK, &
       export_wofost_crop_event_identity_persistence, &
       reconstruct_wofost_crop_event_identity_from_persistence
'''
if tx.count(use_anchor) != 1:
    raise SystemExit(f'transaction use anchor count={tx.count(use_anchor)}')
tx = tx.replace(use_anchor, use_insert, 1)

const_anchor = '  integer, parameter, public :: FMR_WOF38_INVALID_TRANSACTION_STATE = 9\n'
const_insert = const_anchor + '''
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_OK = 0
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE = 1
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW = 2
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT = 3
'''
if tx.count(const_anchor) != 1:
    raise SystemExit(f'transaction constant anchor count={tx.count(const_anchor)}')
tx = tx.replace(const_anchor, const_insert, 1)

tx_type_anchor = '''  end type fmr_wofost_crop_transaction_state_t

  type, extends(kernel_parameters_t), public :: fmr_wofost_crop_transaction_parameters_t
'''
tx_type_insert = '''  end type fmr_wofost_crop_transaction_state_t

  ! Compact physical continuation view. Parameters, forcing and retired
  ! accepted-window cache are deliberately absent.
  type, public :: fmr_wofost_crop_transaction_persistence_t
    logical :: valid = .false.
    type(wofost_crop_owner_state_t) :: owner
    logical :: receipt_present = .false.
    type(fmr_wofost_crop_event_identity_persistence_t) :: receipt
  contains
    procedure, public :: ready => fmr_wofost_crop_transaction_persistence_ready
  end type fmr_wofost_crop_transaction_persistence_t

  type, extends(kernel_parameters_t), public :: fmr_wofost_crop_transaction_parameters_t
'''
if tx.count(tx_type_anchor) != 1:
    raise SystemExit(f'transaction type anchor count={tx.count(tx_type_anchor)}')
tx = tx.replace(tx_type_anchor, tx_type_insert, 1)

pub_anchor = '''  public :: prepare_fmr_wofost_crop_event_forcing

contains
'''
pub_insert = '''  public :: prepare_fmr_wofost_crop_event_forcing
  public :: export_fmr_wofost_crop_transaction_persistence
  public :: reconstruct_fmr_wofost_crop_transaction_from_persistence

contains

  logical function fmr_wofost_crop_transaction_persistence_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_persistence_t), intent(in) :: self
    ready = .false.
    if (.not. self%valid) return
    if (self%owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (self%receipt_present) then
      if (.not. self%receipt%ready()) return
    else
      if (self%receipt%valid) return
    end if
    ready = .true.
  end function fmr_wofost_crop_transaction_persistence_ready

  subroutine export_fmr_wofost_crop_transaction_persistence(state, view, exported, status)
    type(fmr_wofost_crop_transaction_state_t), intent(in) :: state
    type(fmr_wofost_crop_transaction_persistence_t), intent(out) :: view
    logical, intent(out) :: exported
    integer, intent(out) :: status
    logical :: receipt_exported

    view = fmr_wofost_crop_transaction_persistence_t()
    exported = .false.
    status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE
    if (.not. state%ready()) return
    view%owner = state%owner
    if (state%last_consumed_event%ready()) then
      call export_wofost_crop_event_identity_persistence(state%last_consumed_event, view%receipt, receipt_exported)
      if (.not. receipt_exported) then
        status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT
        return
      end if
      view%receipt_present = .true.
    end if
    view%valid = .true.
    if (.not. view%ready()) then
      view = fmr_wofost_crop_transaction_persistence_t()
      status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW
      return
    end if
    exported = .true.
    status = FMR_WOFOST_CROP_PERSISTENCE_OK
  end subroutine export_fmr_wofost_crop_transaction_persistence

  subroutine reconstruct_fmr_wofost_crop_transaction_from_persistence(view, state, reconstructed, status)
    type(fmr_wofost_crop_transaction_persistence_t), intent(in) :: view
    type(fmr_wofost_crop_transaction_state_t), intent(out) :: state
    logical, intent(out) :: reconstructed
    integer, intent(out) :: status
    integer :: receipt_status

    state = fmr_wofost_crop_transaction_state_t()
    reconstructed = .false.
    status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW
    if (.not. view%ready()) return
    state%owner = view%owner
    if (view%receipt_present) then
      call reconstruct_wofost_crop_event_identity_from_persistence(view%receipt, state%last_consumed_event, receipt_status)
      if (receipt_status /= FMR_WOFOST_LINEAGE_OK) then
        state = fmr_wofost_crop_transaction_state_t()
        status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT
        return
      end if
    end if
    state%initialized = .true.
    if (.not. state%ready()) then
      state = fmr_wofost_crop_transaction_state_t()
      status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE
      return
    end if
    reconstructed = .true.
    status = FMR_WOFOST_CROP_PERSISTENCE_OK
  end subroutine reconstruct_fmr_wofost_crop_transaction_from_persistence
'''
if tx.count(pub_anchor) != 1:
    raise SystemExit(f'transaction public anchor count={tx.count(pub_anchor)}')
tx = tx.replace(pub_anchor, pub_insert, 1)

Path(sys.argv[3]).write_text(lineage, encoding='utf-8')
Path(sys.argv[4]).write_text(tx, encoding='utf-8')
print('FWOF40_OWNER_PERSISTENCE_CANDIDATE_MATERIALIZED=PASS')
