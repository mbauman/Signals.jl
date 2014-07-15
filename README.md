# Signals

[![Build Status](https://travis-ci.org/mbauman/Signals.jl.svg?branch=master)](https://travis-ci.org/mbauman/Signals.jl)

A package specialized for signals that vary over time, where time is measured in seconds.  This is very much a work in progress.  Collaboration is welcome!

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
    Signal with 1 channel over t=0.0 to 60.0, at 40000.0 Hz:
      Each channel has 2400001 datapoints of type Array{Float64,1}

Signals know their sampling rate and display it nicely. The time vector in this case is stored as a range (with all the optimizations—both space and time—that it brings).  There can be many channels, all which share the same time base.

But you can also create signals that aren't regularly sampled.  Let's take this one channel and find those spikes again.

    julia> idxs = find(diff(sig[1] .< -15) .> 0) # Threshold on negative crossings
    258-element Array{Int64,1}: …
    
    julia> spikes = window(sig, idxs, (-200μs, 800μs))
    Signal with 1 channel over t=0.90815 to 59.676:
      Each channel has 258 datapoints of type Signal{258,FloatRange{Float64},Array{Float64,1}}
       0.90815: ▆▆▆▆▆▆▆▅▅▄▄▂▂▁▁▁▃▂▃▄▅▆▆▆▇▇█▇▇▇▇▇▆▆▆▅▆▅▅▆▆
      0.943575: ▅▅▄▅▄▄▃▄▃▂▂▁▁▁▁▁▂▂▃▄▅▆▆▇▇█▇▆▆▆▅▄▅▄▅▅▅▄▅▅▅
      0.983425: ▅▄▄▄▄▄▄▃▂▂▂▂▁▁▁▁▁▂▃▄▅▅▇█▇▇▇▆▆▅▄▄▄▄▄▄▄▄▄▄▄
       1.08085: ▅▄▅▄▅▅▄▄▃▂▁▁▁▁▁▁▁▁▂▃▃▅▆▇█▇▇▇▇▆▅▅▅▄▅▄▄▄▅▄▅
      1.158525: ▅▆▆▅▅▅▅▅▄▄▃▂▁▁▁▁▂▂▃▄▅▅▆▆▇█▇▇▇▇▇▆▆▆▅▆▅▅▅▅▅
       1.51325: ▆▆▆▆▆▆▅▅▄▃▂▁▁▁▁▁▂▃▄▅▆▆▇▇▇█▇▆▇▆▆▆▆▆▅▅▅▅▅▅▆
      1.642425: ▄▄▄▅▄▄▃▃▃▂▂▁▁▁▁▁▁▂▃▃▅▇▇█▇▇▇▇▆▆▅▅▅▄▄▄▄▄▄▅▄
      1.835975: ▅▅▄▅▄▅▄▃▃▃▃▃▂▁▁▁▁▁▂▃▃▄▄▆▇█▇▇▇▆▆▆▅▄▅▄▄▄▄▄▄
      1.836025: ▄▅▄▅▄▃▃▃▃▃▂▁▁▁▁▁▂▃▃▄▄▆▇█▇▇▇▆▆▆▅▄▅▄▄▄▄▄▄▅▄
      2.059975: ▆▆▆▆▆▆▅▅▄▃▂▁▁▁▁▂▃▃▄▅▆▆▆▇▇▇▇█▇▇▆▆▆▆▆▆▆▅▅▆▆
      2.587675: ▅▅▆▅▆▅▅▄▄▃▂▂▁▁▁▁▂▃▄▄▅▆▇▆▇▇█▇▆▆▆▆▅▅▆▅▅▅▅▅▅
        2.5999: ▆▆▆▅▆▅▅▅▅▄▃▂▂▁▁▁▂▃▃▄▅▆▆▆▇▇█▇▇▇▆▆▆▆▅▆▅▆▅▅▆
      2.624775: ▅▄▅▅▅▄▄▄▃▃▂▁▁▂▁▂▂▂▃▄▆▆▇▇█▇▇▇▆▅▅▅▄▄▄▅▅▅▄▄▄
      2.722325: ▆▆▇▆▆▆▇▅▅▄▃▂▁▁▁▁▁▂▃▃▄▆▆▆▇▇▇▇▇█▇▆▆▇▆▆▆▆▆▆▆
      3.046875: ▆▆▆▆▆▅▆▅▅▄▃▂▁▁▁▁▁▂▃▃▄▅▅▆▆▇█▇▇▇▇▆▆▅▅▆▅▆▅▆▅
        3.1573: ▄▄▅▄▄▄▄▄▄▂▃▂▂▁▁▁▁▂▂▂▄▅▆▇▇█▇▇▆▆▅▅▅▄▅▄▄▄▄▄▄
       3.15735: ▅▄▄▄▄▄▄▂▃▂▂▁▁▁▁▂▂▂▄▅▆▇▇█▇▇▆▆▅▅▅▄▅▄▄▄▄▄▄▄▄
       3.28905: ▆▆▆▆▆▆▆▅▅▄▄▂▂▁▁▁▂▃▃▄▅▅▆▇▇█▇▇▇▇▆▇▆▆▆▅▆▆▆▅▆
      3.671775: ▅▅▄▄▄▃▄▃▂▁▂▁▁▁▁▁▁▂▃▄▅▅▇▇▇█▇▇▆▅▄▄▄▄▄▄▄▄▄▄▄
       3.81325: ▅▅▅▅▅▄▄▄▃▂▂▁▁▁▁▁▁▂▃▄▅▇▇▇█▇▇▇▆▅▅▅▅▄▄▄▄▄▄▄▅
      ⋮       : ⋮

The `window` function is returning 1ms of data back to us for each threshold, packaged together into an irregularly sampled signal.  Keeping those timestamps neatly connected to the snippets.

Let's look a bit closer at the first "channel" of `spikes`:

    julia> snips = spikes[1]
    Signal with 258 channels over t=-0.0002 to 0.0008, at 40000.0 Hz:
      Each channel has 41 datapoints of type Array{Float64,1}

Now, the elements of `snips` are still called channels, but they're really just repetitions.  There's 258 of them, one for each threshold crossing.  And their time base, -0.2 to 0.8ms is still there.

    julia> snips[1]
    41-element Array{Float64,1}: …

## Stuff to do

Take a look at the issues list for some of my current thoughts.  Some big-ticket items that are still outstanding are smart plotting (not just sparklines) and high-level filtering.
