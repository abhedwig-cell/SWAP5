using Ribasim
using DataFrames

const DAY = 86400.0
const AREA = 1_000_000.0
const SUPPLY = 60.0 / DAY
const ROOT_DEMAND = 40.0 / DAY
const EXTERNAL_DEMAND = 20.0 / DAY
const ROOT_INITIAL = 20.0 / DAY
const EXTERNAL_INITIAL = 10.0 / DAY

const EXPECTED_TOTAL_M3 = 30.067398763262645
const EXPECTED_ROOT_M3 = 20.044932508841764
const EXPECTED_EXTERNAL_M3 = 10.022466254420882
const EXPECTED_STORAGE_GAIN_M3 = 29.932601236737355
const EXPECTED_FINAL_LEVEL_M = 1.0000299326012367
const VOLUME_ATOL_M3 = 0.05

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
    return user_demand.allocated[id.idx, idx], user_demand.demand[id.idx, idx]
end

function physical_link_flow(model, from_id::Int, to_id::Int)
    df = DataFrame(Ribasim.flow_data(model))
    rows = df[(df.from_node_id .== from_id) .& (df.to_node_id .== to_id), :]
    require(!isempty(rows), "physical link $from_id -> $to_id is absent")
    sort!(rows, :time)
    return rows
end

function integrate_physical_flow(model, rows, initial_rate::Float64)
    times = Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
    rates = Float64.(rows.flow_rate)

    require(issorted(times), "physical-flow times are not sorted")
    require(last(times) >= DAY - 1.0e-6, "physical-flow output does not reach horizon end")

    if first(times) > 1.0e-9
        times = vcat(0.0, times)
        rates = vcat(initial_rate, rates)
    else
        require(
            isapprox(first(rates), initial_rate; atol = 1.0e-10, rtol = 1.0e-7),
            "physical initial flow differs from pinned 0.5 reduction",
        )
    end

    # Restrict any numerically repeated/future endpoint to the one-day horizon.
    keep = times .<= DAY + 1.0e-6
    times = times[keep]
    rates = rates[keep]

    require(isapprox(last(times), DAY; atol = 1.0e-6), "last physical-flow time is not one day")

    volume = 0.0
    for i in 1:(length(times) - 1)
        dt = times[i + 1] - times[i]
        require(dt >= 0.0, "negative physical-flow time increment")
        volume += 0.5 * (rates[i] + rates[i + 1]) * dt
    end
    return volume, times, rates
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
        isapprox(root_alloc, ROOT_DEMAND; atol = 1.0e-10, rtol = 1.0e-8),
        "$model_name root demand was not fully allocated",
    )
    require(
        isapprox(ext_alloc, EXTERNAL_DEMAND; atol = 1.0e-10, rtol = 1.0e-8),
        "$model_name external demand was not fully allocated",
    )
    require(
        isapprox(root_alloc + ext_alloc, SUPPLY; atol = 1.0e-10, rtol = 1.0e-8),
        "$model_name total allocation differs from 60 m3/day",
    )

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)

    require(
        length(root_flow.flow_rate) == length(ext_flow.flow_rate),
        "$model_name recipient physical series lengths differ",
    )
    require(
        all(root_flow.time .== ext_flow.time),
        "$model_name recipient physical sample times differ",
    )
    require(
        all(isapprox.(root_flow.flow_rate, 2.0 .* ext_flow.flow_rate; atol = 1.0e-10, rtol = 1.0e-7)),
        "$model_name physical recipient split is not the preregistered 2:1 common-factor ratio",
    )

    root_volume, root_times, root_rates =
        integrate_physical_flow(model, root_flow, ROOT_INITIAL)
    ext_volume, ext_times, ext_rates =
        integrate_physical_flow(model, ext_flow, EXTERNAL_INITIAL)
    source_volume, _, source_rates =
        integrate_physical_flow(model, source_flow, SUPPLY)

    require(root_times == ext_times, "$model_name integrated recipient time grids differ")
    require(
        all(isapprox.(source_rates, SUPPLY; atol = 1.0e-10, rtol = 1.0e-8)),
        "$model_name fixed physical source flow changed",
    )
    require(isapprox(source_volume, 60.0; atol = 1.0e-6), "$model_name source volume differs from 60 m3")

    require(
        isapprox(root_volume, EXPECTED_ROOT_M3; atol = VOLUME_ATOL_M3),
        "$model_name integrated root supply differs from preregistered continuous reference",
    )
    require(
        isapprox(ext_volume, EXPECTED_EXTERNAL_M3; atol = VOLUME_ATOL_M3),
        "$model_name integrated external supply differs from preregistered continuous reference",
    )
    require(
        isapprox(root_volume + ext_volume, EXPECTED_TOTAL_M3; atol = VOLUME_ATOL_M3),
        "$model_name integrated total supply differs from preregistered continuous reference",
    )
    require(
        root_volume + ext_volume < 31.0,
        "$model_name physical supply is not materially lower than 60 m3 allocation",
    )

    basin = DataFrame(Ribasim.basin_data(model))
    basin2 = basin[basin.node_id .== 2, :]
    require(!isempty(basin2), "$model_name Basin 2 output is absent")
    final_level = Float64(last(basin2.level))
    storage_gain = AREA * (final_level - 1.0)

    require(
        isapprox(storage_gain, EXPECTED_STORAGE_GAIN_M3; atol = VOLUME_ATOL_M3),
        "$model_name Basin storage gain differs from preregistered reference",
    )
    require(
        isapprox(final_level, EXPECTED_FINAL_LEVEL_M; atol = VOLUME_ATOL_M3 / AREA),
        "$model_name final Basin level differs from preregistered reference",
    )
    require(
        isapprox(source_volume, root_volume + ext_volume + storage_gain; atol = VOLUME_ATOL_M3),
        "$model_name physical Basin ledger does not close",
    )

    require(
        first(root_rates) < last(root_rates) && first(ext_rates) < last(ext_rates),
        "$model_name physical reduction factor did not increase as Basin storage accumulated",
    )

    println(
        "RIBASIM_REAL_19C_CASE=PASS model=$model_name " *
        "allocated_root_m3_day=$(root_alloc * DAY) " *
        "allocated_external_m3_day=$(ext_alloc * DAY) " *
        "supplied_root_m3=$root_volume supplied_external_m3=$ext_volume " *
        "final_level_m=$final_level",
    )

    return (
        root_alloc = root_alloc,
        ext_alloc = ext_alloc,
        root_volume = root_volume,
        ext_volume = ext_volume,
        basin = basin2,
        root_flow = root_flow,
        ext_flow = ext_flow,
    )
