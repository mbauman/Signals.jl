# Low level time selection & restriction functions

# TODO: Perhaps use singleton types for the mode if this becomes a hotspot
function time2idx(sig::Signal, t, mode::Symbol=:exact)
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
        return t - time[i] > time[i+1] - t ? i+1 : i
    else
        error("unknown time2idx conversion mode")
    end
end
idx2time(sig::Signal, i) = sig.time[i]

# Time restriction (TODO: should this use seconds to differentiate time/idxs?)
timebefore(sig::Signal, t::Real) = idxsbefore(sig, time2idx(sig, t, :previous))
idxsbefore(sig::Signal, i::Real) = idxswithin(sig, 1, i)

timeafter(sig::Signal, t::Real) = idxsafter(sig, time2idx(sig, t, :next))
idxsafter(sig::Signal, i::Real) = idxswithin(sig, i, length(sig.time))

timewithin(sig::Signal, t1::Real, t2::Real) = idxswithin(sig, time2idx(sig, t1, :previous), time2idx(sig, t2, :next))
timewithin(sig::Signal, t::(Real, Real)) = timewithin(sig, t[1], t[2])
idxswithin(sig::Signal, t::(Real, Real)) = idxswithin(sig, t[1], t[2])
function idxswithin(sig::Signal, i1::Real, i2::Real)
    Signal(sig.time[i1:i2], [c[i1:i2] for c in sig])
end

# Higher-level API: use SIUnits to flag indices vs. time?
import SIUnits
typealias SecondT{T} SIUnits.SIQuantity{T,0,0,1,0,0,0,0}

# Windowing a regular signal returns a signal of a signals: one for each channel
# each with a timebase of the window size and length(at) repetitions
# Window defaults to windowing all channels
# convert seconds to relative indices ahead of time for regular signals
function window{N,T<:Range,S<:SecondT}(sig::Signal{N,T}, at::AbstractVector{S}, within::(Real, Real), channels=1:length(sig))
    window(sig, [time2idx(sig, float(a), :nearest) for a in at], within, channels)
end
function window{N,T<:Range,S<:SecondT}(sig::Signal{N,T}, at::AbstractVector{S}, within::(SecondT, SecondT), channels=1:length(sig))
    window(sig, [time2idx(sig, float(a), :nearest) for a in at], within, channels)
end
function window{N,T<:Range,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(SecondT, SecondT), channels=1:length(sig))
    window(sig, at, (iceil(float(within[1])*fs(sig)), ifloor(float(within[2])*fs(sig))))
end
function window{N,T<:Range,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    r = within[1]:within[2]
    t = r/fs(sig)
    
    cs = Array(Signal{length(at),typeof(t),S}, length(channels))
    for (i,c) in enumerate(channels)
        cs[i] = Signal(t, [sig[c][a+r] for a in at])
    end
    Signal(sig.time[at], cs)
end

# Windowing an irregular signal cannot aggregate the Signals together into a
# common time-base. Therefore, it returns an array of signals. Furthermore,
# specifying indices vs. time can behave very differently. This is much more
# difficult, with four very different cases:
function window{N,T,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    # All indices
    r = within[1]:within[2]
    
    cs = {} # TODO: type and pre-allocate properly
    for c in channels
        push!(cs, [Signal(sig.time[i+r] - sig.time[i], sig[c][i+r]) for i in at])
    end
    Signal(sig.time[at], cs)
end
function window{N,T,S,R<:SecondT}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    # All seconds
    error("unimplemented")
end
function window{N,T,S,R<:Real}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(SecondT, SecondT), channels=1:length(sig))
    # Second windows about indices
    error("unimplemented")
end
function window{N,T,S,R<:SecondT}(sig::Signal{N,T,S}, at::AbstractVector{R}, within::(Real, Real), channels=1:length(sig))
    # Indexed windows about seconds
    error("unimplemented")
end
