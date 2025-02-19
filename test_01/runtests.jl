using LickometerUtils
using Statistics
using CSV, DataFrames
using PythonPlot
using Test

## Load data
#fn = "./test/AR11.CSV"
fn = "AR11_003.CSV"
df = CSV.read(fn, DataFrame)

## Initial parameters
rawdata = df[:, 1] #data from single port
sampling_interval = get_sampling_interval(df) #Probably 25 or 50 (ms)
thresh_cap = 50 # sensor value
thresh_interval = 2 #waittime * thresh_interval is the duration (ms). Allow up to 50ms for a single lick.
filter_windowsize = 50 #Number of data points. For baseline correction

## Process and update data 
result = TouchSensor(rawdata, sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
t0 = detect_touchmoment(result.touch)
l0 = detect_touchmoment(result.lick)


#### Plot capacitance sensor
## scale time into second (x-axis)
scale = "min"
xi = get_recording_time(length(rawdata), sampling_interval, scale) #total recording time in minute

## Plot raw data
hfig = figure(figsize = (6,6))
p1 = hfig.add_subplot(4,1,1)
p1.plot(xi, result.rawdata)
xlabel("time ($scale)")
ylabel("Capacitance value")

## Plot touch
p2 = hfig.add_subplot(4,1,2)
p2.plot(xi, result.corrected_rawdata)
xlabel("time ($scale)")
ylabel("Corrected data")

## Plot lick
p3 = hfig.add_subplot(4,1,3)
p3.plot(xi, result.touch)
xlabel("time ($scale)")
ylabel("Touch")

## Plot lick
p4 = hfig.add_subplot(4,1,4)
p4.plot(xi, result.lick)
xlabel("time ($scale)")
ylabel("Lick")

## Cumulative lick plot
figure( figsize = (4,3));
plot(xi, cumsum(t0))
plot(xi, cumsum(l0))
legend(["Touch", "Lick"])
xlabel("Time ($scale)")
ylabel("Cumulative touch")
tight_layout();

@testset "LickometerUtils.jl" begin
    # Write your tests here.
end
