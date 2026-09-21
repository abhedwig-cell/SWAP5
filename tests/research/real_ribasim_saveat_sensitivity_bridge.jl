using Ribasim
using DataFrames

const DAY = 86400.0
const SUPPLY = 32.0 / DAY
const ROOT_DEMAND = 40.0 / DAY
const EXTERNAL_DEMAND = 20.0 / DAY
const AREA = 1_000_000.0

const VOLUME_TOL = 0.05
const ALLOCATION_TOL = 0.05
const LEVEL_TOL = 5.0e-8

const SWEEP = [
    (
        saveat = 3600.0,
        total = 29.091488480329396,
        final_level = 1.0000029085115192,
        storage_gain = 2.9085115191840316,
        root_first = (
            final_root_alloc = 40.0,
            final_ext_alloc = 20.0,
            root_volume = 19.838956206388705,
            ext_volume = 9.25253227394069,
        ),
        external_first = (
            final_root_alloc = 40.0,
            final_ext_alloc = 20.0,
            root_volume = 19.088672877273925,
            ext_volume = 10.002815603055462,
        ),
    ),
    (
        saveat = 21600.0,
        total = 24.512820430148427,
        final_level = 1.0000074871795697,
        storage_gain = 7.487179569665159,
        root_first = (
            final_root_alloc = 40.0,
            final_ext_alloc = 19.96254646941776,
            root_volume = 19.015246367867107,
            ext_volume = 5.49757406228132,
        ),
        external_first = (
            final_root_alloc = 39.96254646941776,
            final_ext_alloc = 20.0,
            root_volume = 14.50504727621437,
            ext_volume = 10.007773153934059,
        ),
    ),
    (
        saveat = 43200.0,
        total = 20.020373860361662,
        final_level = 1.0000119796261395,
        storage_gain = 11.979626139524413,
        root_first = (
            final_root_alloc = 40.0,
            final_ext_alloc = 7.990403839705181,
            root_volume = 18.01978009224423,
            ext_volume = 2.0005937681174317,
        ),
        external_first = (
            final_root_alloc = 27.99040383970518,
            final_ext_alloc = 20.0,
            root_volume = 10.009884054231453,
            ext_volume = 10.010489806130208,
        ),
    ),
    (
        saveat = 86400.0,
        total = 16.019184641047147,
        final_level = 1.000015980815359,
        storage_gain = 15.980815359029066,
        root_first = (
            final_root_alloc = 32.0,
            final_ext_alloc = 0.0,
            root_volume = 16.019184641047147,
            ext_volume = 0.0,
        ),
        external_first = (
            final_root_alloc = 12.0,
            final_ext_alloc = 20.0,
            root_volume = 6.00719424039268,
            ext_volume = 10.011990400654467,
        ),
    ),
]


function require(condition::Bool, message::AbstractString)
    condition || error(message)
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


function allocation_history(model, node_id::Int, priority::Int)
    df = DataFrame(Ribasim.allocation_data(model))
    rows = df[(df.node_id .== node_id) .& (df.demand_priority .== priority), :]
    require(!isempty(rows), "allocation history absent for node $node_id priority $priority")
    sort!(rows, :time)
    return rows
end


function history_times_seconds(model, rows)
    return Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
end


function require_allocation_clock(model, rows, saveat::Float64, label::AbstractString)
    observed = history_times_seconds(model, rows)
    expected = collect(0.0:saveat:(DAY - saveat))
    require(
        length(observed) == length(expected),
        "$label allocation record count differs from saveat-capped clock",
    )
    require(
        all(isapprox.(observed, expected; atol = 1.0e-6, rtol = 0.0)),
        "$label allocation record times differ from saveat-capped clock",
    )
end


function print_history(model, rows, model_name::AbstractString, label::AbstractString)
    times = history_times_seconds(model, rows)
    for (t, allocated, supplied) in zip(times, rows.allocated, rows.supplied)
        println(
            "RIBASIM_REAL_19G_ALLOC model=$model_name label=$label " *
            "t_s=$t allocated_m3_day=$(allocated * DAY) supplied_m3_day=$(supplied * DAY)",
        )
    end
end


