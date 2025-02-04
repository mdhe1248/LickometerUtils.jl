using LickometerUtils
using Statistics
using CSV, DataFrames
using PythonPlot
using Test

## Load data
#fn = "./test/AR11.CSV"
fn = "./test/AR11_003.CSV"
df = CSV.read(fn, DataFrame)

## Initial parameters
rawdata = df[:, 1] #data from single port
waittime = get_waittime(df) #Probably 25 or 50 (ms)
thresh_cap = 50 # sensor value
thresh_interval = 2 #waittime * thresh_interval is the duration (ms). Allow up to 50ms for a single lick.
filter_windowsize = 50 #Number of data points. For baseline correction

## Update data
dat = TouchSensor(rawdata, waittime, thresh_cap, thresh_interval, filter_windowsize)
t0 = detect_touchmoment(dat.touch)
l0 = detect_touchmoment(dat.lick)


#### Plot capacitance sensor
## scale time into second (x-axis)
scale = "min"
m = get_recording_time(length(rawdata), waittime, scale) #total recording minute
x = range(1,m, length(rawdata))

## Plot raw data
hfig = figure(figsize = (6,6))
p1 = hfig.add_subplot(4,1,1)
p1.plot(x, dat.rawdata)
xlabel("time ($scale)")
ylabel("Capacitance value")

## Plot touch
p2 = hfig.add_subplot(4,1,2)
p2.plot(x, dat.corrected_rawdata)
xlabel("time ($scale)")
ylabel("Corrected data")

## Plot lick
p3 = hfig.add_subplot(4,1,3)
p3.plot(x, dat.touch)
xlabel("time ($scale)")
ylabel("Touch")

## Plot lick
p4 = hfig.add_subplot(4,1,4)
p4.plot(x, dat.lick)
xlabel("time ($scale)")
ylabel("Lick")

## Cumulative lick plot
figure( figsize = (4,3));
plot(x, cumsum(t0))
plot(x, cumsum(l0))
legend(["Touch", "Lick"])
xlabel("Time ($scale)")
ylabel("Cumulative touch")
tight_layout();

@testset "LickometerUtils.jl" begin
    # Write your tests here.
end
