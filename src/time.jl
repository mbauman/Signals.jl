# Time selection & restriction functions

# TODO: Perhaps use singleton types for the mode if this becomes a hotspot
time2idx(sig::Signal, t::Real, mode::Symbol=:exact) = time2idx(sig, t*s, mode)  # Should this be allowed?
function time2idx(sig::Signal, t::SecondT, mode::Symbol=:exact)
    ts = time(sig)
    ts[1] <= t <= ts[end] || throw(BoundsError())
    if mode == :exact
        r = searchsorted(ts, t)
        isempty(r) && throw(InexactError())
        return r[1]
    elseif mode == :previous
        return searchsortedlast(ts, t)
    elseif mode == :next
        return searchsortedfirst(ts, t)
    elseif mode == :nearest
        i = searchsortedlast(ts, t)
        return t - ts[i] > ts[i+1] - t ? i+1 : i
    else
        error("unknown time2idx conversion mode")
    end
end

# Time restriction
before(sig::Signal, t::SecondT) = before(sig, time2idx(sig, t, :previous))
before(sig::Signal, i::Real)    = within(sig, 1, i)

after(sig::Signal, t::SecondT) = after(sig, time2idx(sig, t, :next))
after(sig::Signal, i::Real)    = within(sig, i, length(time(sig)))

within(sig::Signal, i::(Real, Real))          = within(sig, t[1], t[2])
within(sig::Signal, t::(SecondT, SecondT))    = within(sig, time2idx(sig, t[1], :next), time2idx(sig, t[2], :previous))
within(sig::Signal, t1::SecondT, t2::SecondT) = within(sig, time2idx(sig, t1,   :next), time2idx(sig, t2,   :previous))
function within(sig::Signal, i1::Real, i2::Real) # The real (and only) workhorse
    Signal(timewithin(sig, i1, i2), chanswithin(i1, i2))
end

# Private API (TODO: Generate these helper functions via metaprogramming?)
timebefore(sig::Signal, t::SecondT)               = timebefore(sig, time2idx(sig, t, :previous))
timebefore(sig::Signal, i::Real)                  = timewithin(sig, 1, i)
timeafter(sig::Signal,  t::SecondT)               = timeafter(sig, time2idx(sig, t, :next))
timeafter(sig::Signal,  i::Real)                  = timewithin(sig, i, length(time(sig)))
timewithin(sig::Signal, t1::SecondT, t2::SecondT) = timewithin(sig, time2idx(sig, t1,   :next), time2idx(sig, t2,   :previous))
timewithin(sig::Signal, i1::Real, i2::Real)       = time(sig, i1:i2)

chanbefore(sig::Signal, idx, t::SecondT)               = chanbefore(sig, idx, time2idx(sig, t, :previous))
chanbefore(sig::Signal, idx, i::Real)                  = chanwithin(sig, idx, 1, i)
chanafter(sig::Signal,  idx, t::SecondT)               = chanafter(sig,  idx, time2idx(sig, t, :next))
chanafter(sig::Signal,  idx, i::Real)                  = chanwithin(sig, idx, i, length(time(sig)))
chanwithin(sig::Signal, idx, t1::SecondT, t2::SecondT) = chanwithin(sig, idx, time2idx(sig, t1,   :next), time2idx(sig, t2,   :previous))
chanwithin(sig::Signal, idx, i1::Real, i2::Real)       = sig[idx][i1:i2]

chansbefore(sig::Signal, t::SecondT)               = chansbefore(sig, time2idx(sig, t, :previous))
chansbefore(sig::Signal, i::Real)                  = chanswithin(sig, 1, i)
chansafter(sig::Signal,  t::SecondT)               = chansafter(sig, time2idx(sig, t, :next))
chansafter(sig::Signal,  i::Real)                  = chanswithin(sig, i, length(time(sig)))
chanswithin(sig::Signal, t1::SecondT, t2::SecondT) = chanswithin(sig, time2idx(sig, t1,   :next), time2idx(sig, t2,   :previous))
chanswithin(sig::Signal, i1::Real, i2::Real)       = [c[i1:i2] for c in sig]

