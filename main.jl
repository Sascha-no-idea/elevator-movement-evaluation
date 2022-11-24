using CSV
using DataFrames
using Statistics
using Plots

# Read in the data
mutable struct Jerk
    time
    data
    label::String
end

mutable struct Acceleration
    time
    data
    label::String
end

mutable struct Velocity
    time
    data
    label::String
end

mutable struct Position
    time
    data
    label::String
end

mutable struct Pressure
    time
    data
    label::String
end
#using Polynomials

mutable struct Accelerometer
    jerk::Jerk
    acceleration::Acceleration
    velocity::Velocity
    position::Position
end

mutable struct PressureSensor
    pressure::Pressure
    position::Position
    velocity::Velocity
end

mutable struct DataSeries
    accelerometer::Accelerometer
    pressure_sensor::PressureSensor
end

function read_data_series(series::Int)
    # read accelerometer data
    acc_df = CSV.read("./measurements/series_$(series)/Acceleration.csv", DataFrame)
    acc_jerk = Jerk(acc_df[:, 1], acc_df[:, 2], "jerk_measurement")

    accelerometer = Accelerometer(
        acc_jerk,
        Acceleration(nothing, nothing, ""),
        Velocity(nothing, nothing, ""),
        Position(nothing, nothing, "")
    )
    # read pressure sensor data
    prs_and_vel_df = CSV.read("./measurements/series_$series/Pressure and velocity.csv", DataFrame)
    prs_prs = Pressure(prs_and_vel_df[:, 1], prs_and_vel_df[:, 2], "pressure_measurement")
    prs_altitude = Position(prs_and_vel_df[:, 1], prs_and_vel_df[:, 3], "altitude_measurement")
    prs_vel = Velocity(prs_and_vel_df[:, 4], prs_and_vel_df[:, 5], "velocity_measurement")

    pressure_sensor = PressureSensor(prs_prs, prs_altitude, prs_vel)
    # combine data
    return DataSeries(accelerometer, pressure_sensor)
end

 # main functions
save_figure(title::String) = savefig("./figures/$(title).svg")

plot_series(series::Jerk) = plot!(series.time, series.data, title="Jerk", label=series.label, ylabel="Jerk [m/s^3]")
plot_series(series::Acceleration) = plot!(series.time, series.data, title="Acceleration", label=series.label, ylabel="Acceleration [m/s^2]")
plot_series(series::Velocity) = plot!(series.time, series.data, title="Velocity", label=series.label, ylabel="Velocity [m/s]")
plot_series(series::Position) = plot!(series.time, series.data, title="Position", label=series.label, ylabel="Position [m]")

function plot_stuff(series...)
    plot()
    # check if the series are of the same type
    if all(x -> typeof(x) == typeof(series[1]), series)
        for s in series
            display(plot_series(s))
        end
        plot!(
            lw=1,
            grid=true,
            xlabel="t in [s]",
            size=(600, trunc(Int, sqrt(2)*600))
        )
    else
        error("Series are not of the same type")
    end
    return nothing
end

#=
function plot_layout(x::Array, y::Array, unit::String, title::String, label=nothing)
    if label === nothing
        plot(x, y, label="")
    else
        plot(x, y, label=label)
    end
    plot!(title=title, lw=1, grid=true, xlabel="t in [s]", size=(600, trunc(Int, sqrt(2)*600)))
    if unit == "jerk"
        plot!(ylabel="j in [ms^(-3)]")
    elseif unit == "acc"
        plot!(ylabel="a in [ms^(-2)]")
    elseif unit == "vel"
        plot!(ylabel="v in [ms^(-1)]")
    elseif unit == "dist"
        plot!(ylabel="s in [m]")
    elseif unit == "none"
        nothing
    else
        @warn "Undefined unit!"
    end
end
=#

function zoom_and_grid(start::Number, stop::Number, divisons=10, digits=1)
    plot!(xlims=(start, stop))
    plot!(xtick=round.(range(start, stop, step=(stop-start)/divisons), digits=digits))
end

find_closest(array::Array, value::Number) = findmin(abs.(array.-value))[2]

#=
# write a function to cut a data Series
cut_series = (series, start, stop) -> series[find_closest(series.time, start):find_closest(series.time, stop)]

# write a function to cut the entire data set
# by iterating trough all nested fields
cut_data_series = (data_series, start, stop) -> begin
    data_series.accelerometer.jerk = cut_series(data_series.accelerometer.jerk, start, stop)
    data_series.accelerometer.acceleration = cut_series(data_series.accelerometer.acceleration, start, stop)
    data_series.accelerometer.velocity = cut_series(data_series.accelerometer.velocity, start, stop)
    data_series.accelerometer.position = cut_series(data_series.accelerometer.position, start, stop)
    data_series.pressure_sensor.pressure = cut_series(data_series.pressure_sensor.pressure, start, stop)
    data_series.pressure_sensor.position = cut_series(data_series.pressure_sensor.position, start, stop)
    data_series.pressure_sensor.velocity = cut_series(data_series.pressure_sensor.velocity, start, stop)
    return data_series
end
=#

