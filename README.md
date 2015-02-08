# Signals

[![Build Status](https://travis-ci.org/mbauman/Signals.jl.svg?branch=master)](https://travis-ci.org/mbauman/Signals.jl) [![Coverage Status](https://img.shields.io/coveralls/mbauman/Signals.jl.svg)](https://coveralls.io/r/mbauman/Signals.jl)

A package specialized for signals that vary over time, where time is measured in seconds.  This is very much a work in progress.  Collaboration is welcome!

## Design

A `Signal` is an array whose elements (typically channels) are vectors along a time axis. It keeps track of the time values, allowing both regularly-sampled (in a `RegularSignal`) or discrete time axes, where the step between timepoints is not constant.  Regularly sampled signals are simply Signals whose time vector is a Range.  This allows for some very nice optimizations and saving of space.  Time is always in seconds.

Since the elements of a Signal are vectors, `sig1` can be a channel of another Signal `sig2` (if `sig1` has the same number of channels as timepoints in `sig2`).  In this case, the terminology gets a little awkward -- the channels of the nested Signal `sig1` would probably be more appropiately described as repetitions. But this can be very nice way to associate events at specific times with repetitions of a signal.  This can be the first step in averaging signals about a recurring event or building of a peri-stimulus time histogram, or it may simply be used to associate spike snippets with their times.

## Example usage:

    julia> Pkg.clone("https://github.com/mbauman/Signals.jl.git")
           Pkg.checkout("SIUnits") # Currently requires the master branch
           using Signals
           
    julia> fs = 40000 # Generate a 40kHz noisy signal, with spike-like stuff added for testing
           y = randn(60*fs+1)*3
           for spk = (sin(0.8:0.2:8.6) .* [0:0.01:.1, .15:.1:.95, 1:-.05:.05]   .* 50,
                      sin(0.8:0.2:8.6) .* [0:0.01:.1, .15:.05:1, 1:-.1:.1, .05] .* 50)
               i = rand(round(Int,.001fs):1fs)
               while i+length(spk)-1 < length(y)
                   y[i:i+length(spk)-1] += spk
                   i += rand(round(Int,.001fs):1fs)
               end
           end
        
    julia> sig = Signal(0:1/fs:(length(y)-1)/fs, y) # Create a signal object!
    1-channel Signals.Signal:
      Each channel has 2400001 datapoints from 0.0 s to 60.0 s, at 40000.0 s⁻¹
      ⋮

RegularSignals know their sampling rate and display it nicely. The time vector in this case is stored as a range (with all the optimizations—both space and time—that it brings).  There can be many channels in many dimensions, all of which share the same time base.

But you can also create signals that aren't regularly sampled.  Let's take this one channel and find those spikes again.

    julia> idxs = find(diff(sig[1] .< -15) .> 0)
    252-element Array{Int64,1}: …
    
    julia> spikes = window(sig, idxs, (-200μs, 800μs))
    1-channel Signals.Signal:
      Each channel has 252 datapoints from 0.43895 s to 59.78225 s
       0.43895 s: ▅▄▄▅▅▄▄▃▃▂▂▁▁▁▁▂▂▂▃▄▆▆▇▇▇▇█▆▇▆▅▅▄▅▅▄▃▅▅▄▄
        0.8222 s: ▆▆▆▆▆▆▆▅▅▄▃▂▂▂▁▁▂▂▃▄▄▆▆▇▇█▇▇▇▇▇▇▆▆▅▆▆▆▅▆▆
      0.881075 s: ▄▄▄▅▃▄▄▃▃▃▃▃▁▂▁▁▁▁▁▁▃▃▅▆▆▇█▇▇▆▆▅▅▄▄▄▄▄▄▄▅
       0.88115 s: ▅▃▄▄▃▃▃▃▃▁▂▁▁▁▁▁▁▃▃▅▆▆▇█▇▇▆▆▅▅▄▄▄▄▄▄▄▅▄▅▄
      0.929375 s: ▆▆▅▆▅▆▆▅▅▄▄▃▃▂▁▁▁▂▃▃▄▄▅▆▇▇▇█▇▆▇▆▇▆▆▅▅▆▆▆▆
      0.929425 s: ▅▆▅▆▆▅▅▄▄▃▃▂▁▁▁▂▃▃▄▄▅▆▇▇▇█▇▆▇▆▇▆▆▅▅▆▆▆▆▆▆
         1.035 s: ▆▅▆▆▅▅▅▅▅▄▃▂▂▁▁▁▂▂▃▄▅▅▆▆▇▇▇█▇▇▇▆▆▆▅▆▅▅▆▅▆
      1.365275 s: ▅▅▅▄▄▄▃▃▃▂▂▂▁▁▁▁▁▁▁▂▅▅▆▇▇▇█▇▆▆▅▅▄▄▄▄▅▄▄▄▄
      1.523675 s: ▄▄▄▄▄▄▄▃▃▂▂▂▁▁▁▁▁▂▂▃▄▅▆▇█▇▆▆▆▆▅▄▄▄▄▄▄▄▄▄▅
       1.72695 s: ▆▆▆▆▆▆▅▄▄▃▂▁▁▁▁▁▂▃▄▅▅▇▆▇▇▇█▇▇▇▆▆▆▆▆▅▆▆▆▆▆
      1.846575 s: ▆▅▆▅▅▅▆▅▄▄▃▂▁▁▁▁▂▂▃▄▅▅▆▇▇▇▇█▇▆▇▆▆▆▆▅▆▅▅▆▆
        1.9027 s: ▅▅▅▄▅▄▄▄▃▂▂▂▂▁▁▁▂▂▃▄▄▆▇▇▇█▇▇▆▆▅▅▅▄▄▄▅▅▄▄▄
        2.0623 s: ▇▆▆▆▆▆▆▆▅▄▃▃▂▁▁▁▂▃▄▄▅▆▆▆▇▇█▇▇▇▇▇▆▆▆▆▆▆▆▆▆
       2.61665 s: ▆▆▆▆▆▆▅▅▅▄▃▃▂▁▁▁▁▂▃▄▄▅▅▆▇▇▇█▇▇▇▆▆▆▆▆▆▆▆▆▆
       2.74445 s: ▄▄▄▄▄▄▄▃▃▂▂▂▁▁▁▁▂▂▃▄▅▅▆▆▆█▇▆▆▅▄▄▄▄▄▄▄▄▄▄▄
       2.77055 s: ▅▄▄▅▄▄▄▄▃▃▂▂▂▂▁▁▁▁▂▃▄▅▇▇▇█▇▇▆▇▅▅▅▅▄▅▄▅▅▄▄
      ⋮         : ⋮

The `window` function is returning 1ms of data back to us for each threshold, packaged together into an irregularly sampled signal.  It keeps the threshold-crossing timestamps neatly connected to the actual snippet waveforms.

Let's look a bit closer at the first "channel" of `spikes`:

    julia> snips = spikes[1]
    252-channel Signals.Signal:
      Each channel has 41 datapoints from -0.0002 s to 0.0008 s, at 40000.0 s⁻¹
       5.306880004345258    0.006406337231743553   3.464638635218165    …    1.1609662910886862
      -0.7612873679613665   3.7126515360049996     1.8780824490664738        1.799765848175257
       0.4069952774929375   6.717172398748497      2.9065946530976126       -1.5511479700175745
       5.246968046933468    2.1052837383312117     4.239197628142568        -2.980193371353037
       3.664142995019853    0.4161493927235327    -6.009777987534029        -1.990443323400188
      -3.493241608483568    0.4816883354585908     0.49127015174544475  …   -5.334829416798311
      -3.5926404932079103   0.49988766775675975   -2.167334006256121        -4.285602168220942
     -12.42948441329311    -4.532701928176711     -8.53506101605329        -14.335730820210516
       ⋮                                                                ⋱
       3.809408087574148    4.319008118769778      2.4576482114591007       -4.486576933703155
       0.6510171018606636  -3.750598829072038      0.5375818108076873        0.005525002804324679
      -3.5621462990506054   0.345671484483268      0.5981206582237535   …    0.7698576557724018
      -8.252472980216908    1.9508410169592105    -1.6724695101222573        2.2029537641579973
       2.7257445403176543   4.515110249074433      0.8538160755713697        1.4367081807706001
       2.600574125879401   -3.5742872591668933    -1.528753279643352        -2.99381002664557
      -1.8392222050772524   3.5596514899990708     0.9786505675719901        1.434157362925891
      -1.7219372071755341  -1.419362389302502      5.472314326513038    …   -5.194924130268105
  
Now, the elements of `snips` are still called channels, but they're really just repetitions.  There's 250 of them, one for each threshold crossing.  And their time base, -0.2 to 0.8ms is still there.

    julia> snips[1]'
    1x41 Array{Float64,2}:
     5.30688  -0.761287  0.406995  5.24697  3.66414  …  2.72574  2.60057  -1.83922  -1.72194

    julia> snips.time
    -0.0002 s:2.5e-5 s:0.0008 s

## Stuff to do

Take a look at the issues list for some of my current thoughts.  Some big-ticket items that are still outstanding are smart plotting (not just sparklines) and high-level filtering.
