module LickometerUtils

export AbstractSensor, Touch, FedBox 
export get_recording_time, get_sampling_interval, detect_touch, remove_long_touch, detect_lick, detect_touchmoment, estimate_baseline, lickevent_filter, detect, meanvector, stdvector, semvector, analyze_multiple_sensors

include("lickometer.jl")
# Write your package code here.

end
