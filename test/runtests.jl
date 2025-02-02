using LickometerUtils
using CSV, DataFrames
using PythonPlot
using Test

## Load data
fn = "./test/AR11.CSV"
#fn = "./test/AR11_003.CSV"
df = CSV.read(fn, DataFrame)

## Initial parameters
waittime = get_waittime(df)
thresh_cap = 100 # sensor value
thresh_interval = 150 #millisecond. Allow for 2~3 licks being detected as a single long lick.

## scale time into second (x-axis)
rawdata = df[:, 1] #data from single port
m = scaletime(length(rawdata), waittime) #total recording minute
x = range(1,m, length(rawdata))

## touch & lick
touch = detect_touch(rawdata, thresh_cap)
remove_long_touch(touch, thresh_interval)

lick = detect_lick(rawdata, thresh_cap, thresh_interval)

## Plot capacitance sensor
hfig = figure()
p1 = hfig.add_subplot(3,1,1)
p1.plot(x, df[:, 1])
xlabel("time (min)")
ylabel("Capacitance value")

## Plot touch
p2 = hfig.add_subplot(3,1,2)
p2.plot(x, touch)
xlabel("time (min)")
ylabel("Touch")

## Plot lick
p3 = hfig.add_subplot(3,1,3)
p3.plot(x, lick)
xlabel("time (ms)")
ylabel("Lick")

## Cumulative lick plot
figure( figsize = (4,3));
plot(x, cumsum(touch))
plot(x, cumsum(lick))
legend(["Touch", "Lick"])
xlabel("Time (min)")
ylabel("Cumulative touch")
tight_layout();
@testset "LickometerUtils.jl" begin
    # Write your tests here.
end
