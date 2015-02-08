# Time selection & restriction functions
abstract SnapMode
type SnapExact    <: SnapMode; end
type SnapPrevious <: SnapMode; end
type SnapNext     <: SnapMode; end
type SnapNearest  <: SnapMode; end

time2idx(sig::Signal, t::SecondT) = time2idx(sig, t, SnapExact())
function time2idx(sig::Signal, t::SecondT, ::SnapExact)
    ts = sig.time
    ts[1] <= t <= ts[end] || throw(BoundsError())
    r = searchsorted(ts, t)
    isempty(r) && throw(InexactError())
    return r[1]
end
function time2idx(sig::Signal, t::SecondT, ::SnapNearest)
    ts = sig.time
    t <= ts[1] && return 1 # No bounds errors; these are easy cases
    t >= ts[end] && return length(ts)
    i = searchsortedlast(ts, t)
    return ifelse(t - ts[i] > ts[i+1] - t, i+1, i)
end
function time2idx(sig::Signal, t::SecondT, ::SnapPrevious)
    ts = sig.time
    t < ts[1] && throw(BoundsError())
    searchsortedlast(ts, t)
end
function time2idx(sig::Signal, t::SecondT, ::SnapNext)
    ts = sig.time
    t > ts[end] && throw(BoundsError())
    searchsortedfirst(ts, t)
end

# With regular signals, we can compute and allow out-of-range indices
# TODO: "lift" these computations as FloatRange does?
_time2idxf(sig::RegularSignal, t::SecondT) = (t - sig.time[1])*samplingfreq(sig)
time2idx(sig::RegularSignal, t::SecondT, ::SnapExact)    = 1+Int(_time2idxf(sig,t))
time2idx(sig::RegularSignal, t::SecondT, ::SnapNearest)  = 1+round(Int, _time2idxf(sig,t))
time2idx(sig::RegularSignal, t::SecondT, ::SnapPrevious) = 1+floor(Int, _time2idxf(sig,t))
time2idx(sig::RegularSignal, t::SecondT, ::SnapNext)     = 1+ceil(Int, _time2idxf(sig,t))

# Time restriction
before(sig::Signal, t::SecondT) = before(sig, time2idx(sig, t, SnapPrevious()))
before(sig::Signal, i::Real)    = within(sig, 1, i)

after(sig::Signal, t::SecondT) = after(sig, time2idx(sig, t, SnapNext()))
after(sig::Signal, i::Real)    = within(sig, i, length(sig.time))

within(sig::Signal, i::(Real, Real))          = within(sig, t[1], t[2])
within(sig::Signal, t::(SecondT, SecondT))    = within(sig, time2idx(sig, t[1], SnapNext()), time2idx(sig, t[2], SnapPrevious()))
within(sig::Signal, t1::SecondT, t2::SecondT) = within(sig, time2idx(sig, t1,   SnapNext()), time2idx(sig, t2,   SnapPrevious()))
function within(sig::Signal, i1::Real, i2::Real) # The real (and only) workhorse
    data = sub(sig.data, i1:i2, :)
    data = reshape(data, tuple(length(i1:i2), size(sig)...))
    Signal(sig.time[i1:i2], data)
end

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
    window(sig, [time2idx(sig, a, SnapNearest()) for a in at], within)
end
# Can't use within::(Union(SecondT,Real), Union(SecondT,Real)) due to ambiguity
function window{S<:SecondT}(sig::RegularSignal, at::AbstractVector{S}, within::(SecondT, SecondT))
    window(sig, [time2idx(sig, a, SnapNearest()) for a in at], within)
end
function window{R<:Real}(sig::RegularSignal, at::AbstractVector{R}, within::(SecondT, SecondT))
    window(sig, at, (time2idx(sig, within[1], SnapNext()), time2idx(sig, within[2], SnapPrevious())))
end
function window{R<:Real,R2<:Real}(sig::RegularSignal, at::AbstractVector{R}, within::(R2, R2))
    r = within[1]:within[2]
    dt = float(samplingrate(sig)) # TODO: Math with SIUnits is very annoying.
    t = inseconds((within[1]*dt):dt:(within[2]*dt))

    vi = similar(sig.data, tuple(length(r), length(at), size(sig)...))
    for chan=1:length(sig)
        for rep in 1:length(at)
            vi[:, rep, chan] = sig.data[r+at[rep], chan]
        end
    end
    Signal(sig.time[at], Signal(t, vi))
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
    cs = [(i = time2idx(sig, t, SnapNearest()); signal(time(sig, i+r) - t, c[i+r])) for t in at, c in sig]
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
