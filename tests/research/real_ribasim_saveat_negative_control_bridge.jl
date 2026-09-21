using Ribasim
using DataFrames

const DAY = 86400.0
const SUPPLY = 60.0 / DAY
const AREA = 1_000_000.0

const EXPECTED_ROOT_ALLOC = 40.0
const EXPECTED_EXT_ALLOC = 20.0
const EXPECTED_ROOT_VOLUME = 20.04493250879216
const EXPECTED_EXT_VOLUME = 10.02246625439608
const EXPECTED_TOTAL_VOLUME = 30.067398763188237
const EXPECTED_FINAL_LEVEL = 1.0000299326012365
const EXPECTED_STORAGE_GAIN = 29.93260123651531

const VOLUME_TOL = 0.05
const ALLOCATION_TOL = 0.05
const LEVEL_TOL = 5.0e-8

const SAVEATS = [3600.0, 21600.0, 43200.0, 86400.0]


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
    require(abs(first(times)) <= 1.0e-9, "physical linkflow does not start at model start")
    if length(times) > 1
        require(all(diff(times) .> 0.0), "physical linkflow interval starts are not strictly increasing")
    end
    durations = diff(vcat(times, DAY))
    require(all(durations .> 0.0), "physical linkflow has a non-positive interval")
    require(isapprox(sum(durations), DAY; atol=1.0e-6, rtol=0.0), "physical linkflow does not cover one day")
    return sum(Float64.(rows.flow_rate) .* durations)
end


function allocation_history(model, node_id::Int, priority::Int)
    df = DataFrame(Ribasim.allocation_data(model))
    rows = df[(df.node_id .== node_id) .& (df.demand_priority .== priority), :]
    require(!isempty(rows), "allocation history absent for node $node_id priority $priority")
    sort!(rows, :time)
    return rows
end


function require_clock_and_full_allocation(model, rows, saveat::Float64, expected::Float64, label::AbstractString)
    times = Float64.(Ribasim.seconds_since.(rows.time, model.config.starttime))
    expected_times = collect(0.0:saveat:(DAY - saveat))
    require(length(times) == length(expected_times), "$label allocation record count differs from saveat grid")
    require(all(isapprox.(times, expected_times; atol=1.0e-6, rtol=0.0)), "$label allocation record times differ from saveat grid")
    require(
        all(isapprox.(Float64.(rows.allocated) .* DAY, expected; atol=ALLOCATION_TOL, rtol=0.0)),
        "$label allocation changed despite non-scarce demand-capped case",
    )
end


function check_case(root::AbstractString, saveat::Float64)
    model_name = "swap5_saveat_negative_$(Int(saveat))"
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = Ribasim.run(path)

    root_hist = allocation_history(model, 3, 2)
    ext_hist = allocation_history(model, 4, 3)
    require_clock_and_full_allocation(model, root_hist, saveat, EXPECTED_ROOT_ALLOC, "$model_name root")
    require_clock_and_full_allocation(model, ext_hist, saveat, EXPECTED_EXT_ALLOC, "$model_name external")

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)

    expected_samples = Int(round(DAY / saveat))
    require(length(root_flow.flow_rate) == expected_samples, "$model_name root sample count differs from saveat")
    require(length(ext_flow.flow_rate) == expected_samples, "$model_name external sample count differs from saveat")
    require(length(source_flow.flow_rate) == expected_samples, "$model_name source sample count differs from saveat")
    require(all(isapprox.(source_flow.flow_rate, SUPPLY; atol=1.0e-10, rtol=1.0e-7)), "$model_name fixed source changed")

    root_volume = integrate_link_flow(model, root_flow)
    ext_volume = integrate_link_flow(model, ext_flow)
    total_volume = root_volume + ext_volume

    require(isapprox(root_volume, EXPECTED_ROOT_VOLUME; atol=VOLUME_TOL, rtol=0.0), "$model_name root volume differs from continuous reference")
    require(isapprox(ext_volume, EXPECTED_EXT_VOLUME; atol=VOLUME_TOL, rtol=0.0), "$model_name external volume differs from continuous reference")
    require(isapprox(total_volume, EXPECTED_TOTAL_VOLUME; atol=VOLUME_TOL, rtol=0.0), "$model_name total volume differs from continuous reference")

    basin_state = DataFrame(Ribasim.basin_state_data(model))
    basin2 = basin_state[basin_state.node_id .== 2, :]
    require(nrow(basin2) == 1, "$model_name final Basin state absent or ambiguous")
    final_level = Float64(only(basin2.level))
    storage_gain = AREA * (final_level - 1.0)

    require(isapprox(final_level, EXPECTED_FINAL_LEVEL; atol=LEVEL_TOL, rtol=0.0), "$model_name final level differs from continuous reference")
    require(isapprox(storage_gain, EXPECTED_STORAGE_GAIN; atol=VOLUME_TOL, rtol=0.0), "$model_name storage gain differs from continuous reference")
    require(isapprox(total_volume + storage_gain, 60.0; atol=VOLUME_TOL, rtol=0.0), "$model_name 60 m3 ledger does not close")

    println(
        "RIBASIM_REAL_19H_OBS model=$model_name saveat_s=$saveat " *
        "root_supplied_m3=$root_volume external_supplied_m3=$ext_volume " *
        "total_supplied_m3=$total_volume final_level=$final_level storage_gain_m3=$storage_gain " *
        "allocation_records=$(length(root_hist.time))",
    )
    println("RIBASIM_REAL_19H_CASE=PASS model=$model_name")

    return (root_volume=root_volume, ext_volume=ext_volume, total_volume=total_volume, final_level=final_level)
end


function main()
    length(ARGS) == 1 || error("usage: real_ribasim_saveat_negative_control_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    results = [check_case(root, saveat) for saveat in SAVEATS]

    ref = last(results)
    for (saveat, result) in zip(SAVEATS, results)
        require(isapprox(result.root_volume, ref.root_volume; atol=VOLUME_TOL, rtol=0.0), "saveat $saveat changed root physical volume")
        require(isapprox(result.ext_volume, ref.ext_volume; atol=VOLUME_TOL, rtol=0.0), "saveat $saveat changed external physical volume")
        require(isapprox(result.total_volume, ref.total_volume; atol=VOLUME_TOL, rtol=0.0), "saveat $saveat changed total physical volume")
        require(isapprox(result.final_level, ref.final_level; atol=LEVEL_TOL, rtol=0.0), "saveat $saveat changed final Basin level")
    end

    println("RIBASIM_REAL_19H_SAVEAT_NEGATIVE_CONTROL=PASS")
end

main()