function check_case(
        root::AbstractString,
        spec,
        order::Symbol,
    )
    expected = order === :root_first ? spec.root_first : spec.external_first
    model_name = "swap5_saveat_$(Int(spec.saveat))_" * String(order)
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = Ribasim.run(path)

    root_priority = order === :root_first ? 2 : 3
    external_priority = order === :root_first ? 3 : 2

    root_hist = allocation_history(model, 3, root_priority)
    ext_hist = allocation_history(model, 4, external_priority)

    require_allocation_clock(model, root_hist, spec.saveat, "$model_name root")
    require_allocation_clock(model, ext_hist, spec.saveat, "$model_name external")
    print_history(model, root_hist, model_name, "root")
    print_history(model, ext_hist, model_name, "external")

    require(
        isapprox(first(root_hist.allocated) * DAY, order === :root_first ? 32.0 : 12.0; atol = ALLOCATION_TOL, rtol = 0.0),
        "$model_name initial root allocation differs from frozen priority split",
    )
    require(
        isapprox(first(ext_hist.allocated) * DAY, order === :root_first ? 0.0 : 20.0; atol = ALLOCATION_TOL, rtol = 0.0),
        "$model_name initial external allocation differs from frozen priority split",
    )

    root_alloc_series = Float64.(root_hist.allocated) .* DAY
    ext_alloc_series = Float64.(ext_hist.allocated) .* DAY
    total_alloc_series = root_alloc_series .+ ext_alloc_series

    require(
        all(diff(total_alloc_series) .>= -ALLOCATION_TOL),
        "$model_name total allocation decreases despite retained-storage feedback",
    )

    final_root_alloc = last(root_alloc_series)
    final_ext_alloc = last(ext_alloc_series)

    require(
        isapprox(final_root_alloc, expected.final_root_alloc; atol = ALLOCATION_TOL, rtol = 0.0),
        "$model_name final root allocation differs from preregistered reference",
    )
    require(
        isapprox(final_ext_alloc, expected.final_ext_alloc; atol = ALLOCATION_TOL, rtol = 0.0),
        "$model_name final external allocation differs from preregistered reference",
    )

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)

    expected_samples = Int(round(DAY / spec.saveat))
    require(length(root_flow.flow_rate) == expected_samples, "$model_name root physical sample count differs from saveat")
    require(length(ext_flow.flow_rate) == expected_samples, "$model_name external physical sample count differs from saveat")
    require(length(source_flow.flow_rate) == expected_samples, "$model_name source sample count differs from saveat")
    require(
        all(isapprox.(source_flow.flow_rate, SUPPLY; atol = 1.0e-10, rtol = 1.0e-7)),
        "$model_name fixed source flow changed",
    )

    root_volume = integrate_link_flow(model, root_flow)
    ext_volume = integrate_link_flow(model, ext_flow)
    total_volume = root_volume + ext_volume

    require(
        isapprox(root_volume, expected.root_volume; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name root physical volume differs from preregistered hybrid reference",
    )
    require(
        isapprox(ext_volume, expected.ext_volume; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name external physical volume differs from preregistered hybrid reference",
    )
    require(
        isapprox(total_volume, spec.total; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name total physical volume differs from preregistered hybrid reference",
    )

    basin_state = DataFrame(Ribasim.basin_state_data(model))
    basin2 = basin_state[basin_state.node_id .== 2, :]
    require(nrow(basin2) == 1, "$model_name final Basin state absent or ambiguous")
    final_level = Float64(only(basin2.level))
    storage_gain = AREA * (final_level - 1.0)

    require(
        isapprox(final_level, spec.final_level; atol = LEVEL_TOL, rtol = 0.0),
        "$model_name final Basin level differs from preregistered hybrid reference",
    )
    require(
        isapprox(storage_gain, spec.storage_gain; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name storage gain differs from preregistered hybrid reference",
    )
    require(
        isapprox(total_volume + storage_gain, 32.0; atol = VOLUME_TOL, rtol = 0.0),
        "$model_name one-day physical ledger does not close to 32 m3",
    )

    println(
        "RIBASIM_REAL_19G_OBS model=$model_name saveat_s=$(spec.saveat) " *
        "final_root_alloc_m3_day=$final_root_alloc final_external_alloc_m3_day=$final_ext_alloc " *
        "root_supplied_m3=$root_volume external_supplied_m3=$ext_volume total_supplied_m3=$total_volume " *
        "final_level=$final_level storage_gain_m3=$storage_gain allocation_records=$(length(root_hist.time))",
    )
    println("RIBASIM_REAL_19G_CASE=PASS model=$model_name")

    return (
        total_volume = total_volume,
        final_level = final_level,
        storage_gain = storage_gain,
        final_root_alloc = final_root_alloc,
        final_ext_alloc = final_ext_alloc,
    )
end


function main()
    length(ARGS) == 1 || error("usage: real_ribasim_saveat_sensitivity_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_totals = Float64[]
    external_totals = Float64[]
    root_storage = Float64[]

    for spec in SWEEP
        root_first = check_case(root, spec, :root_first)
        external_first = check_case(root, spec, :external_first)

        require(
            isapprox(root_first.total_volume, external_first.total_volume; atol = VOLUME_TOL, rtol = 0.0),
            "saveat $(spec.saveat): priority reversal changed total physical supply",
        )
        require(
            isapprox(root_first.final_level, external_first.final_level; atol = LEVEL_TOL, rtol = 0.0),
            "saveat $(spec.saveat): priority reversal changed final Basin level",
        )

        push!(root_totals, root_first.total_volume)
        push!(external_totals, external_first.total_volume)
        push!(root_storage, root_first.storage_gain)
    end

    require(
        all(diff(root_totals) .< -VOLUME_TOL),
        "root-first total physical supply is not strictly lower as saveat increases",
    )
    require(
        all(diff(external_totals) .< -VOLUME_TOL),
        "external-first total physical supply is not strictly lower as saveat increases",
    )
    require(
        all(diff(root_storage) .> VOLUME_TOL),
        "retained Basin storage is not strictly higher as saveat increases",
    )

    println("RIBASIM_REAL_19G_SAVEAT_ALLOCATION_CLOCK_SENSITIVITY=PASS")
end

main()
