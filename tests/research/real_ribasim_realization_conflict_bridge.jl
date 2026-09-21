using Ribasim
using DataFrames

const DAY = 86400.0
const SUPPLY = 60.0 / DAY
const ROOT_DEMAND = 40.0 / DAY
const EXTERNAL_DEMAND = 20.0 / DAY
const AREA = 1_000_000.0
const MIN_LEVEL = 0.99
const LEVEL_THRESHOLD = 0.02

const EXPECTED_FINAL_LEVEL = 1.0000299326012367
const EXPECTED_TOTAL_SUPPLIED = 30.067398763262645
const EXPECTED_ROOT_SUPPLIED = 20.044932508841763
const EXPECTED_EXTERNAL_SUPPLIED = 10.022466254420882
const EXPECTED_STORAGE_GAIN = 29.932601236737355
const VOLUME_TOL = 0.05
const LEVEL_TOL = VOLUME_TOL / AREA


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
    # Pinned Ribasim flow_data reports interval-mean flows. The timestamp is
    # the START of the represented saveat interval (core/src/write.jl).
    times = Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
    rates = Float64.(rows.flow_rate)

    require(!isempty(times), "physical linkflow contains no intervals")
    require(
        length(times) == length(rates),
        "physical linkflow time/rate lengths differ",
    )
    require(
        all(diff(times) .> 0.0),
        "physical linkflow interval starts are not strictly increasing",
    )
    require(
        abs(first(times)) <= 1.0e-9,
        "physical linkflow does not start at the model horizon",
    )
    require(
        last(times) < DAY,
        "physical linkflow interval start is not before the model end",
    )

    interval_edges = vcat(times, DAY)
    durations = diff(interval_edges)
    require(
        all(durations .> 0.0),
        "physical linkflow contains a non-positive represented interval",
    )
    require(
        isapprox(sum(durations), DAY; atol = 1.0e-6, rtol = 0.0),
        "physical linkflow intervals do not cover the full one-day horizon",
    )

    return sum(rates .* durations)
end


function check_source_flow(rows)
    require(
        all(isapprox.(rows.flow_rate, SUPPLY; atol = 1.0e-10, rtol = 1.0e-7)),
        "fixed 60 m3/day source flow changed",
    )
end


