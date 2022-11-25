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

plot_series(series) = plot!(series.time, series.data)

label_string(series::Jerk) = "Jerk [m/s^3]"
label_string(series::Acceleration) = "Acc. [m/s^2]"
label_string(series::Velocity) = "Vel. [m/s]"
label_string(series::Position) = "Pos. [m]"
label_string(series::Pressure) = "Prs. [Pa]"

function plot_stuff(series...)
    fig = plot(xlabel="t in [s]")
    ylabels = []
    titles = []
    for s in series
        fig = plot_series(s)
        fig.series_list[end][:label] = s.label
        if !(label_string(s) in ylabels)
            push!(ylabels, label_string(s))
        end
        if !(typeof(s) in titles)
            push!(titles, typeof(s))
        end
    end
    yaxis!(join(ylabels, " / "))
    title!(join(string.(titles), " / "))
    display(fig)
    return nothing
end

function zoom_and_grid(start::Number, stop::Number, divisons=10, digits=1)
    plot!(xlims=(start, stop))
    plot!(xtick=round.(range(start, stop, step=(stop-start)/divisons), digits=digits))
end

find_closest(array::Array, value::Number) = findmin(abs.(array.-value))[2]

function cut(data::DataSeries, start::Number, stop::Number)
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

integrate_series(data::Array, Δt::Array) = cumsum(data .* Δt)

function integrate(data::DataSeries)
    Δt = data.accelerometer.jerk.time[2:end] .- data.accelerometer.jerk.time[1:end-1]
    # calculate the acceleration, velocity and position
    data.accelerometer.acceleration.data = integrate_series(data.accelerometer.jerk.data[1:end-1], Δt)
    data.accelerometer.acceleration.time = cumsum(Δt)
    data.accelerometer.acceleration.label = "calculated acceleration"
    data.accelerometer.velocity.data = integrate_series(data.accelerometer.acceleration.data, Δt)
    data.accelerometer.velocity.time = cumsum(Δt)
    data.accelerometer.velocity.label = "calculated velocity"
    data.accelerometer.position.data = integrate_series(data.accelerometer.velocity.data, Δt)
    data.accelerometer.position.time = cumsum(Δt)
    data.accelerometer.position.label = "calculated position"
    return nothing
end

# usage example (functions you may want to use)
#=
data = read_data_series(1)
plot_stuff(data.accelerometer.jerk)
save_figure("jerk_raw_data")
zoom_and_grid(0, 10)
cut(data, 0, 2)
plot_stuff(data.accelerometer.jerk)
offset = sensor_noise(data, 0, 15)
apply_offset(data, offset)
plot_stuff(data.accelerometer.jerk)
integrate(data)
plot_stuff(data.accelerometer.acceleration)
plot_stuff(data.accelerometer.velocity)
plot_stuff(data.accelerometer.position)
=#


# TODO:
# - rewrite sencor noise function to allow for multiple start and stop values

# debug
data = read_data_series(1)
cut(data, 0, 2)
offset = sensor_noise(data, 0, 15)
apply_offset(data, offset)
integrate(data)
plot_stuff(data.accelerometer.jerk)
plot_stuff(data.accelerometer.acceleration)
zoom_and_grid(0, 10)