function cut(data::DataSeries, start::Number, stop::Number)
    # find the closest values in the time fields of the nested structs
    # and remove the data in between the start and stop values from the structs
    # start and stop are in seconds
    # TODO fix fieldnames (needs struct not instance)
    for i_1 in fieldnames(DataSeries) # Accelerometer, PressureSensor
        for i_2 in fieldnames(typeof(getfield(data, i_1))) # Jerk, Acceleration, Velocity, Position or Pressure, Position, Velocity
            # get the field
            field = getfield(getfield(data, i_1), i_2)
            # check if field is empty
            empty(value) = isnothing(getfield(field, value))
            if any(empty.(fieldnames(typeof(field))))
                continue
            end
            # find the closest values in the time field
            start_idx, stop_idx = find_closest.(Ref(field.time), [start, stop])
            # remove the data in between the start and stop values
            field.time = field.time[1:end .∉ [start_idx:stop_idx-1]]
            field.data = field.data[1:end .∉ [start_idx:stop_idx-1]]
            # shift the time field
            field.time .-= stop
        end
    end
    return nothing
    #=
    start_idx, stop_idx = find_closest.(Ref(data.acc_and_vel[:, 1]), [start, stop])
    acc_and_vel = data.acc_and_vel[1:end .∉ [start_idx:stop_idx-1], :]
    start_idx, stop_idx = find_closest.(Ref(data.prs_and_vel[:, 1]), [start, stop])
    prs_and_vel = data.prs_and_vel[1:end .∉ [start_idx:stop_idx-1], :]
    acc_and_vel[:, 1] .-= acc_and_vel[1, 1]
    prs_and_vel[:, 1] .-= prs_and_vel[1, 1]
    prs_and_vel[:, 4] .-= prs_and_vel[1, 4]
    result = Measurement(
        acc_and_vel,
        prs_and_vel
        )
    return result
    =#
end

function sensor_noise(data::DataSeries, start::Number, stop::Number)
    start_idx, stop_idx = find_closest.(Ref(data.accelerometer.jerk.time), [start, stop])
    jerk = data.accelerometer.jerk.data[start_idx:stop_idx]
    return mean(jerk)
end

function apply_offset(data::DataSeries, offset::Number)
    data.accelerometer.jerk.data .-= offset
    return nothing
end
 #=
function noise_profile(data::Measurement, start::Number, stop::Number)
    start_idx, stop_idx = find_closest.(Ref(data.acc_and_vel[:, 1]), [start, stop])
    offset = Statistics.mean(data.acc_and_vel[start_idx:stop_idx, 2])
    println("Average offset: $offset [m/s^3]")
    return offset
end

function calibrate(data::Measurement, offset::Number)
    accelerations = copy(data.acc_and_vel)
    accelerations[:, 2] .-= offset
    result = Measurement(
        accelerations,
        data.prs_and_vel
        )
    return result
end
=#

# write a function to calculate the acceleration from the jerk using integration
# first calculate the timesteps
integrate_series(data::Array, Δt::Array) = cumsum(data .* Δt)

function integrate(data::DataSeries)
    Δt = data.accelerometer.jerk.time[2:end] .- data.accelerometer.jerk.time[1:end-1]
    # calculate the acceleration, velocity and position
    data.accelerometer.acceleration.data = integrate_series(data.accelerometer.jerk.data[1:end-1], Δt)
    data.accelerometer.acceleration.time = cumsum(Δt)
    data.accelerometer.velocity.data = integrate_series(data.accelerometer.acceleration.data, Δt)
    data.accelerometer.velocity.time = cumsum(Δt)
    data.accelerometer.position.data = integrate_series(data.accelerometer.velocity.data, Δt)
    data.accelerometer.position.time = cumsum(Δt)
    return nothing
end

#=
function acc_by_jerk(data::Measurement)
    acc_and_vel = copy(data.acc_and_vel)
    times = acc_and_vel[2:end, 1] - acc_and_vel[1:end-1, 1]
    accelerations = cumsum(acc_and_vel[1:end-1, 2] .* times)
    acc_and_vel[1:end-1, 3:4] = hcat(cumsum(times), accelerations)
    result = Measurement(
        acc_and_vel,
        data.prs_and_vel
        )
    return result
end

function vel_by_acc(data::Measurement)
    acc_and_vel = copy(data.acc_and_vel)
    times = acc_and_vel[2:end, 1] - acc_and_vel[1:end-1, 1]
    velocities = cumsum(acc_and_vel[1:end-1, 4] .* times)
    acc_and_vel[1:end-1, 5] = velocities
    result = Measurement(
        acc_and_vel,
        data.prs_and_vel
        )
    return result
end

function dist_by_vel(data::Measurement)
    acc_and_vel = copy(data.acc_and_vel)
    times = acc_and_vel[2:end, 1] - acc_and_vel[1:end-1, 1]
    distances = cumsum(acc_and_vel[1:end-1, 5] .* times)
    acc_and_vel[1:end-1, 6] = distances
    result = Measurement(
        acc_and_vel,
        data.prs_and_vel
        )
    return result
end
=#

function run_all()
    data = read_data_series(1)
    zoom_and_grid(0, 10)
    cut(data, 0, 2)
    offset = sensor_noise(data, 0, 2)
    apply_offset(data, offset)
end

run_all()


# TODO:
# - it seems like some data retains, as the integrated data series look different compared to a previous run_all
# - inetgrate function doesn't work well in run_all (doesn't get executed properly/at all)
# - somehow pressure data from pressure sensor gets lost at some point (maybe when cutting the data series)