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
                      sin(0.8:0.4:8.6) .* [0:0.02:.1, .15:.1:1, 1:-.2:.1] .* 50)
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
    244-element Array{Int64,1}: …
    
    julia> spikes = window(sig, idxs, (-200μs, 800μs))
    1-channel Signals.Signal:
      Each channel has 244 datapoints from 0.232675 s to 59.96645 s
      0.232675 s: ▆▇▆▆▆▆▅▅▄▄▂▁▁▁▁▁▂▃▃▅▆▆▆▇▇▇▇█▇▇▆▆▆▅▆▅▅▆▅▆▆
      0.334525 s: ▆▅▆▆▆▆▅▄▄▃▃▂▁▁▁▂▃▃▄▅▆▆▆▇▇▇█▇▇▆▆▆▆▆▅▆▆▅▆▅▆
       0.82495 s: ▄▅▅▅▅▅▅▄▄▂▂▁▁▂▃▅▇▇█▇▅▄▅▄▄▄▄▄▅▅▅▄▄▅▄▄▄▄▄▄▄
        0.9038 s: ▅▆▆▆▅▅▆▅▅▃▃▂▂▁▁▂▂▂▃▄▄▅▆▆▆▇█▇▇▇▇▆▆▆▆▅▅▆▆▅▅
      1.411275 s: ▄▄▄▄▄▄▄▃▃▂▁▁▁▂▅▇█▇▆▅▃▄▄▄▄▃▄▄▄▄▅▄▄▄▄▄▄▄▄▃▄
      1.414375 s: ▄▄▃▄▃▄▄▃▂▂▁▁▁▂▅▇█▇▆▅▃▄▃▄▃▄▄▄▄▄▄▄▄▄▄▄▄▃▄▄▃
      1.590175 s: ▆▆▅▆▆▆▅▅▄▃▃▂▁▁▂▂▂▄▄▅▆▆▇▇▇█▇▇▇▆▆▆▆▆▅▅▆▆▆▆▆
      2.092475 s: ▄▄▄▄▄▃▄▃▃▂▂▁▁▁▁▂▄▇█▇▆▄▅▄▄▃▄▄▄▄▄▄▄▄▄▃▄▄▃▃▄
      2.092525 s: ▄▄▄▃▄▃▃▂▂▁▁▁▁▂▄▇█▇▆▄▅▄▄▃▄▄▄▄▄▄▄▄▄▃▄▄▃▃▄▅▃
        2.2723 s: ▆▅▆▆▆▆▆▆▆▄▃▃▂▁▁▂▂▃▃▄▅▆▆▆▇▇▇▇▇█▇▆▆▆▆▅▆▆▆▆▆
       2.57675 s: ▄▄▄▄▄▄▄▃▂▁▁▁▂▂▄▆█▇▅▅▄▃▄▄▄▄▄▄▄▄▄▄▄▄▃▃▄▃▄▄▄
        2.8082 s: ▄▄▄▄▄▅▄▂▃▁▁▁▂▂▄▇█▇▆▅▄▃▄▅▄▄▄▃▄▄▄▃▄▄▄▄▄▄▄▄▃
       2.90325 s: ▄▃▄▄▄▄▄▃▃▁▁▁▁▃▄▇█▇▇▅▄▄▄▃▄▄▃▄▄▄▄▃▄▃▄▄▄▄▃▄▄
        3.2133 s: ▆▆▆▆▅▅▅▅▄▃▂▁▁▁▁▁▂▃▄▅▆▆▇▇▇▇▇█▇▆▆▆▆▅▆▆▅▆▅▆▆
      3.229075 s: ▄▄▄▄▄▄▄▄▂▁▁▁▁▃▅▇█▇▆▅▃▃▄▃▄▄▃▄▄▄▃▄▄▃▄▄▄▄▄▄▄
      3.790625 s: ▆▆▆▆▅▅▅▅▄▃▃▂▁▁▁▁▁▂▃▃▅▅▆▆▇█▇▇▇▇▇▆▆▆▅▅▆▆▅▆▅
      ⋮         : ⋮

The `window` function is returning 1ms of data back to us for each threshold, packaged together into an irregularly sampled signal.  It keeps the threshold-crossing timestamps neatly connected to the actual snippet waveforms.

Let's look a bit closer at the first "channel" of `spikes`:

    julia> snips = spikes[1]
    244-channel Signals.Signal:
      Each channel has 41 datapoints from -0.0002 s to 0.0008 s, at 40000.0 s⁻¹
      1.4234450924665925    7.468387519159538    …   1.152344001943351      1.4846155477335388
      9.185479220593425    -2.377397050707207       -2.0728338967556637     0.888555479573104
      4.938282202984665    -0.6783157653233518       2.6401901582359186     5.7723290994214675
      3.494059493697093     4.384418856889594        2.246299854521021      5.641233679881379
      0.5551553919253401    0.31022790808604295      2.5633646830088774    -3.1326802794739432
      3.471289669768316     1.202736626858985    …   4.577519053054585     -0.7706714381406417
     -5.733293726873521    -6.796391233583272       -1.7223985938821889    -7.224093836796728
     -7.18911444696532    -11.871889965518742       -5.316391283029029     -3.1037148470795115
      ⋮                                          ⋱
     -5.1419872739760475    5.5770132649924475      -0.018104666910257514  -6.109071786242671
     -0.6185244253180804   -2.9998451050085744       7.072594993017859     -2.0890143360533084
     -3.884387742256716     3.91427202701932     …  -2.6002299087019822    -4.86184501513248
     -2.6875931126314283    1.2820878597415064       0.24619164959629278   -3.995215657495417
      1.6561172269696525   -4.401927099750241        1.9529624039304592     4.587791146080367
     -1.983322545183078    -0.142295398413273       -3.4065430978158675    -2.4177907662237255
      1.2580997101547946   -7.5539375839864995       0.9363466336404049     7.138836686241775
      1.4772561295127062    4.239547752352428    …   8.476482728729541      0.28644915870329835
  
Now, the elements of `snips` are still called channels, but they're really just repetitions.  There's 250 of them, one for each threshold crossing.  And their time base, -0.2 to 0.8ms is still there.

    julia> snips[1]'
    1x41 Array{Float64,2}:
     1.42345  9.18548  4.93828  3.49406  0.555155  3.47129  …  1.65612  -1.98332  1.2581  1.47726

    julia> snips.time
    -0.0002 s:2.5e-5 s:0.0008 s

## Stuff to do

Take a look at the issues list for some of my current thoughts.  Some big-ticket items that are still outstanding are smart plotting (not just sparklines) and high-level filtering.
