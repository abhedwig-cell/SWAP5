using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA = 1_000_000.0
const ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
const ALLOCATION_TOL = 0.05
const VOLUME_TOL = 0.05
const LEVEL_TOL = 5.0e-8

const ROOT_FIRST_SHADOW = [
    (32.0, 0.0),
    (40.0, 7.99520096018381),
    (40.0, 20.0),
    (40.0, 20.0),
]
const EXTERNAL_FIRST_SHADOW = [
    (12.0, 20.0),
    (27.99520096018381, 20.0),
    (40.0, 20.0),
    (40.0, 20.0),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present")
    return idx
end

function user_id(model, node_id::Int)
    return Ribasim.NodeID(:UserDemand, node_id, model.integrator.p.p_independent)
end

function applied_user_allocated(model, node_id::Int, priority::Int)::Float64
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    id = user_id(model, node_id)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx]
end

function applied_link_allocated(model, node_id::Int)::Float64
    user_demand = model.integrator.p.p_independent.user_demand
    id = user_id(model, node_id)
    links = user_demand.inflow_link_allocated[id.idx]
    require(length(links) == 1, "expected exactly one UserDemand inflow link")
    return only(links)
end

function shadow_user_allocated(model, node_id::Int, priority::Int)::Float64
    (; allocation) = model.integrator.p.p_independent
    require(length(allocation.allocation_models) == 1, "expected exactly one allocation model")
    allocation_model = only(allocation.allocation_models)
    id = user_id(model, node_id)
    variable = allocation_model.problem[:user_demand_allocated][id, Int32(priority)]
    return JuMP.value(variable) * allocation_model.scaling.flow
end

function cumulative_user_inflow(model, node_id::Int)::Float64
    id = user_id(model, node_id)
    values = BMI.get_value_ptr(model, "user_demand.cumulative_inflow")
    return values[id.idx]
end

function basin_level(model)::Float64
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:Basin, 2, p_independent)
    return BMI.get_value_ptr(model, "basin.level")[id.idx]
end

function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
        expected_shadow,
        expected_applied_root::Float64,
        expected_applied_external::Float64,
        expected_root_volume::Float64,
        expected_external_volume::Float64,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")
    model = BMI.initialize(Ribasim.Model, path)

    for (i, endpoint) in enumerate(ENDPOINTS)
        BMI.update_until(model, endpoint)
        require(isapprox(BMI.get_current_time(model), endpoint; atol=1.0e-9, rtol=0.0), "$model_name did not stop at BMI endpoint")

        shadow_root = shadow_user_allocated(model, 3, root_priority) * DAY
        shadow_external = shadow_user_allocated(model, 4, external_priority) * DAY
        applied_root = applied_user_allocated(model, 3, root_priority) * DAY
        applied_external = applied_user_allocated(model, 4, external_priority) * DAY
        applied_root_link = applied_link_allocated(model, 3) * DAY
        applied_external_link = applied_link_allocated(model, 4) * DAY

        exp_shadow_root, exp_shadow_external = expected_shadow[i]

        require(isapprox(shadow_root, exp_shadow_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name shadow root allocation differs at segment $i")
        require(isapprox(shadow_external, exp_shadow_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name shadow external allocation differs at segment $i")
        require(isapprox(applied_root, expected_applied_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name applied root allocation changed at sub-saveat BMI solve")
        require(isapprox(applied_external, expected_applied_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name applied external allocation changed at sub-saveat BMI solve")
        require(isapprox(applied_root_link, expected_applied_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name applied root link allocation diverged from frozen applied state")
        require(isapprox(applied_external_link, expected_applied_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name applied external link allocation diverged from frozen applied state")

        println(
            "RIBASIM_REAL_19I2_STATE model=$model_name bmi_endpoint_s=$endpoint " *
            "represented_solve_time_s=$(endpoint-21600.0) " *
            "shadow_root_m3_day=$shadow_root shadow_external_m3_day=$shadow_external " *
            "applied_root_m3_day=$applied_root applied_external_m3_day=$applied_external " *
            "applied_root_link_m3_day=$applied_root_link applied_external_link_m3_day=$applied_external_link",
        )
    end

    root_volume = cumulative_user_inflow(model, 3)
    external_volume = cumulative_user_inflow(model, 4)
    total_volume = root_volume + external_volume
    final_level = basin_level(model)
    storage_gain = AREA * (final_level - 1.0)

    require(isapprox(root_volume, expected_root_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name root physical volume differs from daily applied-state reference")
    require(isapprox(external_volume, expected_external_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name external physical volume differs from daily applied-state reference")
    require(isapprox(total_volume, 16.019184640970934; atol=VOLUME_TOL, rtol=0.0), "$model_name total physical volume differs from daily applied-state reference")
    require(isapprox(final_level, 1.000015980815359; atol=LEVEL_TOL, rtol=0.0), "$model_name final Basin level differs from daily applied-state reference")
    require(isapprox(storage_gain, 15.980815359029066; atol=VOLUME_TOL, rtol=0.0), "$model_name storage gain differs from daily applied-state reference")
    require(isapprox(total_volume + storage_gain, 32.0; atol=VOLUME_TOL, rtol=0.0), "$model_name physical ledger does not close")

    println(
        "RIBASIM_REAL_19I2_OBS model=$model_name root_supplied_m3=$root_volume " *
        "external_supplied_m3=$external_volume total_supplied_m3=$total_volume " *
        "final_level=$final_level storage_gain_m3=$storage_gain",
    )
    println("RIBASIM_REAL_19I2_CASE=PASS model=$model_name")
    BMI.finalize(model)
    return (total=total_volume, level=final_level)
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_bmi_shadow_applied_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_bmi_clock_root_first";
        root_priority=2,
        external_priority=3,
        expected_shadow=ROOT_FIRST_SHADOW,
        expected_applied_root=32.0,
        expected_applied_external=0.0,
        expected_root_volume=16.019184640970934,
        expected_external_volume=0.0,
    )
    external_first = check_case(
        root,
        "swap5_bmi_clock_external_first";
        root_priority=3,
        external_priority=2,
        expected_shadow=EXTERNAL_FIRST_SHADOW,
        expected_applied_root=12.0,
        expected_applied_external=20.0,
        expected_root_volume=6.0071942403641,
        expected_external_volume=10.011990400606834,
    )

    require(isapprox(root_first.total, external_first.total; atol=VOLUME_TOL, rtol=0.0), "priority reversal changed total physical supply")
    require(isapprox(root_first.level, external_first.level; atol=LEVEL_TOL, rtol=0.0), "priority reversal changed final Basin level")
    println("RIBASIM_REAL_19I2_SHADOW_APPLIED_SEPARATION=PASS")
end

main()
