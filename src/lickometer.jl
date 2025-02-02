using DataFrames

struct TouchSensor
    rawdata::Vector
    waittime::Number #millisecond
    thresh_cap::Number
    thresh_interval::Number
end

""" Get the total recording time with a given time scale.
`scale` can be milisecond ("ms" or "millisecond"), second ("s", "sec", or "second"), minute ("m", "min", or "minute").
"""
function get_recording_time(x, waittime, scale)
    if scale ∈  ["min", "m", "minute"]
        t = x*waittime/1000/60 #millisecond to minute
    elseif scale ∈  ["sec", "s", "second"]
        t = x*waittime/1000
    elseif scale ∈  ["millisecond", "ms"]
        t = x*waittime
    end
    return t
end


""" Get wait time from the data frame"""
function get_waittime(df::DataFrame)
    s = names(df)[2]
    idx = findfirst(==(':'), s)
    return parse(Int, s[idx+1:end])
end

""" Using a threshold, detect touch from raw recording. non-touch: 0, touch: 1."""
function detect_touch(y::Vector, thresh_cap)
    y1 = zeros(Bool, length(y))
    for (i, v) in enumerate(y)
        if v > thresh_cap || v == -2
            y1[i] = true
        else 
            y1[i] = false
        end
    end
    return y1
end

detect_touch(x::TouchSensor) = detect_touch(x.rawdata, x.thresh_cap)

"""Remove long touch. interval_thresh is touch duration. If touch lasts longer than the threshold, it becomes 0."""
function remove_long_touch(touch::Vector{Bool}, thresh_interval)
    touch1 = copy(touch)
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
function detect_lick(y::Vector, thresh_cap, thresh_interval)
    touch = detect_touch(y, thresh_cap)
    lick = remove_long_touch(touch, thresh_interval)
    return lick
end

function detect_lick(x::TouchSensor)
    touch = detect_touch(x)
    lick = remove_long_touch(touch, x.thresh_interval)
    return lick
end

function detect_touchmoment(touch::Vector{Bool})
    touchon = vcat(diff(touch), 0)
    return touchon.== 1
end
