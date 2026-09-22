using Ribasim
using DataFrames
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA = 1_000_000.0
const ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
const ALLOCATION_TOL = 0.05
const VOLUME_TOL = 0.05
const LEVEL_TOL = 5.0e-8

const ROOT_FIRST_ALLOC = [
    (32.0, 0.0),
    (40.0, 7.995200961071983),
    (40.0, 15.979613076541273),
    (40.0, 19.962546470305938),
]
const EXTERNAL_FIRST_ALLOC = [
    (12.0, 20.0),
    (27.995200960183805, 20.0),
    (35.979613075653106, 20.0),
    (39.96254646941776, 20.0),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present")
    return idx
end

function user_allocated(model, node_id::Int, priority::Int)
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx]
end

function user_cumulative_inflow(model, node_id::Int)
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    values = BMI.get_value_ptr(model, "user_demand.cumulative_inflow")
    return values[id.idx]
end

function basin_level(model, node_id::Int)
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:Basin, node_id, p_independent)
    values = BMI.get_value_ptr(model, "basin.level")
    return values[id.idx]
end

function check_case(root::AbstractString, model_name::AbstractString; root_priority::Int, external_priority::Int, expected_alloc, expected_root_volume::Float64, expected_external_volume::Float64)
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = BMI.initialize(Ribasim.Model, path)
    observed_alloc = Tuple{Float64,Float64}[]

    for (i, endpoint) in enumerate(ENDPOINTS)
        current_before = BMI.get_current_time(model)
        tstops_before = copy(model.integrator.p.p_independent.allocation.time.tstops)
        BMI.update_until(model, endpoint)
        current_after = BMI.get_current_time(model)
        tstops_after = copy(model.integrator.p.p_independent.allocation.time.tstops)
        root_alloc = user_allocated(model, 3, root_priority) * DAY
        ext_alloc = user_allocated(model, 4, external_priority) * DAY
        push!(observed_alloc, (root_alloc, ext_alloc))
        exp_root, exp_ext = expected_alloc[i]

        println(
            "RIBASIM_REAL_19I_ALLOC model=$model_name bmi_call=$i " *
            "before_s=$current_before endpoint_s=$endpoint after_s=$current_after " *
            "represented_solve_time_s=$(endpoint-21600.0) " *
            "root_m3_day=$root_alloc external_m3_day=$ext_alloc " *
            "expected_root_m3_day=$exp_root expected_external_m3_day=$exp_ext " *
            "tstops_before=$(tstops_before) tstops_after=$(tstops_after)",
        )

        require(isapprox(current_after, endpoint; atol=1.0e-9, rtol=0.0), "$model_name BMI did not stop at requested endpoint")
        require(isapprox(root_alloc, exp_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name root allocation after BMI call $i differs from frozen reference")
        require(isapprox(ext_alloc, exp_ext; atol=ALLOCATION_TOL, rtol=0.0), "$model_name external allocation after BMI call $i differs from frozen reference")
    end

    root_volume = user_cumulative_inflow(model, 3)
    ext_volume = user_cumulative_inflow(model, 4)
    total_volume = root_volume + ext_volume
    final_level = basin_level(model, 2)
    storage_gain = AREA * (final_level - 1.0)

    require(isapprox(root_volume, expected_root_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name root cumulative inflow differs from frozen 6-hour reference")
    require(isapprox(ext_volume, expected_external_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name external cumulative inflow differs from frozen 6-hour reference")
    require(isapprox(total_volume, 24.512820430148427; atol=VOLUME_TOL, rtol=0.0), "$model_name total physical supply differs from frozen 6-hour reference")
    require(isapprox(final_level, 1.0000074871795697; atol=LEVEL_TOL, rtol=0.0), "$model_name final Basin level differs from frozen 6-hour reference")
    require(isapprox(storage_gain, 7.487179569665159; atol=VOLUME_TOL, rtol=0.0), "$model_name storage gain differs from frozen 6-hour reference")
    require(isapprox(total_volume + storage_gain, 32.0; atol=VOLUME_TOL, rtol=0.0), "$model_name physical ledger does not close")

    println("RIBASIM_REAL_19I_OBS model=$model_name root_supplied_m3=$root_volume external_supplied_m3=$ext_volume total_supplied_m3=$total_volume final_level=$final_level storage_gain_m3=$storage_gain")
    println("RIBASIM_REAL_19I_CASE=PASS model=$model_name")
    BMI.finalize(model)
    return (total_volume=total_volume, final_level=final_level)
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_bmi_management_clock_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(root, "swap5_bmi_clock_root_first"; root_priority=2, external_priority=3, expected_alloc=ROOT_FIRST_ALLOC, expected_root_volume=19.015246367867107, expected_external_volume=5.49757406228132)
    external_first = check_case(root, "swap5_bmi_clock_external_first"; root_priority=3, external_priority=2, expected_alloc=EXTERNAL_FIRST_ALLOC, expected_root_volume=14.50504727621437, expected_external_volume=10.007773153934059)

    require(isapprox(root_first.total_volume, external_first.total_volume; atol=VOLUME_TOL, rtol=0.0), "priority reversal changed total BMI-clock physical supply")
    require(isapprox(root_first.final_level, external_first.final_level; atol=LEVEL_TOL, rtol=0.0), "priority reversal changed BMI-clock final level")
    println("RIBASIM_REAL_19I_BMI_MANAGEMENT_CLOCK=PASS")
end

main()
