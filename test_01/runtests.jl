using LickometerUtils
using CSV, DataFrames
using Statistics, Unitful, AxisArrays
using PythonPlot
using Test

## Load data
#fn = "./test/AR11.CSV"
fn = "./test_01/AR11_003.CSV"
df = CSV.read(fn, DataFrame)

## Initial parameters
sampling_interval = 25  #Probably 25 or 50 (ms)
thresh_cap = 100 # sensor value
thresh_interval = 2 #waittime * thresh_interval is the duration (ms). Allow up to 50ms for a single lick.
filter_windowsize = 75 #Number of data points. For baseline correction
timescale = "min"

## licking
touch_column = 1
sensor = Touch(df[:, touch_column], sampling_interval, thresh_cap, thresh_interval, filter_windowsize)
lick = detect(sensor)

## Eating
fedbox_column = 2
fedbox = FedBox(df[:, fedbox_column]) 
eat = detect(fedbox)

## Cumulative and statistics if there are multiple datasets
lick_vec = detect.([sensor])
eat_vec = detect.([fedbox])
mean_lick, std_lick, sem_lick = analyze_multiple_sensors([sensor])
mean_eat, std_eat, sem_eat = analyze_multiple_sensors([fedbox])

## Plotting
#### Plot capacitance sensor
## get x-axis
xi_ms = range(0, step = sampling_interval, length = length(lick))u"ms"
xi_min = uconvert.(u"minute", xi_ms)
xi = getfield.(xi_min, :val)

## Plot raw data
rawdata = df[:, touch_column]
hfig = figure(figsize = (6,6))
p1 = hfig.add_subplot(4,1,1)
p1.plot(xi, rawdata)
xlabel("time ($scale)")
ylabel("Capacitance value")

## Plot touch
corrected_data = copy(rawdata)
corrected_data[corrected_data.== -2] .= 5000
baseline = estimate_baseline(corrected_data filter_windowsize)
corrected_data = corrected_data.- baseline
p2 = hfig.add_subplot(4,1,2, sharex = p1)
p2.plot(xi, corrected_data)
xlabel("time ($scale)")
ylabel("Corrected data")

## Plot touch 
touch = detect_touch(corrected_data, thresh_cap)
p3 = hfig.add_subplot(4,1,3, sharex = p1)
p3.plot(xi, touch)
xlabel("time ($scale)")
ylabel("Touch")

## Plot lick
p4 = hfig.add_subplot(4,1,4, sharex = p1)
p4.plot(xi, lick)
xlabel("time ($scale)")
ylabel("Lick")

## Cumulative lick plot
figure( figsize = (4,3));
plot(xi, cumsum(detect_touchmoment(touch)), label = "Touch")
plot(xi, mean_lick, label = "Lick")
legend(["Touch", "Lick"])
xlabel("Time ($scale)")
ylabel("Cumulative touch")
tight_layout();

@testset "LickometerUtils.jl" begin
    # Write your tests here.
end