# Windowing a regular signal returns a signal of a signals: one for each channel
# each with a timebase of the window size and length(at) repetitions
# Window defaults to windowing all channels
# convert seconds to relative indices ahead of time for regular signals

# Note that, given locations in times that are not exactly on a sample point,
# this *snaps* the time vector of the resulting Signal to the nearest sample.
# Were this not done, there are two things that become problematic:
#  1. Fencepost problems: If the window is exactly `m` multiples of the sampling
#     rate (or is specified in indices), the result of windowing may have m or
#     m+1 samples depending on the event location (m+1 when exactly on a sample
#     point, m otherwise). This would be very difficult to handle downstream.
#  2. We could no longer combine multiple repetitions into one Signal object as
#     the times of each repetition would vary by as much as ±0.5dt. The only
#     sensible way to combine such signals is to upsample them all to a common
#     timebase. This is something that the user could do ahead of time if they
#     are concerned about jitter on the scale of ±0.5dt.
function window{S<:SecondT}(sig::RegularSignal, at::AbstractVector{S}, within::(Real, Real))
    window(sig, [time2idx(sig, a, :nearest) for a in at], within)
end
# Can't use within::(Union(SecondT,Real), Union(SecondT,Real)) due to ambiguity
function window{S<:SecondT}(sig::RegularSignal, at::AbstractVector{S}, within::(SecondT, SecondT))
    window(sig, [time2idx(sig, a, :nearest) for a in at], within) 
end
function window{R<:Real}(sig::RegularSignal, at::AbstractVector{R}, within::(SecondT, SecondT))
    window(sig, at, (iceil(within[1]*samplingfreq(sig)), ifloor(within[2]*samplingfreq(sig))))
end
function window{R<:Real,R2<:Real}(sig::RegularSignal, at::AbstractVector{R}, within::(R2, R2))
    r = within[1]:within[2]
    dt = float(samplingrate(sig)) # TODO: Math with SIUnits is very annoying.
    t = (within[1]*dt):dt:(within[2]*dt)
    cs = [VectorSignal(t, [c[a+r] for a in at]) for c in sig]
    VectorSignal(time(sig, at), cs)
end

# Windowing an irregular signal cannot aggregate the Signals together into a
# common time-base across all the repetitions. We could aggregate *channels*
# together within each repetition, but that is the effective transpose of what
# we need. Furthermore, specifying indices vs. time can behave very differently
# because we don't snap to the nearest sample like RegularSignals. So there are
# four different cases, each constructing a matrix of one-channel Signals:
function window{S<:SecondT}(sig::Signal, at::AbstractVector{S}, within::(Real, Real))
    # Set number of indexes within each window, about time
    r1, r2 = within
    r = r1:r2
    cs = [(i = time2idx(sig, t, :nearest); signal(time(sig, i+r) - t, c[i+r])) for t in at, c in sig]
    signal(at, cs)
end
function window{R<:Real}(sig::Signal, at::AbstractVector{R}, within::(Real, Real))
    # Set number of indexes within each window, about indices
    r1, r2 = within
    r = r1:r2
    cs = [signal(time(sig, i+r) - time(sig, i), c[i+r]) for i in at, c in sig]
    signal(time(sig, at), cs)
end
function window{S<:SecondT}(sig::Signal, at::AbstractVector{S}, within::(SecondT, SecondT))
    # Time windows, about times
    t1, t2 = within
    cs = [signal(timewithin(sig, t+t1, t+t2)-t, chanwithin(sig, c, t+t1, t+t2)) for t in at, c in 1:length(sig)]
    signal(at, cs)
end
function window{R<:Real}(sig::Signal, at::AbstractVector{R}, within::(SecondT, SecondT))
    # time windows, about indices
    t1, t2 = within
    cs = [(t = time(sig, i); signal(timewithin(sig, t+t1, t+t2)-t, chanwithin(sig, c, t+t1, t+t2))) for i in at, c in 1:length(sig)]
    signal(time(sig, at), cs)
end
