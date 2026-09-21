using Ribasim
using DataFrames

const DAY = 86400.0
const SUPPLY = 32.0 / DAY
const ROOT_DEMAND = 40.0 / DAY
const EXTERNAL_DEMAND = 20.0 / DAY
const AREA = 1_000_000.0
const MIN_LEVEL = 0.99
const LEVEL_THRESHOLD = 0.02

const EXPECTED_FINAL_LEVEL = 1.000015980815359
const EXPECTED_FINAL_FACTOR = 0.5011985601316069
const EXPECTED_TOTAL_SUPPLIED = 16.019184640970934
const EXPECTED_STORAGE_GAIN = 15.980815359029066
const VOLUME_TOL = 0.05
const LEVEL_TOL = 5.0e-8
const FACTOR_TOL = 5.0e-6


function require(condition::Bool, message::AbstractString)
    condition || error(message)
end


function reduction_factor_reference(x::Float64)::Float64
    if x < 0.0
        return 0.0
    elseif x < LEVEL_THRESHOLD
        z = x / LEVEL_THRESHOLD
        return (-2.0 * z + 3.0) * z^2
    else
        return 1.0
    end
end


function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present in pinned Ribasim model")
    return idx
end


function user_allocated(model, node_id::Int, priority::Int)
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx], user_demand.demand[id.idx, idx]
end


function physical_link_flow(model, from_id::Int, to_id::Int)
    df = DataFrame(Ribasim.flow_data(model))
    rows = df[(df.from_node_id .== from_id) .& (df.to_node_id .== to_id), :]
    require(!isempty(rows), "physical link $from_id -> $to_id is absent")
    sort!(rows, :time)
    return rows
end


function integrate_link_flow(model, rows)::Float64
    times = Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
    rates = Float64.(rows.flow_rate)

    require(!isempty(times), "physical linkflow contains no intervals")
    require(length(times) == length(rates), "physical linkflow time/rate lengths differ")
    require(abs(first(times)) <= 1.0e-9, "physical linkflow does not start at model start")
    if length(times) > 1
        require(all(diff(times) .> 0.0), "physical linkflow interval starts are not strictly increasing")
    end
    require(last(times) < DAY, "physical linkflow interval start is not before model end")

    durations = diff(vcat(times, DAY))
    require(all(durations .> 0.0), "physical linkflow has a non-positive represented interval")
    require(isapprox(sum(durations), DAY; atol = 1.0e-6, rtol = 0.0), "physical linkflow does not cover one day")
    return sum(rates .* durations)
end


