using LickometerUtils
using CSV, DataFrames, AxisArrays
using PythonPlot, Statistics
using Unitful
using Unitful: s, ms, minute

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
params = (
    sampling_interval = 25ms,  #Sampling time interval. Probably 25 or 50 (ms). Sampling rate.
    thresh_cap = 100, # sensor value
    thresh_interval = 3, #sampling_interval * thresh_interval is the duration (ms). Allow up to 50ms for a single lick.
    filter_windowsize = 10) #Number of data points before and after a time point. For baseline correction
fnidx = [3,6,1,4,12,11,10] #arduino file name
msidx = [1,2,3,4,6,7,8] #Corresponding mouse ID

## Load data
cd("test_02")
mouseid = prepare_mousename(msidx) #mouse id
fns = prepare_filenames(fnidx)
dfs = CSV.read.(fns, DataFrame)

#### Single dataset
i = 1 #First dataset
df = dfs[i]
rawdata = df[:, 2] #data from single port
fedbox = df[:, 1] #data from single - fake data

## Calculate licking events
result = Sensor(rawdata, fedbox, params...)

xi  = uconvert.(minute, axisvalues(result.lick)...) |> ustrip #Convert to minute
timescale = "min"

#### Plot capacitance sensor
hfig = figure(figsize = (6,6), string(mouseid[i], " Lickometer"))
p = [hfig.add_subplot(4,1,i) for i in 1:4]
[p1.sharex(p[1]) for p1 in p]

p[1].plot(xi, result.capacitive_data)
xlabel("time ($timescale)")
ylabel("Capacitance value")

## Plot corrected_rawdata
p[2].plot(xi, result.corrected_capacitive_data)
xlabel("time ($timescale)")
ylabel("Corrected data")

## Plot touch
p[3].plot(xi, result.touch)
xlabel("time ($timescale)")
ylabel("Touch")

## Plot lick
p[4].plot(xi, result.lick)
xlabel("time ($timescale)")
ylabel("Lick")

hfig.tight_layout()

## Cumulative lick plot
figure(figsize = (4,3), string(mouseid[i], " cumulative lick"));
plot(xi, cumsum(detect_touchmoment(result.touch)))
plot(xi, cumsum(result.lick))
legend(["Touch", "Lick"])
xlabel("Time ($timescale)")
ylabel("Cumulative touch")
tight_layout();


#### Multiple datasets
## Example datasets
rawdatasets = map(x -> x[:,2], dfs)
feddatasets = map(x -> x[:,1], dfs) #just fake data

## Sensor typing
dataset1 = [Sensor(rawdatasets[1], feddatasets[1], params...),
            Sensor(rawdatasets[2], feddatasets[2], params...)]
dataset2 = [Sensor(rawdatasets[3], feddatasets[3], params...),
            Sensor(rawdatasets[4], feddatasets[4], params...)]

## Time can be either interval or range
xi = 0minute .. 100minute
fed_results = [Result("mCherry", "saline", :eating, dataset1,xi),
               Result("mCherry", "saline", :eating, dataset2,xi)]

lick_results = [Result("mCherry", "saline", :lick, dataset1, xi),
                Result("mCherry", "cno", :lick, dataset2, xi)]

#### plot
fig = figure()
p = [fig.add_subplot(2, 3, i) for i in 1:6] #The first row and then the second row is filled.
[p[i].sharey(p[1]) for i in 1:3]
[p[i].sharey(p[4]) for i in 4:6]

## feeding data plot
xii = 0minute .. 100minute
fm1 = fed_results[1].meanval[xii]
fm2 = fed_results[2].meanval[xii]
x1 = uconvert.(minute, axisvalues(fm1)...) |> ustrip
p[1].plot(x1, fm1)
p[2].plot(x1, fm2)

## Lick data plot
lm1 = lick_results[1].meanval[xii]
lm2 = lick_results[2].meanval[xii]
p[4].plot(x1, lm1)
p[5].plot(x1, lm2)
