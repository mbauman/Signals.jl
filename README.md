# Signals

[![Build Status](https://travis-ci.org/mbauman/Signals.jl.svg?branch=master)](https://travis-ci.org/mbauman/Signals.jl) [![Coverage Status](https://img.shields.io/coveralls/mbauman/Signals.jl.svg)](https://coveralls.io/r/mbauman/Signals.jl)

A package specialized for signals that vary over time, where time is measured in seconds.  This is very much a work in progress.  Collaboration is welcome!

## Design

A `Signal` is a combination of a time vector with any number of data channels. It is vector (`<: AbstractVector`) of its channels, and so iteration is done across channels (not along the data within the channels), skipping the time vector.  All channels must themselves be an `AbstractVector`, and they must have the same length as the time vector.

Signals may be either regularly sampled (`RegularSignal`) or discrete, where the step between timepoints is not constant.  Regularly sampled signals are simply Signals whose time vector is a Range.  This allows for some very nice optimizations and saving of space.  Time is always in seconds.

Since a Signal is itself a vector of channels, `sig1` can be a channel of another Signal `sig2` (if `sig1` has the same number of channels as timepoints in `sig2`).  In this case, the terminology gets a little awkward -- the channels of the nested Signal `sig1` would probably be more appropiately described as repetitions. But this can be very nice way to associate events at specific times with repetitions of a signal.  This can be the first step in averaging signals about a recurring event or building of a peri-stimulus time histogram, or it may simply be used to associate spike snippets with their times.

## Example usage:

    julia> Pkg.clone("https://github.com/mbauman/Signals.jl.git")
           Pkg.checkout("SIUnits") # Currently requires the master branch
           using Signals
           
    julia> fs = 40000 # Generate a 40kHz noisy signal, with spike-like stuff added for testing
           y = randn(60*fs+1)*3 
           for spk = (sin(0.8:0.2:8.6) .* [0:0.01:.1, .15:.1:.95, 1:-.05:.05]   .* 50,
                      sin(0.8:0.2:8.6) .* [0:0.01:.1, .15:.05:1, 1:-.1:.1, .05] .* 50)
               i = rand(iround(.001fs):1fs)
               while i+length(spk)-1 < length(y)
                   y[i:i+length(spk)-1] += spk
                   i += rand(iround(.001fs):1fs)
               end
           end
           
    julia> sig = signal(0:1/fs:(length(y)-1)/fs, y) # Create a signal object!
    RegularVectorSignal with 1 channel over t=0.0 s to 60.0 s, at 40000.0 s⁻¹:
      Each channel has 2400001 datapoints of type Float64

Signals know their sampling rate and display it nicely. The time vector in this case is stored as a range (with all the optimizations—both space and time—that it brings).  There can be many channels, all which share the same time base.

But you can also create signals that aren't regularly sampled.  Let's take this one channel and find those spikes again.

    julia> idxs = find(diff(sig[1] .< -15) .> 0)
    250-element Array{Int64,1}: …

    julia> spikes = window(sig, idxs, (-200μs, 800μs))
    VectorSignal with 1 channel over t=0.7552 s to 59.584775 s:
      Each channel has 250 datapoints of type ContiguousView{Float64,1,Array{Float64,2}}
        0.7552 s: ▅▅▄▄▅▅▄▄▃▂▂▂▁▁▁▁▁▂▂▃▄▅▅▇▇▇█▇▇▆▆▄▄▄▅▄▄▄▃▄▄
       0.75935 s: ▆▅▆▆▆▆▅▅▄▄▃▃▁▁▁▂▂▃▃▄▅▆▆▇▇█▇▇▇▆▇▆▆▅▆▆▆▅▆▆▆
      1.622625 s: ▄▅▄▃▅▄▄▃▃▂▂▁▁▁▁▁▁▁▂▃▄▅▅▇▇▇▇█▆▆▅▄▄▅▄▄▄▄▄▄▄
       1.70595 s: ▅▄▅▅▄▄▄▃▃▂▂▂▂▁▁▁▁▂▂▃▄▅▆▇▇▇█▇▆▆▅▅▄▅▄▄▄▄▄▄▅
       1.74135 s: ▆▆▆▅▅▅▅▄▄▃▂▂▂▁▁▂▂▃▄▅▅▆▇▇█▆▇▇▇▆▇▆▆▆▅▆▆▅▅▆▅
      1.761325 s: ▆▇▆▆▆▆▅▄▄▃▂▁▁▁▁▁▂▃▄▅▅▆▇▇▇▇▇█▇▇▇▆▅▆▆▅▅▅▆▅▆
      1.946375 s: ▆▇▆▆▆▆▅▅▅▃▃▁▂▁▂▂▃▄▅▅▆▆▇▇█▇▇▇▇▇▇▆▆▆▆▆▆▆▆▆▆
       1.97465 s: ▅▄▅▄▅▄▄▄▃▂▂▂▁▁▁▁▁▁▂▃▄▄▆▇▇█▇▇▇▆▅▄▅▅▄▅▄▅▄▄▄
      2.546375 s: ▅▅▄▄▄▄▄▄▄▃▂▁▁▁▁▁▁▂▂▃▄▅▇▇▆▇█▇▆▆▅▄▄▄▅▄▄▅▄▄▄
        2.8466 s: ▇▆▆▆▆▆▆▅▅▄▃▂▂▁▁▁▁▂▄▄▅▅▆▆▇▇█▇▇▆▆▆▆▆▆▆▅▆▆▆▆
      3.150275 s: ▆▆▆▆▆▆▆▅▅▄▃▂▂▁▁▁▁▃▃▄▅▆▆▆▇▇█▇▇▆▆▆▆▆▅▆▅▆▆▅▆
       3.34315 s: ▅▆▄▅▄▄▄▃▃▂▂▁▁▁▁▂▂▃▄▅▆▇▇▇█▇▇▇▆▅▅▅▄▄▅▅▄▅▅▅▄
       3.86275 s: ▄▄▃▄▄▃▄▃▂▂▁▂▁▁▁▁▂▁▃▃▅▅▆█▇▇▆▆▆▅▄▄▄▄▃▄▄▄▄▄▄
      4.142575 s: ▆▆▆▆▆▅▅▅▅▄▃▂▁▁▁▂▂▂▃▄▄▅▆▇▇▇▇█▇▇▆▆▆▆▅▆▆▆▅▆▆
      4.451575 s: ▄▄▅▄▄▄▄▃▃▂▂▁▁▁▁▁▁▁▂▂▄▄▆▆▇▇█▆▆▅▅▄▄▄▄▄▄▄▄▃▄
      ⋮         : ⋮

The `window` function is returning 1ms of data back to us for each threshold, packaged together into an irregularly sampled signal.  It keeps the threshold-crossing timestamps neatly connected to the actual snippet waveforms.

Let's look a bit closer at the first "channel" of `spikes`:

    julia> snips = spikes[1]
    RegularMatrixSignal with 250 channels over t=-0.0002 s to 0.0008 s, at 40000.0 s⁻¹:
      Each channel has 41 datapoints of type Float64
  
Now, the elements of `snips` are still called channels, but they're really just repetitions.  There's 250 of them, one for each threshold crossing.  And their time base, -0.2 to 0.8ms is still there.

    julia> snips[1]
    41-element ContiguousView{Float64,1,Array{Float64,2}}: …

## Stuff to do

Take a look at the issues list for some of my current thoughts.  Some big-ticket items that are still outstanding are smart plotting (not just sparklines) and high-level filtering.
