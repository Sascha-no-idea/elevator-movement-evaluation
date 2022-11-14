using CSV
using DataFrames
using Statistics
using Plots

#floattoint(number::Number) = trunc(Int, number)

struct Measurement
    acc_and_vel
    prs_and_vel
end

function read_data(series::Int)
    acc_df = CSV.read("./measurements/series_$(series)/Acceleration.csv", DataFrame)
    prs_and_vel_df = CSV.read("./measurements/series_$series/Pressure and velocity.csv", DataFrame)
    return Measurement(
        hcat(Array{Float64}(acc_df), fill(NaN, (size(acc_df, 1), 4))),
        Array{Float64}(prs_and_vel_df)
        )
end

save_figure(title::String) = savefig("./figures/$(title).svg")

function plot_layout(x::Array, y::Array, unit::String, title::String, label=nothing)
    if label == nothing
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

function zoom_and_grid(start::Number, stop::Number, divisons=10, digits=1)
    plot!(xlims=(start, stop))
    plot!(xtick=round.(range(start, stop, step=(stop-start)/divisons), digits=digits))
end

find_closest(array::Array, value::Number) = findmin(abs.(array.-value))[2]

function cut(data, start::Number, stop::Number)
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
end

function noise_profile(data::Measurement, start::Number, stop::Number)
    start_idx, stop_idx = find_closest.(Ref(data.acc_and_vel[:, 1]), [start, stop])
    offset = Statistics.mean(data.acc_and_vel[start_idx:stop_idx, 2])
    println("Average offset: $offset [m/s^3]")
    return offset
end

function calibrate(data::Measurement, offset::Number)
    accelerations = data.acc_and_vel
    accelerations[:, 2] .-= offset
    result = Measurement(
        accelerations,
        data.prs_and_vel
        )
    return result
end

function acc_by_jerk(data::Measurement)
    times = data.acc_and_vel[2:end, 1]-data.acc_and_vel[1:end-1, 1]
    accelerations = cumsum(data.acc_and_vel[1:end-1, 2] .* times)
    acc_and_vel = data.acc_and_vel
    acc_and_vel[1:end-1, 3:4] = hcat(cumsum(times), accelerations)
    result = Measurement(
        acc_and_vel,
        data.prs_and_vel
        )
    return result
end

function vel_by_acc(data::Measurement)
    acc_and_vel = data.acc_and_vel
    velocities = cumsum(acc_and_vel[1:end-1, 4] .* acc_and_vel[1:end-1, 3])
    acc_and_vel[1:end-1, 5] = velocities
    result = Measurement(
        acc_and_vel,
        data.prs_and_vel
        )
    return result
end

function run_all()
    data = read_data(0)
    plot_data(data)
    zoom(0, 10)
    data = cut(data, 0, 2)
    #data = calibrate(data, 0, 4)
    data = vel_by_acc(data)
end