function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
        expected_root_alloc::Float64,
        expected_external_alloc::Float64,
        expected_root_supplied::Float64,
        expected_external_supplied::Float64,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = Ribasim.run(path)

    root_alloc, root_demand = user_allocated(model, 3, root_priority)
    ext_alloc, ext_demand = user_allocated(model, 4, external_priority)

    require(isapprox(root_demand, ROOT_DEMAND; atol = 1.0e-12), "root demand changed")
    require(isapprox(ext_demand, EXTERNAL_DEMAND; atol = 1.0e-12), "external demand changed")
    require(isapprox(root_alloc * DAY, expected_root_alloc; atol = 1.0e-6, rtol = 1.0e-7), "$model_name root allocation changed inside clock-aligned window")
    require(isapprox(ext_alloc * DAY, expected_external_alloc; atol = 1.0e-6, rtol = 1.0e-7), "$model_name external allocation changed inside clock-aligned window")
    require(isapprox((root_alloc + ext_alloc) * DAY, 32.0; atol = 1.0e-6, rtol = 1.0e-7), "$model_name total allocation differs from 32 m3/day")

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)

    require(all(isapprox.(source_flow.flow_rate, SUPPLY; atol = 1.0e-10, rtol = 1.0e-7)), "fixed source flow changed")

    root_volume = integrate_link_flow(model, root_flow)
    ext_volume = integrate_link_flow(model, ext_flow)
    total_volume = root_volume + ext_volume

    require(isapprox(root_volume, expected_root_supplied; atol = VOLUME_TOL, rtol = 0.0), "$model_name root supplied volume differs from frozen reference")
    require(isapprox(ext_volume, expected_external_supplied; atol = VOLUME_TOL, rtol = 0.0), "$model_name external supplied volume differs from frozen reference")
    require(isapprox(total_volume, EXPECTED_TOTAL_SUPPLIED; atol = VOLUME_TOL, rtol = 0.0), "$model_name total supplied volume differs from frozen reference")

    if expected_external_alloc == 0.0
        require(all(abs.(Float64.(ext_flow.flow_rate)) .<= 1.0e-12), "$model_name supplied an unallocated external claim")
    else
        normalized_root = Float64.(root_flow.flow_rate) ./ root_alloc
        normalized_ext = Float64.(ext_flow.flow_rate) ./ ext_alloc
        require(all(isapprox.(normalized_root, normalized_ext; atol = 2.0e-8, rtol = 2.0e-7)), "$model_name active allocated links do not share common physical factor")
    end

    basin_state = DataFrame(Ribasim.basin_state_data(model))
    basin_state2 = basin_state[basin_state.node_id .== 2, :]
    require(nrow(basin_state2) == 1, "$model_name final Basin state absent or ambiguous")
    final_level = Float64(only(basin_state2.level))
    storage_gain = AREA * (final_level - 1.0)
    final_factor = reduction_factor_reference(final_level - MIN_LEVEL)

    require(isapprox(final_level, EXPECTED_FINAL_LEVEL; atol = LEVEL_TOL, rtol = 0.0), "$model_name final level differs from frozen reference")
    require(isapprox(storage_gain, EXPECTED_STORAGE_GAIN; atol = VOLUME_TOL, rtol = 0.0), "$model_name storage gain differs from frozen reference")
    require(isapprox(final_factor, EXPECTED_FINAL_FACTOR; atol = FACTOR_TOL, rtol = 0.0), "$model_name final factor differs from frozen reference")
    require(isapprox(total_volume + storage_gain, 32.0; atol = VOLUME_TOL, rtol = 0.0), "$model_name physical ledger does not close")
    require(isapprox(32.0 - total_volume, storage_gain; atol = VOLUME_TOL, rtol = 0.0), "$model_name allocated-but-unsupplied water did not remain in Basin storage")

    println(
        "RIBASIM_REAL_19E2_OBS model=$model_name " *
        "allocated_root_m3_day=$(root_alloc * DAY) allocated_external_m3_day=$(ext_alloc * DAY) " *
        "root_supplied_m3=$root_volume external_supplied_m3=$ext_volume " *
        "total_supplied_m3=$total_volume final_level=$final_level storage_gain_m3=$storage_gain " *
        "final_factor=$final_factor samples=$(length(root_flow.flow_rate))",
    )
    println("RIBASIM_REAL_19E2_CASE=PASS model=$model_name")

    return (root_volume=root_volume, ext_volume=ext_volume, total_volume=total_volume)
end


function main()
    length(ARGS) == 1 || error("usage: real_ribasim_clock_aligned_conflict_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_clock_aligned_root_first";
        root_priority=2,
        external_priority=3,
        expected_root_alloc=32.0,
        expected_external_alloc=0.0,
        expected_root_supplied=16.019184640970934,
        expected_external_supplied=0.0,
    )
    external_first = check_case(
        root,
        "swap5_clock_aligned_external_first";
        root_priority=3,
        external_priority=2,
        expected_root_alloc=12.0,
        expected_external_alloc=20.0,
        expected_root_supplied=6.0071942403641,
        expected_external_supplied=10.011990400606834,
    )

    require(isapprox(root_first.total_volume, external_first.total_volume; atol=VOLUME_TOL, rtol=0.0), "priority reversal changed total physical supply")
    println("RIBASIM_REAL_19E2_CLOCK_ALIGNED_PRIORITY_THEN_REALIZATION=PASS")
end

main()
