using DataFrames, Statistics
using AxisArrays

abstract type AbstractSensor end

struct Sensor <: AbstractSensor
    capacitive_data::AbstractVector
    fedbox_data::Union{AbstractVector, Bool}
    sampling_interval::Number #millisecond
    thresh_cap::Number
    thresh_interval::Number
    filter_windowsize::Number
    baseline::AbstractVector
    corrected_capacitive_data::AbstractVector
    touch::AbstractVector
    lick::AbstractVector
    eating::AbstractVector

    function Sensor(capacitive_data, fedbox_data, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
        capacitive_data = AxisArray(capacitive_data, time = range(zero(eltype(sampling_interval)), step = sampling_interval, length = length(capacitive_data)))
        processed = preprocess_rawdata(capacitive_data)
        baseline = estimate_baseline(processed, filter_windowsize)
        corrected_capacitive_data= AxisArray(processed.-baseline, AxisArrays.axes(capacitive_data)...)
        touch = AxisArray(detect_touch(corrected_capacitive_data, thresh_cap), AxisArrays.axes(capacitive_data)...)
        lick = detect_lick(corrected_capacitive_data, thresh_cap, thresh_interval)
        lick = AxisArray(lickevent_filter(lick, 20, 3), AxisArrays.axes(capacitive_data)...) # Lick definition: the same or greater than three short touches within 15 time points (15*25 ms)
        eating = AxisArray(detect_eating(fedbox_data), AxisArrays.axes(capacitive_data)...)
        new(capacitive_data, fedbox_data, sampling_interval, thresh_cap, thresh_interval, filter_windowsize, baseline, corrected_capacitive_data, touch, lick, eating)
    end
end

struct Result <: AbstractSensor
    virus::Union{AbstractString, Bool}
    condition::Union{AbstractString, Bool}
    lbl::Symbol
    meanval::AbstractVector
    stdval::AbstractVector
    semval::AbstractVector
end

""" To calculate mean, std, and sem of a vector of Sensor type.
if `xi` is not provided, the shorted length will be used"""
function Result(virus::String, condition::String, field::Symbol, sensors::Vector{Sensor}, xi::Union{AbstractRange, ClosedInterval})
    meanval = meanvector(sensors, field, xi)
    stdval = stdvector(sensors, field, xi)
    semval = semvector(sensors, field, xi)
    Result(virus, condition, field, meanval, stdval, semval)
end

function Result(virus::String, condition::String, field::Symbol, sensors::Vector{Sensor})
    meanval = meanvector(sensors, field)
    stdval = stdvector(sensors, field)
    semval = semvector(sensors, field)
    Result(virus, condition, field, meanval, stdval, semval)
end

function preprocess_rawdata(rawdata::AbstractVector)
    processed = copy(rawdata)
    processed[processed .== -2] .= 5000
    return processed
end

function detect_eating(sensor::AbstractVector)
    bncdiff = vcat(diff(sensor), [0])
    return(bncdiff .== 1)
end

function estimate_baseline(rawdata::AbstractVector, window_size::Int)
    if window_size <= 1
        return(rawdata)
    else
        result = similar(rawdata, Float64)
        for i in 1:length(rawdata)
            result[i] = quantile(rawdata[max(1, i-window_size):i], 0.2)
        end
        return result
    end
end

function meanvector(vectors::Vector{Sensor}, field::Symbol, xi::Union{AbstractRange, ClosedInterval})
    # truncate and cumsum
    truncated_vectors = [cumsum(getfield(v, field)[xi]) for v in vectors]
    if length(unique(length.(truncated_vectors))) != 1
        error("The lengths of $field vectors are not equal. Try without `xi` or with smaller `xi`.")
    end
    return dropdims(mean(cat(truncated_vectors..., dims = 2), dims = 2), dims = 2)
end
meanvector(vectors::Vector{Sensor}, field::Symbol) = meanvector(vectors, field, 1:minimum(length.(getfield.(vectors, field))))

function stdvector(vectors::AbstractVector, field::Symbol, xi::Union{AbstractRange, ClosedInterval})
    truncated_vectors = [cumsum(getfield(v, field)[xi]) for v in vectors]
    if length(unique(length.(truncated_vectors))) != 1
        error("The lengths of $field vectors are not equal. Try without `xi` or with smaller `xi`.")
    end
    return AxisArray(vec(std(hcat(truncated_vectors...), dims = 2)), truncated_vectors[1].axes...)
end
stdvector(vectors::AbstractVector, field::Symbol) = stdvector(vectors, field, 1:minimum(length.(getfield.(vectors, field))))

function semvector(vectors::AbstractVector, field::Symbol,  xi::Union{AbstractRange, ClosedInterval})
    n = length(vectors)
    stdval = stdvector(vectors, field, xi)
    return AxisArray(stdval./sqrt(n), stdval.axes...)
end
semvector(vectors::AbstractVector, field::Symbol) = semvector(vectors, field, 1:minimum(length.(getfield.(vectors, field))))

""" Get wait time from the data frame"""
function get_sampling_interval(df::DataFrame)
    s = names(df)[2]
    idx = findfirst(==(':'), s)
    return parse(Int, s[idx+1:end])
end

""" Using a threshold, detect touch from raw recording. non-touch: 0, touch: 1."""
function detect_touch(y::AbstractVector, thresh_cap)
    return (y .> thresh_cap)
end

"""Remove long touch. interval_thresh is touch duration. If touch lasts longer than the threshold, it becomes 0."""
function remove_long_touch(touch0::AbstractVector, thresh_interval)
    touch1 = copy(touch0)
    y = diff(vcat(touch1, 0))
    on = findall(y.== 1)
    off = findall(y.== -1)
    for i in eachindex(on)
        if off[i] - on[i] > thresh_interval
            touch1[on[i]:off[i]] .=0
        end
    end
    return touch1 
end

""" Detect licks. 
Given that a single lick lasts only a couple of milliseconds and the average lick interval is roughly 100 ms, a long-period touch is regarded as simple touch, but not lick. See also `detect_touch` and `remove_long_touch`"""
function detect_lick(y::AbstractVector, thresh_cap, thresh_interval)
    touch0 = detect_touch(y, thresh_cap)
    lick = remove_long_touch(touch0, thresh_interval)
    return lick
end

function detect_touchmoment(touch0::AbstractVector)
    touchon = vcat(diff(touch0), 0)
    return touchon.== 1
end

""" Vector is filtered. Lick is defined by the number of short touches `nthresh`  within a short time window `winzs`"""
function lickevent_filter(lick::AbstractVector, winsz, nthresh)
    lick_filtered = falses(length(lick))
    l0 = detect_touchmoment(lick)
    a = [sum(l0[max(i, 1):min(i+winsz, length(l0))]) for i in eachindex(l0)]
    idx1 = findall(a .>= nthresh)
    [lick_filtered[i:i+winsz] .= l0[i:i+winsz] for i in idx1]
    lick_filtered
end