end

function main()
    length(ARGS) == 1 ||
        error("usage: real_ribasim_allocation_realization_conflict_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_reduction_root_first";
        root_priority = 2,
        external_priority = 3,
    )
    external_first = check_case(
        root,
        "swap5_reduction_external_first";
        root_priority = 3,
        external_priority = 2,
    )

    require(
        isapprox(root_first.root_alloc, external_first.root_alloc; atol = 1.0e-12) &&
        isapprox(root_first.ext_alloc, external_first.ext_alloc; atol = 1.0e-12),
        "priority reversal changed full allocation in DUMMY-19C",
    )
    require(
        isapprox(root_first.root_volume, external_first.root_volume; atol = VOLUME_ATOL_M3) &&
        isapprox(root_first.ext_volume, external_first.ext_volume; atol = VOLUME_ATOL_M3),
        "priority reversal changed common-factor physical supplied split",
    )
    require(
        length(root_first.basin.level) == length(external_first.basin.level),
        "priority cases have different Basin trajectory lengths",
    )
    require(
        all(isapprox.(
            root_first.basin.level,
            external_first.basin.level;
            atol = 5.0e-8,
            rtol = 1.0e-8,
        )),
        "priority reversal changed real Ribasim Basin trajectory",
    )

    println("RIBASIM_REAL_19C_ALLOCATION_REALIZATION_CONFLICT=PASS")
end

main()
