using LickometerUtils
using CSV, DataFrames
using PythonPlot
using Test

## Load data
fn = "./test/AR11.CSV"
#fn = "./test/AR11_003.CSV"
df = CSV.read(fn, DataFrame)

## Initial parameters
rawdata = df[:, 1] #data from single port
waittime = get_waittime(df) #Probably 25 or 50 (ms)
thresh_cap = 100 # sensor value
thresh_interval = 50 #millisecond. Allow for 2~3 licks being detected as a single long lick.
dat = TouchSensor(rawdata, waittime, thresh_cap, thresh_interval)

## detect touch & lick
touch = detect_touch(dat)
lick = detect_lick(dat)
touchon = detect_touchmoment(touch)
lickon = detect_touchmoment(lick)

#### Plot capacitance sensor
## scale time into second (x-axis)
scale = "min"
m = get_recording_time(length(rawdata), waittime, scale) #total recording minute
x = range(1,m, length(rawdata))

## Plot raw data
hfig = figure()
p1 = hfig.add_subplot(3,1,1)
p1.plot(x, df[:, 1])
xlabel("time ($scale)")
ylabel("Capacitance value")

## Plot touch
p2 = hfig.add_subplot(3,1,2)
p2.plot(x, touch)
xlabel("time ($scale)")
ylabel("Touch")

## Plot lick
p3 = hfig.add_subplot(3,1,3)
p3.plot(x, lick)
xlabel("time ($scale)")
ylabel("Lick")

## Cumulative lick plot
figure( figsize = (4,3));
plot(x, cumsum(touchon))
plot(x, cumsum(lickon))
legend(["Touch", "Lick"])
xlabel("Time ($scale)")
ylabel("Cumulative touch")
tight_layout();

@testset "LickometerUtils.jl" begin
    # Write your tests here.
end
