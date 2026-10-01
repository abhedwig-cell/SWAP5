#!/usr/bin/env python3
"""F-MACRO-TRACER01-A: disposable conservative matrix-tracer reference kernel."""

from __future__ import annotations
from dataclasses import dataclass
import copy
import json
import math
from typing import Optional

TOL = 1.0e-12

@dataclass(frozen=True)
class TracerState:
    mass: tuple[float, ...]
    generation: int = 0

@dataclass(frozen=True)
class WaterTransfer:
    water: float
    donor: Optional[int]
    receiver: Optional[int]
    external_concentration: Optional[float] = None
    label: str = ''

@dataclass(frozen=True)
class TrialResult:
    valid: bool
    reason: str
    candidate: Optional[TracerState]
    external_input_mass: float
    external_output_mass: float
    tracer_residual: float
    water_residual_max: float
    reconstructed_end_water: tuple[float, ...]

def _finite_nonnegative(values):
    return all(math.isfinite(x) and x >= 0.0 for x in values)

def _close(a, b, scale=1.0):
    return abs(a - b) <= TOL * max(scale, 1.0)

def validate_state(state: TracerState, nlayer: int) -> None:
    if state.generation < 0:
        raise ValueError('negative tracer generation')
    if len(state.mass) != nlayer:
        raise ValueError('tracer layer count mismatch')
    if not _finite_nonnegative(state.mass):
        raise ValueError('invalid tracer mass')

def validate_water(start_water, end_water) -> None:
    if len(start_water) == 0 or len(start_water) != len(end_water):
        raise ValueError('invalid water layer shape')
    if not _finite_nonnegative(start_water) or not _finite_nonnegative(end_water):
        raise ValueError('invalid water storage')

def validate_transfer(event: WaterTransfer, nlayer: int) -> None:
    if not math.isfinite(event.water) or event.water < 0.0:
        raise ValueError('invalid transfer water')
    if event.donor is None and event.receiver is None:
        raise ValueError('transfer has no endpoint')
    if event.donor is not None and not 0 <= event.donor < nlayer:
        raise ValueError('invalid donor index')
    if event.receiver is not None and not 0 <= event.receiver < nlayer:
        raise ValueError('invalid receiver index')
    if event.donor is not None and event.receiver is not None and event.donor == event.receiver:
        raise ValueError('self-transfer is not a physical route')
    if event.donor is None:
        if event.external_concentration is None:
            raise ValueError('external inflow requires concentration')
        if not math.isfinite(event.external_concentration) or event.external_concentration < 0.0:
            raise ValueError('invalid external concentration')
    elif event.external_concentration is not None:
        raise ValueError('external concentration only valid for external inflow')

def evaluate_trial(accepted: TracerState, start_water, end_water, transfers) -> TrialResult:
    start_water = tuple(float(x) for x in start_water)
    end_water = tuple(float(x) for x in end_water)
    nlayer = len(start_water)
    try:
        validate_water(start_water, end_water)
        validate_state(accepted, nlayer)
        events = tuple(transfers)
        for event in events:
            validate_transfer(event, nlayer)
    except (ValueError, TypeError) as exc:
        return TrialResult(False, str(exc), None, 0.0, 0.0, math.nan, math.nan, tuple())

    water = list(start_water)
    mass = list(accepted.mass)
    initial_mass = sum(mass)
    external_input = 0.0
    external_output = 0.0

    for event in events:
        amount = event.water
        if amount == 0.0:
            continue
        if event.donor is None:
            tracer = amount * event.external_concentration
            water[event.receiver] += amount
            mass[event.receiver] += tracer
            external_input += tracer
            continue

        d = event.donor
        if amount > water[d] + TOL * max(1.0, water[d]):
            return TrialResult(False, 'water transfer exceeds donor storage: ' + (event.label or 'unnamed'), None, external_input, external_output, math.nan, math.nan, tuple(water))

        if water[d] <= TOL:
            if mass[d] > TOL:
                return TrialResult(False, 'positive tracer mass in dry donor: ' + (event.label or 'unnamed'), None, external_input, external_output, math.nan, math.nan, tuple(water))
            concentration = 0.0
        else:
            concentration = mass[d] / water[d]

        tracer = min(mass[d], amount * concentration)
        water[d] -= amount
        mass[d] -= tracer
        if event.receiver is None:
            external_output += tracer
        else:
            water[event.receiver] += amount
            mass[event.receiver] += tracer

        if water[d] < 0.0 and abs(water[d]) <= TOL:
            water[d] = 0.0
        if mass[d] < 0.0 and abs(mass[d]) <= TOL:
            mass[d] = 0.0

    water_residual_max = max(abs(a-b) for a,b in zip(water,end_water))
    if any(not _close(a,b,max(abs(a),abs(b),1.0)) for a,b in zip(water,end_water)):
        return TrialResult(False, 'reconstructed water end state does not match hydrology owner', None, external_input, external_output, math.nan, water_residual_max, tuple(water))

    if not _finite_nonnegative(mass):
        return TrialResult(False, 'invalid candidate tracer mass', None, external_input, external_output, math.nan, water_residual_max, tuple(water))

    final_mass = sum(mass)
    tracer_residual = initial_mass + external_input - external_output - final_mass
    scale = max(initial_mass + external_input, external_output + final_mass, 1.0)
    if abs(tracer_residual) > TOL * scale:
        return TrialResult(False, 'tracer ledger does not close', None, external_input, external_output, tracer_residual, water_residual_max, tuple(water))

    candidate = TracerState(tuple(mass), accepted.generation + 1)
    return TrialResult(True, 'TRIAL_VALID', candidate, external_input, external_output, tracer_residual, water_residual_max, tuple(water))

def commit_trial(accepted: TracerState, result: TrialResult) -> TracerState:
    if not result.valid or result.candidate is None:
        raise ValueError('cannot commit invalid tracer trial')
    if result.candidate.generation != accepted.generation + 1:
        raise ValueError('candidate generation mismatch')
    return copy.deepcopy(result.candidate)

def _demo():
    accepted = TracerState((0.0, 0.0, 0.0))
    start = (1.0, 1.0, 1.0)
    transfers = (
        WaterTransfer(0.2, None, 0, 2.0, 'surface tracer input'),
        WaterTransfer(0.1, 0, 1, label='matrix interface 1'),
        WaterTransfer(0.05, 1, 2, label='matrix interface 2'),
        WaterTransfer(0.02, 2, None, label='bottom export'),
    )
    end = (1.1, 1.05, 1.03)
    trial = evaluate_trial(accepted, start, end, transfers)
    return {
        'trial_valid': trial.valid,
        'reason': trial.reason,
        'candidate_mass': list(trial.candidate.mass) if trial.candidate else None,
        'external_input_mass': trial.external_input_mass,
        'external_output_mass': trial.external_output_mass,
        'tracer_residual': trial.tracer_residual,
        'water_residual_max': trial.water_residual_max,
    }

if __name__ == '__main__':
    print(json.dumps({'schema':'swap5.f_macro_tracer01.reference_kernel.v1','status':'RESEARCH_ONLY','demo':_demo()}, indent=2, sort_keys=True))
