using DataFrames

""" Change millisecond to minute"""
scaletime(x, waittime) = x*waittime/1000/60 #millisecond to minute

""" Get wait time from the data frame"""
function get_waittime(df::DataFrame)
    s = names(df)[2]
    idx = findfirst(==(':'), s)
    return parse(Int, s[idx+1:end])
end

""" Using a threshold, detect touch from raw recording. non-touch: 0, touch: 1."""
function detect_touch(y, thresh)
    y1 = copy(y)
    for (i, v) in enumerate(y)
        if v > thresh || v == -2
            y1[i] = 1
        else 
            y1[i] = 0
        end
    end
    return y1
end

"""Remove long touch. interval_thresh is touch duration. If touch lasts longer than the threshold, it becomes 0."""
function remove_long_touch(touch, interval_thresh)
    touch1 = copy(touch)
    y = vcat(diff(touch1), 0)
    on = findall(y.== 1)
    off = findall(y.== -1)
    for i in eachindex(on)
        if off[i] - on[i] > interval_thresh
            touch1[on[i]:off[i]] .=0
        end
    end
    return touch1 
end

""" Detect licks. 
Given that a single lick lasts only a couple of milliseconds and the average lick interval is roughly 100 ms, a long-period touch is regarded as simple touch, but not lick. See also `detect_touch` and `remove_long_touch`"""
function detect_lick(y, thresh, interval_thresh)
    touch = detect_touch(y, thresh)
    lick = remove_long_touch(touch, interval_thresh)
    return(lick)
end

