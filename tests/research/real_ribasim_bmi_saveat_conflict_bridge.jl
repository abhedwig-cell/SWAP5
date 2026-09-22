using Ribasim
using DataFrames
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA = 1_000_000.0
const ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
const VOLUME_TOL = 0.05
const ALLOCATION_TOL = 0.05
const LEVEL_TOL = 5.0e-8
const SIX_HOUR_TOTAL = 24.512820430148427

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present")
    return idx
end

function user_allocated(model, node_id::Int, priority::Int)::Float64
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx]
end

function cumulative_user_inflow(model, node_id::Int)::Float64
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    return BMI.get_value_ptr(model, "user_demand.cumulative_inflow")[id.idx]
end

function basin_level(model)::Float64
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:Basin, 2, p_independent)
    return BMI.get_value_ptr(model, "basin.level")[id.idx]
end

function allocation_rows(model, node_id::Int, priority::Int)
    df = DataFrame(Ribasim.allocation_data(model))
    rows = df[(df.node_id .== node_id) .& (df.demand_priority .== priority), :]
    require(!isempty(rows), "allocation history absent for node $node_id priority $priority")
    sort!(rows, :time)
    return rows
end

function check_hourly_clock(model, rows, label::AbstractString)
    times = Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
    expected = collect(0.0:3600.0:82800.0)
    require(length(times) == 24, "$label allocation record count is not 24")
    require(all(isapprox.(times, expected; atol=1.0e-6, rtol=0.0)), "$label allocation records are not hourly")
end

function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
        expected_initial_root::Float64,
        expected_initial_external::Float64,
        expected_root_volume::Float64,
        expected_external_volume::Float64,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")
    model = BMI.initialize(Ribasim.Model, path)

    for endpoint in ENDPOINTS
        BMI.update_until(model, endpoint)
        require(isapprox(BMI.get_current_time(model), endpoint; atol=1.0e-9, rtol=0.0), "$model_name missed BMI endpoint $endpoint")
        println(
            "RIBASIM_REAL_19J_BMI model=$model_name endpoint_s=$endpoint " *
            "applied_root_m3_day=$(user_allocated(model, 3, root_priority) * DAY) " *
            "applied_external_m3_day=$(user_allocated(model, 4, external_priority) * DAY)",
        )
    end

    root_rows = allocation_rows(model, 3, root_priority)
    ext_rows = allocation_rows(model, 4, external_priority)
    check_hourly_clock(model, root_rows, "$model_name root")
    check_hourly_clock(model, ext_rows, "$model_name external")

    require(isapprox(first(root_rows.allocated) * DAY, expected_initial_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name initial root allocation differs")
    require(isapprox(first(ext_rows.allocated) * DAY, expected_initial_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name initial external allocation differs")
    require(isapprox(last(root_rows.allocated) * DAY, 40.0; atol=ALLOCATION_TOL, rtol=0.0), "$model_name final root allocation is not full demand")
    require(isapprox(last(ext_rows.allocated) * DAY, 20.0; atol=ALLOCATION_TOL, rtol=0.0), "$model_name final external allocation is not full demand")

    root_volume = cumulative_user_inflow(model, 3)
    external_volume = cumulative_user_inflow(model, 4)
    total_volume = root_volume + external_volume
    final_level = basin_level(model)
    storage_gain = AREA * (final_level - 1.0)

    require(isapprox(root_volume, expected_root_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name root volume differs from frozen 1-hour reference")
    require(isapprox(external_volume, expected_external_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name external volume differs from frozen 1-hour reference")
    require(isapprox(total_volume, 29.091488480329396; atol=VOLUME_TOL, rtol=0.0), "$model_name total volume differs from frozen 1-hour reference")
    require(isapprox(final_level, 1.0000029085115192; atol=LEVEL_TOL, rtol=0.0), "$model_name final level differs from frozen 1-hour reference")
    require(isapprox(storage_gain, 2.9085115191840316; atol=VOLUME_TOL, rtol=0.0), "$model_name storage gain differs from frozen 1-hour reference")
    require(total_volume - SIX_HOUR_TOTAL > 1.0, "$model_name is not materially separated from the frozen 6-hour reference")
    require(isapprox(total_volume + storage_gain, 32.0; atol=VOLUME_TOL, rtol=0.0), "$model_name physical ledger does not close")

    println(
        "RIBASIM_REAL_19J_OBS model=$model_name root_supplied_m3=$root_volume " *
        "external_supplied_m3=$external_volume total_supplied_m3=$total_volume " *
        "final_level=$final_level storage_gain_m3=$storage_gain allocation_records=$(length(root_rows.time))",
    )
    println("RIBASIM_REAL_19J_CASE=PASS model=$model_name")
    BMI.finalize(model)
    return (total=total_volume, level=final_level)
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_bmi_saveat_conflict_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_saveat_3600_root_first";
        root_priority=2,
        external_priority=3,
        expected_initial_root=32.0,
        expected_initial_external=0.0,
        expected_root_volume=19.838956206388705,
        expected_external_volume=9.25253227394069,
    )
    external_first = check_case(
        root,
        "swap5_saveat_3600_external_first";
        root_priority=3,
        external_priority=2,
        expected_initial_root=12.0,
        expected_initial_external=20.0,
        expected_root_volume=19.088672877273925,
        expected_external_volume=10.002815603055462,
    )

    require(isapprox(root_first.total, external_first.total; atol=VOLUME_TOL, rtol=0.0), "priority reversal changed total physical supply")
    require(isapprox(root_first.level, external_first.level; atol=LEVEL_TOL, rtol=0.0), "priority reversal changed final Basin level")
    println("RIBASIM_REAL_19J_BMI_SAVEAT_CLOCK_CONFLICT=PASS")
end

main()
