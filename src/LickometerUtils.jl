module LickometerUtils

export Sensor, Result
export get_sampling_interval, detect_touch, remove_long_touch, detect_lick, detect_touchmoment, estimate_baseline, lickevent_filter, detect, meanvector, stdvector, semvector

include("lickometer.jl")
# Write your package code here.

end
