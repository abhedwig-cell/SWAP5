using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA_M2 = 1000.0
const ALLOC_TOL_CM = 1.0e-6
const SUPPLY_TOL_CM = 1.0e-4
const REPLAY_DEPTH_TOL_CM = 1.0e-8
const REPLAY_LEVEL_TOL_M = 1.0e-10
const TIME_TOL_S = 1.0e-9
const EXPECTED_MIN_LEVEL_M = 0.90
const REQUIRED_MARGIN_MULTIPLE = 3.0

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present")
    return idx
end

function user_id(model)
    return Ribasim.NodeID(:UserDemand, 3, model.integrator.p.p_independent)
end

function basin_id(model)
    return Ribasim.NodeID(:Basin, 2, model.integrator.p.p_independent)
end

function allocation_depth_cm(model)::Float64
    (; user_demand, allocation) = model.integrator.p.p_independent
    id = user_id(model)
    idx = priority_index(allocation.demand_priorities_all, 2)
    rate_m3_s = user_demand.allocated[id.idx, idx]
    return rate_m3_s * DAY / AREA_M2 * 100.0
end

function cumulative_supply_depth_cm(model)::Float64
    id = user_id(model)
    volume_m3 = BMI.get_value_ptr(model, "user_demand.cumulative_inflow")[id.idx]
    return volume_m3 / AREA_M2 * 100.0
end

function current_basin_level(model)::Float64
    id = basin_id(model)
    return BMI.get_value_ptr(model, "basin.level")[id.idx]
end

function run_candidate(path::AbstractString)
    model = BMI.initialize(Ribasim.Model, path)
    try
        require(isapprox(BMI.get_current_time(model), 0.0; atol=TIME_TOL_S, rtol=0.0),
            "candidate did not initialize at t=0")
        BMI.update_until(model, DAY)
        require(isapprox(BMI.get_current_time(model), DAY; atol=TIME_TOL_S, rtol=0.0),
            "candidate did not stop at aligned one-day boundary")
        return (
            allocated_cm = allocation_depth_cm(model),
            supplied_cm = cumulative_supply_depth_cm(model),
            level_m = current_basin_level(model),
        )
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 2 || error(
        "usage: rm09_real_ribasim_bridge.jl <ribasim.toml> <expected-request-depth-cm>"
    )
    path = abspath(ARGS[1])
    expected_request_cm = parse(Float64, ARGS[2])
    require(isfile(path), "RM09 Ribasim input missing")

    # This instance is the accepted surface-water origin witness. It is never advanced.
    accepted = BMI.initialize(Ribasim.Model, path)
    accepted_t0 = BMI.get_current_time(accepted)
    accepted_level0 = current_basin_level(accepted)
    accepted_supply0 = cumulative_supply_depth_cm(accepted)
    (; p_independent) = accepted.integrator.p
    bid = basin_id(accepted)
    uid = user_id(accepted)
    threshold = p_independent.level_difference_threshold
    configured_min_level = p_independent.user_demand.min_level[uid.idx]
    margin = accepted_level0 - configured_min_level
    low_storage_factor = Ribasim.get_low_storage_factor(accepted.integrator.p, bid)

    require(isapprox(accepted_t0, 0.0; atol=TIME_TOL_S, rtol=0.0), "accepted origin time")
    require(isapprox(configured_min_level, EXPECTED_MIN_LEVEL_M; atol=1.0e-12, rtol=0.0),
        "unexpected UserDemand min_level")
    require(margin + 1.0e-12 >= REQUIRED_MARGIN_MULTIPLE * threshold,
        "accepted origin violates full-realization level-margin precondition")
    require(isapprox(low_storage_factor, 1.0; atol=1.0e-12, rtol=0.0),
        "accepted origin low-storage factor is not one")
    println(
        "RM09_RIBASIM_FULL_REALIZATION_PRECONDITION=PASS " *
        "level_m=$(repr(accepted_level0)) min_level_m=$(repr(configured_min_level)) " *
        "threshold_m=$(repr(threshold)) margin_m=$(repr(margin)) " *
        "low_storage_factor=$(repr(low_storage_factor))"
    )
    require(isapprox(accepted_supply0, 0.0; atol=REPLAY_DEPTH_TOL_CM, rtol=0.0),
        "accepted origin has nonzero UserDemand supply")

    a = run_candidate(path)

    # Candidate A was discarded/finalized. The accepted origin must still be untouched.
    require(isapprox(BMI.get_current_time(accepted), accepted_t0; atol=TIME_TOL_S, rtol=0.0),
        "discarded candidate changed accepted Ribasim time")
    require(isapprox(current_basin_level(accepted), accepted_level0; atol=REPLAY_LEVEL_TOL_M, rtol=0.0),
        "discarded candidate changed accepted Ribasim Basin state")
    require(isapprox(cumulative_supply_depth_cm(accepted), accepted_supply0;
                     atol=REPLAY_DEPTH_TOL_CM, rtol=0.0),
        "discarded candidate changed accepted Ribasim supply ledger")

    b = run_candidate(path)

    println(
        "RM09_RIBASIM_DIAGNOSTIC " *
        "a_allocated_cm=$(repr(a.allocated_cm)) a_supplied_cm=$(repr(a.supplied_cm)) a_level_m=$(repr(a.level_m)) " *
        "b_allocated_cm=$(repr(b.allocated_cm)) b_supplied_cm=$(repr(b.supplied_cm)) b_level_m=$(repr(b.level_m)) " *
        "expected_request_cm=$(repr(expected_request_cm))"
    )

    require(isapprox(a.allocated_cm, b.allocated_cm; atol=REPLAY_DEPTH_TOL_CM, rtol=0.0),
        "same-origin allocation replay drift")
    require(isapprox(a.supplied_cm, b.supplied_cm; atol=REPLAY_DEPTH_TOL_CM, rtol=0.0),
        "same-origin physical supply replay drift")
    require(isapprox(a.level_m, b.level_m; atol=REPLAY_LEVEL_TOL_M, rtol=0.0),
        "same-origin Basin endpoint replay drift")

    require(isapprox(b.allocated_cm, expected_request_cm; atol=ALLOC_TOL_CM, rtol=0.0),
        "real Ribasim allocation differs from SWAP request")
    require(isapprox(b.supplied_cm, expected_request_cm; atol=SUPPLY_TOL_CM, rtol=0.0),
        "real Ribasim physical supply differs from SWAP request")

    println("RM09_RIBASIM_ACCEPTED_ORIGIN_IMMUTABLE=PASS")
    println("RM09_RIBASIM_CANDIDATE_REPLAY=PASS")
    println("RM09_RIBASIM_FULL_ALLOCATION=PASS")
    println("RM09_RIBASIM_FULL_PHYSICAL_SUPPLY=PASS")
    println("RM09_RIBASIM_ALLOCATED_DEPTH_CM=$(repr(b.allocated_cm))")
    println("RM09_RIBASIM_SUPPLIED_DEPTH_CM=$(repr(b.supplied_cm))")
    println("RM09_RIBASIM_FINAL_BASIN_LEVEL_M=$(repr(b.level_m))")
    println("RM09_RIBASIM_STORAGE_GAIN_M3=$(repr((b.level_m - accepted_level0) * AREA_M2))")
    println("RM09 REAL RIBASIM ALIGNED FIXTURE PASS")
    BMI.finalize(accepted)
end

main()
