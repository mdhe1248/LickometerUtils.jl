using DataFrames, Statistics

struct TouchSensor
    rawdata::AbstractVector
    sampling_interval::Number #millisecond
    thresh_cap::Number
    thresh_interval::Number
    filter_windowsize::Number
    baseline::AbstractVector
    corrected_rawdata::AbstractVector
    touch::AbstractVector
    lick::AbstractVector
    function TouchSensor(rawdata, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
        rawdata1 = copy(rawdata)
        rawdata1[rawdata1.== -2] .= 5000
        baseline = estimate_baseline(rawdata1, filter_windowsize)
        corrected_rawdata = rawdata1.-baseline
#        touch = corrected_rawdata .> thresh_cap
        touch = detect_touch(corrected_rawdata, thresh_cap)
        lick = detect_lick(corrected_rawdata, thresh_cap, thresh_interval)
        new(rawdata, sampling_interval, thresh_cap, thresh_interval, filter_windowsize, baseline, corrected_rawdata, touch, lick)
    end
end

function estimate_baseline(rawdata::AbstractVector, window_size::Int)
    if window_size <= 1
        return(rawdata)
    else
        return [quantile(rawdata[max(1, i-window_size):i], 0.2) for i in 1:length(rawdata)]
    end
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
detect_touch(x::TouchSensor) = detect_touch(x.rawdata, x.thresh_cap)

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

function detect_lick(x::TouchSensor)
    touch0 = detect_touch(x)
    lick = remove_long_touch(touch0, x.thresh_interval)
    return lick
end

function detect_touchmoment(touch0::AbstractVector)
    touchon = vcat(diff(touch0), 0)
    return touchon.== 1
end


