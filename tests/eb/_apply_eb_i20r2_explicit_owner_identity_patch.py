from pathlib import Path

p = Path('src/runtime/mod_energy_conservation_ledger.f90')
s = p.read_text(encoding='utf-8')

PRE_BLOB_MARKER = 'integer(int64) :: prepared_lineage_id = 0_int64'
if PRE_BLOB_MARKER not in s:
    raise SystemExit('EB-I20R2 preimage marker missing')

replacements = [
(
'''    integer(int64) :: generation = 0_int64
    integer(int64) :: lineage_id = 0_int64
''',
'''    integer(int64) :: generation = 0_int64
    integer(int64) :: owner_instance_id = 0_int64
    integer(int64) :: lineage_id = 0_int64
'''
),
(
'''    integer(int64) :: prepared_generation = 0_int64
    integer(int64) :: prepared_lineage_id = 0_int64
''',
'''    integer(int64) :: prepared_generation = 0_int64
    integer(int64) :: prepared_owner_instance_id = 0_int64
    integer(int64) :: prepared_lineage_id = 0_int64
'''
),
(
'''    real(real64) :: prepared_t1_value = 0.0_real64
    integer(int64) :: lineage_id = 0_int64
''',
'''    real(real64) :: prepared_t1_value = 0.0_real64
    integer(int64) :: owner_instance_id_value = 0_int64
    integer(int64) :: lineage_id = 0_int64
'''
),
(
'''  subroutine energy_ledger_begin_trial(self, lineage_id, origin_revision, t0, t1, component_ids, initial_energy_j_m2, &
                                       status, transfer_capacity)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer(int64), intent(in) :: lineage_id, origin_revision
''',
'''  subroutine energy_ledger_begin_trial(self, owner_instance_id, lineage_id, origin_revision, t0, t1, component_ids, &
                                       initial_energy_j_m2, status, transfer_capacity)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer(int64), intent(in) :: owner_instance_id, lineage_id, origin_revision
'''
),
(
'''    status = ENERGY_LEDGER_INVALID_PROVENANCE
    if (lineage_id <= 0_int64 .or. origin_revision < 0_int64) return
''',
'''    status = ENERGY_LEDGER_INVALID_PROVENANCE
    ! owner_instance_id is an explicit runtime/worker ownership token.  It must
    ! be positive and unique among simultaneously live logical ledger owners.
    ! The ledger deliberately does not allocate it through hidden global state.
    if (owner_instance_id <= 0_int64 .or. lineage_id <= 0_int64 .or. origin_revision < 0_int64) return
'''
),
(
'''    self%initial_snapshot = snapshot
    self%lineage_id = lineage_id
''',
'''    self%initial_snapshot = snapshot
    self%owner_instance_id_value = owner_instance_id
    self%lineage_id = lineage_id
'''
),
(
'''    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_lineage_id = self%lineage_id
''',
'''    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_owner_instance_id = self%owner_instance_id_value
    self%prepared_lineage_id = self%lineage_id
'''
),
(
'''    prepared%generation = self%prepared_generation
    prepared%lineage_id = self%lineage_id
''',
'''    prepared%generation = self%prepared_generation
    prepared%owner_instance_id = self%owner_instance_id_value
    prepared%lineage_id = self%lineage_id
'''
),
(
'''    ready = self%initialized .and. self%generation > 0_int64 .and. self%lineage_id > 0_int64 .and. &
''',
'''    ready = self%initialized .and. self%generation > 0_int64 .and. self%owner_instance_id > 0_int64 .and. &
         self%lineage_id > 0_int64 .and. &
'''
),
(
'''    if (prepared%generation /= self%prepared_generation) return
    if (prepared%lineage_id /= self%prepared_lineage_id) return
''',
'''    if (prepared%generation /= self%prepared_generation) return
    if (prepared%owner_instance_id /= self%prepared_owner_instance_id) return
    if (prepared%lineage_id /= self%prepared_lineage_id) return
'''
),
(
'''    self%prepared_generation = 0_int64
    self%prepared_lineage_id = 0_int64
''',
'''    self%prepared_generation = 0_int64
    self%prepared_owner_instance_id = 0_int64
    self%prepared_lineage_id = 0_int64
'''
),
(
'''    self%lineage_id = 0_int64
    self%origin_revision_value = -1_int64
''',
'''    self%owner_instance_id_value = 0_int64
    self%lineage_id = 0_int64
    self%origin_revision_value = -1_int64
'''
),
]

for old, new in replacements:
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'EB-I20R2 patch anchor count={count}: {old.splitlines()[0]}')
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
