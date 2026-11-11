"""Accepted-day view of read-only original heat observations.

Conduction closure is a numerical equation check. Missing mass-carried energy
never becomes a complete physical energy balance, even when that check passes.
"""
from collections import Counter
import math
from pathlib import Path

# Existing soil_temperature_numerical_config_t budget and DailyHost clock guard.
ENERGY_BUDGET_J_CM2 = 1e-9
CLOCK_BUDGET_DAY = 1e-8


def read_accepted_heat(path, receipts, project):
    accepted = {}
    for receipt in receipts:
        if receipt.get('committed') is not True:
            continue
        day = receipt['day']
        if type(day) is not int or day < 1 or day in accepted:
            raise ValueError('Invalid or duplicate accepted day')
        if len(receipt['pressure_head_cm']) != project.nodes:
            raise ValueError('Accepted project grid differs')
        accepted[day] = []
    lines = iter(Path(path).read_text().splitlines())
    ignored = 0
    while True:
        header = next(lines, None)
        if header is None:
            break
        fields = header.split()
        if len(fields) != 17 or fields[0] != 'HEAT_STEP':
            raise ValueError('Invalid original heat step frame')
        numbers = list(map(float, fields[1:14]))
        if not all(map(math.isfinite, numbers)):
            raise ValueError('Nonfinite original heat step')
        t0, dt = numbers[:2]
        n, storage_status, assumed_status = map(int, fields[3:6])
        if n != project.nodes or dt <= 0:
            raise ValueError('Invalid original heat grid or interval')
        flags = fields[14:]
        if any(flag not in ('T', 'F') for flag in flags) or flags[2] != 'F':
            raise ValueError('Invalid or promoted original full-energy flag')
        nodes = []
        for i in range(1, n+1):
            row = next(lines, '').split()
            if len(row) != 12 or row[0] != 'HEAT_NODE' or row[1] != str(i):
                raise ValueError('Invalid original heat node frame')
            values = list(map(float, row[2:]))
            if not all(map(math.isfinite, values)) or values[0] <= 0 or values[6] <= 0:
                raise ValueError('Nonfinite or nonphysical original heat coefficient')
            nodes.append(values)
        day = math.floor(t0-project.start_clock)+1
        if t0+dt > project.start_clock+day+CLOCK_BUDGET_DAY:
            raise ValueError('Heat observation crosses accepted day support')
        if day not in accepted:
            ignored += 1
            continue
        # Independent reconstruction from the ACTUAL exported solve coefficients,
        # not an evaluation of another temperature model or copied constitutive law.
        storage = [v[0]*v[6]*(v[5]-v[4]) for v in nodes]
        cell = [abs(s-(v[8]-v[9])) for s,v in zip(storage,nodes)]
        boundary = nodes[0][8]-nodes[-1][9]
        for left,right in zip(nodes,nodes[1:]):
            if left[9] != right[8]:
                raise ValueError('Conductive faces do not cancel internally')
        frozen = math.fsum(storage)
        if (max(cell) > ENERGY_BUDGET_J_CM2 or abs(frozen-boundary) > ENERGY_BUDGET_J_CM2
                or abs(frozen-numbers[5]) > ENERGY_BUDGET_J_CM2
                or abs(boundary-numbers[6]) > ENERGY_BUDGET_J_CM2):
            raise ValueError('Original conduction exceeds existing energy budget')
        if flags[0] == 'T' and storage_status != 3:
            raise ValueError('Missing advective boundary was not refused by the storage owner')
        if flags[1] != 'F':
            raise ValueError('Missing advective/reference energy was relabelled complete')
        accepted[day].append({'t0':t0,'dt':dt,'storage_status':storage_status,
            'counterfactual_status':assumed_status,'frozen_storage_j_cm2':frozen,
            'conductive_into_j_cm2':boundary,'cell_residual_max_j_cm2':max(cell),
            'global_conduction_residual_j_cm2':frozen-boundary,
            'physical_storage_complete':flags[0]=='T',
            'physical_storage_change_j_cm2':numbers[8],
            'composition_change_j_cm2':numbers[10],
            'zero_advection_projected_residual_j_cm2':numbers[12]})
    daily = []
    for day,steps in sorted(accepted.items()):
        if not steps or abs(math.fsum(s['dt'] for s in steps)-1) > CLOCK_BUDGET_DAY:
            raise ValueError('Accepted day has no complete original heat support')
        complete = all(s['physical_storage_complete'] for s in steps)
        daily.append({'day':day,'accepted':True,'steps':len(steps),
            'numerical_conduction_complete':True,'full_energy_balance_complete':False,
            'sensible_mass_carried_boundary_complete':False,
            'storage_status_counts':dict(Counter(s['storage_status'] for s in steps)),
            'conductive_into_j_cm2':math.fsum(s['conductive_into_j_cm2'] for s in steps),
            'cell_residual_max_j_cm2':max(s['cell_residual_max_j_cm2'] for s in steps),
            'global_step_residual_max_j_cm2':max(abs(s['global_conduction_residual_j_cm2']) for s in steps),
            'physical_storage_complete':complete,
            'physical_storage_change_j_cm2':math.fsum(s['physical_storage_change_j_cm2'] for s in steps) if complete else None,
            'composition_change_j_cm2':math.fsum(s['composition_change_j_cm2'] for s in steps) if complete else None,
            'zero_advection_step_residual_max_j_cm2':max(abs(s['zero_advection_projected_residual_j_cm2']) for s in steps) if complete else None})
    return {'status':'ACCEPTED_ORIGINAL_CONDUCTION_WITH_EXPLICIT_PHYSICAL_ENERGY_LIMITS',
            'model':project.model,'daily':daily,'unaccepted_steps_ignored':ignored,
            'energy_budget_j_cm2':ENERGY_BUDGET_J_CM2,'full_energy_balance_complete':False}
