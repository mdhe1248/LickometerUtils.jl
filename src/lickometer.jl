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

function meanvector(vectors::AbstractVector, xi::AbstractRange)
    truncated_vectors = [v[xi] for v in vectors]
    return mean(hcat(truncated_vectors...), dims = 2)[:]
end
meanvector(vectors::AbstractVector) = meanvector(vectors, 1:minimum(length.(vectors)))

function stdvector(vectors::AbstractVector, xi::AbstractRange)
    truncated_vectors = [v[xi] for v in vectors]
    return std(hcat(truncated_vectors))
end
stdvector(vectors::AbstractVector) = stdvector(vectors, 1:minimum(length.(vectors)))

function semvector(vectors::AbstractVector, xi::AbstractRange)
    n = length(vectors)
    truncated_vectors = [v[xi] for v in vectors]
    return std(hcat(truncated_vectors...))./sqrt(n)
end
semvector(vectors) = semvector(vectors, 1:minimum(length.(vectors)))

function analyze_multiple_sensors(sensors, xi)
    mean_vals = Vector{Float64}()
    std_vals = Vector{Float64}()
    sem_vals = Vector{Float64}()

    cumulative_vec = cumsum.(detect.(sensors))
    mean_vals = meanvector(cumulative_vec, xi)
    std_vals = stdvector(cumulative_vec, xi)
    sem_vals = semvector(cumulative_vec, xi)
    return(mean_vals, std_vals, sem_vals)
end
function analyze_multiple_sensors(sensors)
    mean_vals = Vector{Float64}()
    std_vals = Vector{Float64}()
    sem_vals = Vector{Float64}()

    cumulative_vec = cumsum.(detect.(sensors))
    mean_vals = meanvector(cumulative_vec)
    std_vals = stdvector(cumulative_vec)
    sem_vals = semvector(cumulative_vec)
    return(mean_vals, std_vals, sem_vals)
end

""" Get the recording time axis with a given time scale.
`i0` is the start index.
`i1` is the last index.
`scale` can be milisecond ("ms" or "millisecond"), second ("s", "sec", or "second"), minute ("m", "min", or "minute"), or hour ("h", "hr", or "hour").
If there are only 3 input arguments, then `i0` is set to be 0.
"""
function get_recording_time(i0, i1, sampling_interval, scale)
    if scale ∈  ["min", "m", "minute"]
        t1 = i1*sampling_interval/1000/60 #millisecond to minute
        t0 = i0*sampling_interval/1000/60 #millisecond to minute
    elseif scale ∈  ["sec", "s", "second"]
        t1 = i1*sampling_interval/1000
        t0 = i0*sampling_interval/1000
    elseif scale ∈  ["millisecond", "ms"]
        t1 = i1*sampling_interval
        t0 = i0*sampling_interval
    elseif scale ∈  ["hour", "hr", "h"]
        t1 = i1*sampling_interval/1000/60/60
        t0 = i0*sampling_interval/1000/60/60
    end
    xi = range(t0, t1, i1-i0) 
    return xi
end
get_recording_time(i1, sampling_interval, scale) = get_recording_time(0, i1, sampling_interval, scale)

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
