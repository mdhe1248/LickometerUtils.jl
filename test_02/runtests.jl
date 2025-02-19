using LickometerUtils
using CSV, DataFrames
using PythonPlot, Statistics

function prepare_filenames(fndix)
    "AR".*lpad.(fnidx, 2, '0').*".CSV"
end
function prepare_mousename(msidx)
    "ms".*lpad.(msidx, 2, '0')
end

function get_results(rawdata, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
    results = Vector{TouchSensor}()
    t0s = Vector{BitVector}()
    l0s = Vector{BitVector}()
    for r in rawdata
        result = TouchSensor(r, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
        push!(results, result)
        push!(t0s, detect_touchmoment(result.touch))
        push!(l0s, detect_touchmoment(result.lick))
    end
    return(results, t0s, l0s)
end

function set_boundary(ax)
    ax.spines.top.set_visible(false)
    ax.spines.right.set_visible(false)
end

## Initialize variables
fnidx = [3,6,1,4,12,11,10] #arduino file name
msidx = [1,2,3,4,6,7,8] #Corresponding mouse ID
sampling_interval = 25  #Sampling time interval. Probably 25 or 50 (ms). Sampling rate.
thresh_cap = 100 # sensor value
thresh_interval = 2 #sampling_interval * thresh_interval is the duration (ms). Allow up to 50ms for a single lick.
filter_windowsize = 50 #Number of data points. For baseline correction

## Load data
mouseid = prepare_mousename(msidx) #mouse id
fns = prepare_filenames(fnidx)
dfs = CSV.read.(fns, DataFrame)

#### Single dataset
i = 1 #First dataset
df = dfs[i]
rawdata = df[:, 2] #data from single port

## Calculate licking events
result = TouchSensor(rawdata, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
t0 = detect_touchmoment(result.touch)
l0 = detect_touchmoment(result.lick)

#### Plot capacitance sensor
## scale time into second (x-axis)
scale = "min"
xi = get_recording_time(length(rawdata), sampling_interval, scale) #total recording time in minute

## Plot raw data
hfig = figure(figsize = (6,6), string(mouseid[i], " Lickometer"))
p1 = hfig.add_subplot(4,1,1)
p1.plot(xi, result.rawdata)
xlabel("time ($scale)")
ylabel("Capacitance value")

## Plot corrected_rawdata
p2 = hfig.add_subplot(4,1,2)
p2.plot(xi, result.corrected_rawdata)
xlabel("time ($scale)")
ylabel("Corrected data")
p2.sharex(p1)

## Plot touch
p3 = hfig.add_subplot(4,1,3)
p3.plot(xi, result.touch)
xlabel("time ($scale)")
ylabel("Touch")
p3.sharex(p1)

## Plot lick
p4 = hfig.add_subplot(4,1,4)
p4.plot(xi, result.lick)
xlabel("time ($scale)")
ylabel("Lick")
hfig.tight_layout()
p4.sharex(p1)

## Cumulative lick plot
figure( figsize = (4,3), string(mouseid[i], " cumulative lick"));
plot(xi, cumsum(t0))
plot(xi, cumsum(l0))
legend(["Touch", "Lick"])
xlabel("Time ($scale)")
ylabel("Cumulative touch")
tight_layout();


#### Multiple datasets
rawdatasets = map(x -> x[:,2], dfs)
results, t0s, l0s = get_results(rawdatasets, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)

## Set x-axis. Scale x-axis (25 ms) into second.
scale = "min"
n = min(map(x -> length(x.rawdata), results)...) #The number of the smallest data points
xi = get_recording_time(n, sampling_interval, scale) #total recording time in minute
truncated_t0s = cumsum.(map(x -> x[eachindex(xi)], t0s)) #Cumulative sum

## Initialize figure axes
f1 = figure(figsize=(4,6))
p_axes = []
for i in 1:length(results)+1
    push!(p_axes, f1.add_subplot(length(results)+1, 1, i))
    set_boundary(p_axes[i])
end

## Plot Individual lick events
for i in eachindex(results)
    p_axes[i].plot(xi, results[i].lick[eachindex(xi)])
    p_axes[i].set_ylabel(mouseid[i])
end
p_axes[1].set_title("Lick events", fontsize = 10)
p_axes[7].set_xlabel("Time (min)")

## truncate the recording time
meanval = vec(mean(hcat(truncated_t0s...), dims = 2)) #mean
stdval = vec(std(hcat(truncated_t0s...), dims = 2)) #stdev

## Plot cumulative (Mean ± STD)
p_axes[length(results)+1].plot(xi, meanval, label="Mean", color="blue")
fill_between(xi, meanval .- stdval, meanval .+ stdval, color="blue", alpha=0.3)
xlabel("Time ($scale)")
ylabel("Cumulative lick")

## Set plot positions
for i in 1:length(results)
    p_axes[i].set_position([0.15, 0.87-(0.075*(i-1)), 0.8, 0.05])
    i < length(results) ? p_axes[i].set_xticklabels(Int[]) : nothing #Last plot still has xticklabels
end
p_axes[length(results)+1].set_position([0.25, 0.1, 0.65, 0.2]) #Left, bottom, width, height
