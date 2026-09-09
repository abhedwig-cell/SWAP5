from pathlib import Path

path = Path('tests/fmr/run_fmr18_multiswap_receipt_gate.sh')
src = path.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global src
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'F-MR18 Gate C harness fix anchor count={count}: {old!r}')
    src = src.replace(old, new, 1)

replace_once(
    'FMR05_QUAL="qualification/f-vq15-fmr05-serialized-multiswap"',
    'FMR05_QUAL="origin/qualification/f-vq15-fmr05-serialized-multiswap"')

replace_once(
    '           "  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t\\n"\n'
    '           "  use mod_fmr_serialized_multiswap_runtime, only: FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED\\n")',
    '           "  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_commit_receipt_record_t, &\\n"\n'
    '           "       FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED\\n")')

src = src.replace('type(fmr_accepted_commit_receipt_t), allocatable :: receipts_a(:), receipts_a2(:), receipts_fail(:), receipts_invalid(:)',
                  'type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts_a(:), receipts_a2(:), receipts_fail(:), receipts_invalid(:)')
src = src.replace('type(fmr_accepted_commit_receipt_t), allocatable, intent(out) :: receipts(:)',
                  'type(fmr_serialized_commit_receipt_record_t), allocatable, intent(out) :: receipts(:)')
src = src.replace('type(fmr_accepted_commit_receipt_t), intent(in) :: receipt',
                  'type(fmr_serialized_commit_receipt_record_t), intent(in) :: receipt')
src = src.replace('type(fmr_accepted_commit_receipt_t), intent(in) :: left(:), right(:)',
                  'type(fmr_serialized_commit_receipt_record_t), intent(in) :: left(:), right(:)')

replace_once(
    "    call require(receipt%ready(), 'requested receipt ready')\\n"
    "    call require(receipt%current_lineage_id() == lineage, 'receipt lineage identity')\\n"
    "    call require(receipt%origin_revision() == origin_revision, 'receipt origin revision identity')\\n"
    "    call require(receipt%committed_revision() == committed_revision, 'receipt committed revision identity')\\n"
    "    call receipt%origin_interval(actual_t0, actual_t1, available)\\n",
    "    call require(receipt%column_id == lineage, 'receipt record column id identity')\\n"
    "    call require(receipt%receipt%ready(), 'requested receipt ready')\\n"
    "    call require(receipt%receipt%current_lineage_id() == lineage, 'receipt lineage identity')\\n"
    "    call require(receipt%receipt%origin_revision() == origin_revision, 'receipt origin revision identity')\\n"
    "    call require(receipt%receipt%committed_revision() == committed_revision, 'receipt committed revision identity')\\n"
    "    call receipt%receipt%origin_interval(actual_t0, actual_t1, available)\\n")

replace_once(
    "  call require(receipts_fail(1)%ready(), 'accepted requested neighbor receipt')\\n"
    "  call require(.not. receipts_fail(2)%ready(), 'rejected requested column no receipt')\\n",
    "  call require(receipts_fail(1)%column_id == failure_ids(1) .and. receipts_fail(1)%receipt%ready(), &\\n"
    "       'accepted requested neighbor receipt')\\n"
    "  call require(receipts_fail(2)%column_id == failure_ids(2) .and. .not. receipts_fail(2)%receipt%ready(), &\\n"
    "       'rejected requested column no receipt')\\n")

replace_once(
    "      if (left(i)%ready() .neqv. right(i)%ready()) then\\n"
    "        equal = .false.; return\\n"
    "      end if\\n"
    "      if (.not. left(i)%ready()) cycle\\n"
    "      if (left(i)%current_lineage_id() /= right(i)%current_lineage_id() .or. &\\n"
    "          left(i)%origin_revision() /= right(i)%origin_revision() .or. &\\n"
    "          left(i)%committed_revision() /= right(i)%committed_revision()) then\\n"
    "        equal = .false.; return\\n"
    "      end if\\n"
    "      call left(i)%origin_interval(lt0, lt1, la)\\n"
    "      call right(i)%origin_interval(rt0, rt1, ra)\\n",
    "      if (left(i)%column_id /= right(i)%column_id) then\\n"
    "        equal = .false.; return\\n"
    "      end if\\n"
    "      if (left(i)%receipt%ready() .neqv. right(i)%receipt%ready()) then\\n"
    "        equal = .false.; return\\n"
    "      end if\\n"
    "      if (.not. left(i)%receipt%ready()) cycle\\n"
    "      if (left(i)%receipt%current_lineage_id() /= right(i)%receipt%current_lineage_id() .or. &\\n"
    "          left(i)%receipt%origin_revision() /= right(i)%receipt%origin_revision() .or. &\\n"
    "          left(i)%receipt%committed_revision() /= right(i)%receipt%committed_revision()) then\\n"
    "        equal = .false.; return\\n"
    "      end if\\n"
    "      call left(i)%receipt%origin_interval(lt0, lt1, la)\\n"
    "      call right(i)%receipt%origin_interval(rt0, rt1, ra)\\n")

path.write_text(src, encoding='utf-8')
print('FMR18_GATE_C_HARNESS_ALIGNED_TO_SELF_DESCRIBING_RECORDS=PASS')