function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = Ribasim.run(path)

    root_alloc, root_demand = user_allocated(model, 3, root_priority)
    ext_alloc, ext_demand = user_allocated(model, 4, external_priority)

    require(isapprox(root_demand, ROOT_DEMAND; atol = 1.0e-12), "root demand changed")
    require(isapprox(ext_demand, EXTERNAL_DEMAND; atol = 1.0e-12), "external demand changed")
    require(
        isapprox(root_alloc, ROOT_DEMAND; atol = 1.0e-10, rtol = 1.0e-7),
        "$model_name root demand was not fully allocated",
    )
    require(
        isapprox(ext_alloc, EXTERNAL_DEMAND; atol = 1.0e-10, rtol = 1.0e-7),
        "$model_name external demand was not fully allocated",
    )
    require(
        isapprox(root_alloc + ext_alloc, SUPPLY; atol = 1.0e-10, rtol = 1.0e-7),
        "$model_name total allocation differs from 60 m3/day",
    )

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)
    check_source_flow(source_flow)

    require(
        length(root_flow.flow_rate) == length(ext_flow.flow_rate),
        "$model_name recipient physical-flow series lengths differ",
    )

    normalized_root = Float64.(root_flow.flow_rate) ./ ROOT_DEMAND
    normalized_ext = Float64.(ext_flow.flow_rate) ./ EXTERNAL_DEMAND
    require(
        all(isapprox.(normalized_root, normalized_ext; atol = 2.0e-8, rtol = 2.0e-7)),
        "$model_name physical recipients do not share the same reduction factor",
    )
    require(
        all(isapprox.(Float64.(root_flow.flow_rate), 2.0 .* Float64.(ext_flow.flow_rate); atol = 2.0e-10, rtol = 2.0e-7)),
        "$model_name physical root/external supply ratio differs from 2:1",
    )
    require(
        minimum(normalized_root) >= 0.499 &&
        maximum(normalized_root) <= 0.504,
        "$model_name physical reduction factor left the preregistered narrow range",
    )

    root_volume = integrate_link_flow(model, root_flow)
    ext_volume = integrate_link_flow(model, ext_flow)
    total_volume = root_volume + ext_volume

    require(
        isapprox(root_volume, EXPECTED_ROOT_SUPPLIED; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name integrated root supply differs from independent continuous reference",
    )
    require(
        isapprox(ext_volume, EXPECTED_EXTERNAL_SUPPLIED; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name integrated external supply differs from independent continuous reference",
    )
    require(
        isapprox(total_volume, EXPECTED_TOTAL_SUPPLIED; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name total physical supply differs from independent continuous reference",
    )

    basin = DataFrame(Ribasim.basin_data(model))
    basin2 = basin[basin.node_id .== 2, :]
    require(!isempty(basin2), "$model_name Basin 2 interval output is absent")
    sort!(basin2, :time)

    # basin_data intentionally excludes the final state because its rows carry
    # interval-flow context. Use the pinned endpoint-state surface for the
    # actual model-end level.
    basin_state = DataFrame(Ribasim.basin_state_data(model))
    basin_state2 = basin_state[basin_state.node_id .== 2, :]
    require(
        nrow(basin_state2) == 1,
        "$model_name final Basin state is absent or ambiguous",
    )
    final_level = Float64(only(basin_state2.level))
    storage_gain = AREA * (final_level - 1.0)

    println(
        "RIBASIM_REAL_19C_OBS model=$model_name " *
        "root_supplied_m3=$root_volume external_supplied_m3=$ext_volume " *
        "total_supplied_m3=$total_volume final_level=$final_level " *
        "storage_gain_m3=$storage_gain",
    )

    require(
        isapprox(final_level, EXPECTED_FINAL_LEVEL; atol = LEVEL_TOL, rtol = 0.0),
        "$model_name final Basin level differs from preregistered continuous reference",
    )
    require(
        isapprox(storage_gain, EXPECTED_STORAGE_GAIN; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name Basin storage gain differs from preregistered continuous reference",
    )
    require(
        isapprox(total_volume + storage_gain, 60.0; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name physical one-day ledger does not close to 60 m3 fixed inflow",
    )

    final_phi = reduction_factor_reference(final_level - MIN_LEVEL)
    require(
        isapprox(final_phi, 0.502244938388153; atol = 5.0e-6, rtol = 0.0),
        "$model_name final physical min-level reduction factor differs from preregistration",
    )
    require(
        total_volume < 0.51 * 60.0,
        "$model_name did not exhibit the preregistered allocation-versus-realization shortfall",
    )

    println(
        "RIBASIM_REAL_19C_CASE=PASS model=$model_name " *
        "allocated_root_m3_day=$(root_alloc * DAY) allocated_external_m3_day=$(ext_alloc * DAY) " *
        "supplied_root_m3=$root_volume supplied_external_m3=$ext_volume " *
        "final_level=$final_level",
    )

    return (
        root_alloc = root_alloc,
        ext_alloc = ext_alloc,
        root_volume = root_volume,
        ext_volume = ext_volume,
        total_volume = total_volume,
        basin = basin2,
        root_flow = root_flow,
        ext_flow = ext_flow,
    )
end


function main()
    length(ARGS) == 1 || error("usage: real_ribasim_realization_conflict_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_realization_root_first";
        root_priority = 2,
        external_priority = 3,
    )
    external_first = check_case(
        root,
        "swap5_realization_external_first";
        root_priority = 3,
        external_priority = 2,
    )

    require(
        isapprox(root_first.root_alloc, external_first.root_alloc; atol = 1.0e-10),
        "priority reversal changed fully realizable root allocation",
    )
    require(
        isapprox(root_first.ext_alloc, external_first.ext_alloc; atol = 1.0e-10),
        "priority reversal changed fully realizable external allocation",
    )
    require(
        isapprox(root_first.root_volume, external_first.root_volume; atol = VOLUME_TOL, rtol = 0.0),
        "priority reversal changed physical root supply in the common-factor case",
    )
    require(
        isapprox(root_first.ext_volume, external_first.ext_volume; atol = VOLUME_TOL, rtol = 0.0),
        "priority reversal changed physical external supply in the common-factor case",
    )
    require(
        length(root_first.basin.level) == length(external_first.basin.level),
        "priority cases have different Basin trajectory lengths",
    )
    require(
        all(isapprox.(root_first.basin.level, external_first.basin.level; atol = LEVEL_TOL, rtol = 1.0e-8)),
        "priority reversal changed the real Ribasim Basin trajectory",
    )

    println("RIBASIM_REAL_19C_PROPORTIONAL_REALIZATION=PASS")
end

main()
