# Time selection & restriction functions

# TODO: Perhaps use singleton types for the mode if this becomes a hotspot
time2idx(sig::Signal, t::Real, mode::Symbol=:exact) = time2idx(sig, t*s, mode)  # Should this be allowed?
function time2idx(sig::Signal, t::SecondT, mode::Symbol=:exact)
    sig.time[1] <= t <= sig.time[end] || throw(BoundsError())
    if mode == :exact
        r = searchsorted(sig.time, t)
        isempty(r) && throw(InexactError())
        return r[1]
    elseif mode == :previous
        return searchsortedlast(sig.time, t)
    elseif mode == :next
        return searchsortedfirst(sig.time, t)
    elseif mode == :nearest
        i = searchsortedlast(sig.time, t)
        return t - sig.time[i] > sig.time[i+1] - t ? i+1 : i
    else
        error("unknown time2idx conversion mode")
    end
end
idx2time(sig::Signal, i) = sig.time[i]

# Time restriction
before(sig::Signal, t::SecondT) = before(sig, time2idx(sig, t, :previous))
before(sig::Signal, i::Real)    = within(sig, 1, i)

after(sig::Signal, t::SecondT) = after(sig, time2idx(sig, t, :next))
after(sig::Signal, i::Real)    = within(sig, i, length(sig.time))

within(sig::Signal, i::(Real, Real))          = within(sig, t[1], t[2])
within(sig::Signal, t::(SecondT, SecondT))    = within(sig, time2idx(sig, t[1], :previous), time2idx(sig, t[2], :next))
within(sig::Signal, t1::SecondT, t2::SecondT) = within(sig, time2idx(sig, t1,   :previous), time2idx(sig, t2,   :next))
function within(sig::Signal, i1::Real, i2::Real) # The real (and only) workhorse
    Signal(timewithin(sig, i1, i2), chanswithin(i1, i2))
end

# Private API (TODO: Generate these helper functions via metaprogramming?)
timebefore(sig::Signal, t::SecondT) = timebefore(sig, time2idx(sig, t, :previous))
timebefore(sig::Signal, i::Real)    = timewithin(sig, 1, i)
timeafter(sig::Signal, t::SecondT)  = timeafter(sig, time2idx(sig, t, :next))
timeafter(sig::Signal, i::Real)     = timewithin(sig, i, length(sig.time))
timewithin(sig::Signal, i::(Real, Real))          = timewithin(sig, t[1], t[2])
timewithin(sig::Signal, t::(SecondT, SecondT))    = timewithin(sig, time2idx(sig, t[1], :previous), time2idx(sig, t[2], :next))
timewithin(sig::Signal, t1::SecondT, t2::SecondT) = timewithin(sig, time2idx(sig, t1,   :previous), time2idx(sig, t2,   :next))
timewithin(sig::Signal, i1::Real, i2::Real)       = sig.time[i1:i2]
chansbefore(sig::Signal, t::SecondT) = chansbefore(sig, time2idx(sig, t, :previous))
chansbefore(sig::Signal, i::Real)    = chanswithin(sig, 1, i)
chansafter(sig::Signal, t::SecondT)  = chansafter(sig, time2idx(sig, t, :next))
chansafter(sig::Signal, i::Real)     = chanswithin(sig, i, length(sig.time))
chanswithin(sig::Signal, i::(Real, Real))          = chanswithin(sig, t[1], t[2])
chanswithin(sig::Signal, t::(SecondT, SecondT))    = chanswithin(sig, time2idx(sig, t[1], :previous), time2idx(sig, t[2], :next))
chanswithin(sig::Signal, t1::SecondT, t2::SecondT) = chanswithin(sig, time2idx(sig, t1,   :previous), time2idx(sig, t2,   :next))
chanswithin(sig::Signal, i1::Real, i2::Real)       = [c[i1:i2] for c in sig]

# Windowing a regular signal returns a signal of a signals: one for each channel
# each with a timebase of the window size and length(at) repetitions
# Window defaults to windowing all channels
# convert seconds to relative indices ahead of time for regular signals
function window{N,T<:Range,S<:SecondT}(sig::Signal{N,T}, at::AbstractVector{S}, within::(Real, Real), channels=1:length(sig))
    window(sig, [time2idx(sig, a, :nearest) for a in at], within, channels)
end
# Can't use a Union(SecondT, Real) due to ambiguity
function window{N,T<:Range,S<:SecondT}(sig::Signal{N,T}, at::AbstractVector{S}, within::(SecondT, SecondT), channels=1:length(sig))
    window(sig, [time2idx(sig, a, :nearest) for a in at], within, channels) 
end
function window{N,T<:Range,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(SecondT, SecondT), channels=1:length(sig))
    window(sig, at, (iceil(within[1]*samplingfreq(sig)), ifloor(within[2]*samplingfreq(sig))))
end
function window{N,T<:Range,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    r = within[1]:within[2]
    t = (within[1]/samplingfreq(sig)):(1/samplingfreq(sig)):(within[2]/samplingfreq(sig))
    
    cs = Array(Signal{length(at),typeof(t),S}, length(channels))
    for (i,c) in enumerate(channels)
        cs[i] = Signal(t, [sig[c][a+r] for a in at])
    end
    Signal(sig.time[at], cs)
end

# Windowing an irregular signal cannot aggregate the Signals together into a
# common time-base. Therefore, it returns an array of signals. Furthermore,
# specifying indices vs. time can behave very differently. This is much more
# difficult, with four different cases:
function window{N,T,S,R<:SecondT}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    # Set number of indexes within each window, about time
    r1, r2 = within
    r = r1:r2
    @show sig.time[time2idx(sig, at[1], :nearest)+r] - at[1]
    cs = Signal[(i = time2idx(sig, t, :nearest); Signal(sig.time[i+r] - t, chanswithin(sig,i+r1,i+r2))) for t in at]
    signal(at, cs)
end
function window{N,T,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    # Set number of indexes within each window, about indices
    r1, r2 = within
    r = r1:r2
    cs = Signal[Signal(sig.time[i+r] - sig.time[i], chanswithin(sig,i+r1, i+r2)) for i in at]
    
    signal(sig.time[at], cs)
end
function window{N,T,S,R<:SecondT}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(SecondT, SecondT), channels=1:length(sig))
    # Time windows, about times
    t1, t2 = within
    cs = Signal[Signal(timewithin(sig, t+t1, t+t2)-t, chanswithin(sig, t+t1, t+t2)) for t in at]
    signal(at, cs)
end
function window{N,T,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(SecondT, SecondT), channels=1:length(sig))
    # time windows, about indices
    t1, t2 = within
    cs = Signal[(t = idx2time(sig,i); Signal(timewithin(sig, t+t1, t+t2)-t, chanswithin(sig, t+t1,t+t2))) for i in at]
    signal(sig.time[at], cs)
end
