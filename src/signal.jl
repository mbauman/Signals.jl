import SIUnits
import SIUnits.ShortUnits: s
typealias SecondT{T} SIUnits.SIQuantity{T,0,0,1,0,0,0,0,0,0}

# A signal has a common timebase (an abstract vector of type T) in seconds, 
# and an array of data that it iterates and indexes over (each element is an 
# abstract vector of type S). The data are stored in a collection of type D, 
# which is an array of rank N+1.
abstract AbstractSignal{T<:AbstractVector, S<:AbstractVector, N} <: AbstractArray{S, N}
type Signal{T, S, N, D} <: AbstractSignal{T, S, N}
    time::T
    data::D

    dims::NTuple{N, Symbol}

    meta::Dict{Symbol, Any}
    Signal(t,d,n,m) = (_checkargs(t,d); new(t,d,n,m))
end
# There are some gotchas when using typealiases in parametric dispatch, so
# the parameters are re-arranged such that the restricted parameter comes last.
# See http://github.com/JuliaLang/julia/issues/7453
typealias RegularSignal{S, N, D, T<:Range} Signal{T, S, N, D}
typealias SignalVector{T, S, D} Signal{T, S, 1, D}
typealias SignalMatrix{T, S, D} Signal{T, S, 2, D}

# Consistency checks that aren't enforced by the type itself
_checktime{T<:SecondT}(t::Range{T}) = step(t) > 0s || throw(ArgumentError("time vector must be monotonically increasing"))
_checktime{T<:SecondT}(t::AbstractVector{T}) = issorted(t,lt=(<=)) || throw(ArgumentError("time vector must be monotonically increasing"))
_checktime(t) = throw(ArgumentError("time must be a vector specified in seconds"))
function _checkargs(t, d)
    _checktime(t)
    size(d, 1) == length(t) || throw(ArgumentError("each channel must be the same length as time"))
end

# The canonical constructor. This must figure out what the element type will be.
# This is really hard with SubArrays and slices of Signals.
stagedfunction Signal{T<:SecondT, R, N}(time::AbstractVector{T}, data::AbstractArray{R, N}, dims::(Symbol...), meta::Dict{Symbol, Any})
    data <: AbstractVector && return :(throw(ArgumentError("Signal data must be at least 2-dimensional")))
    S = SubArray{T, 1, data, tuple(Colon, ntuple(N-1, (i)->Int)...), N}
    # If the data are Signals themselves, we'll return a SignalVector
    if data <: Signal
        S = Signal{time, R, 1, S} # TODO: is S right here?
    end
    quote
        Signal{$time, $S, N-1, $data}(time, data, dims, meta)
    end
end

# A more forgiving constructor with defaults
function Signal{T,N}(time::AbstractVector, data::AbstractArray{T,N}, 
                     dims::(Symbol...) = N<=2 ? (:channel,) : ntuple(N-1, (i)->symbol("")),
                     meta::Dict{Symbol,Any} = Dict{Symbol, Any}())
    Signal(inseconds(time), atleastmatrix(data), dims, meta)
end
# For simple testing, allow vectorized functions. This could be improved
Signal(time::AbstractVector, fcns::Vector{Function}) = Signal(time, Float64[f(i) for i in time, f in fcns])

# Convert the time ranges and vectors to Seconds without re-allocating them
# TODO: There has got to be a better way! github.com/Keno/SIUnits.jl/issues/25
inseconds{T<:Real}(time::Range{T})  = SIUnits.SIRange{typeof(time),T,0,0,1,0,0,0,0,0,0}(time)
inseconds{T<:Real}(time::Vector{T}) = convert(Vector{SecondT{T}}, time)
inseconds{T<:Real}(time::Vector{SIUnits.SIQuantity{T}}) = convert(Vector{SecondT{T}}, time)
inseconds{T<:SecondT}(time::AbstractVector{T}) = time
inseconds{R,T}(time::SIUnits.SIRange{R,T,0,0,1,0,0,0,0,0,0}) = time
inseconds(time::AbstractVector) = throw(ArgumentError("unsupported time vector type"))

# Ensure the data is at least a matrix
atleastmatrix(d::AbstractVector) = reshape(d, (length(d), 1))
atleastmatrix(d::AbstractArray) = d
atleastmatrix(d) = throw(ArgumentError("unsupported data array type"))

# Convert to a RegularSignal by blindly shifting time underneath the data
# TODO: perhaps I should check the variance of diff(time(sig))?
regularize(sig::RegularSignal) = sig
regularize(sig::Signal) = Signal(inseconds(linrange(float(sig.time[1]),float(sig.time[end]),length(sig.time))), sig.data, sig.dims, sig.meta)

# Test if a signal is "regular" -- that is, is it sampled at an exact interval?
isregular(::Signal) = false
isregular(::RegularSignal) = true

## Index and iterate over the first dimension of the data
Base.size(sig::Signal) = size(sig.data)[2:end]
Base.size(sig::Signal, I::Int) = size(sig.data, I+1)
Base.elsize(sig::Signal) = size(sig.time)
# TODO: Perhaps allow custom names/indexes like DataFrames?
Base.getindex(sig::AbstractSignal, idxs::Union(Colon,Int,Array{Int,1},Range{Int})...) = sub(sig, idxs...)

# TODO: We need to propogate dimension names, maybe metadata, too?
Base.sub(sig::AbstractSignal, idx::Int) = sub(sig.data, :, idx)
Base.sub(sig::AbstractSignal, idxs::Int...) = sub(sig.data, :, idxs...)
Base.sub(sig::AbstractSignal, idxs::Union(Colon,Int,Array{Int,1},Range{Int})...) = Signal(sig.time, sub(sig.data, :, idxs...))

# Use linear indexing for iteration
Base.start(::Signal) = 1
Base.next(sig::Signal, i) = (sig[i], i+1)
Base.done(sig::Signal, i) = i > prod(size(sig))

# Information specific to regular signals:
# Hack to get around poor typing in SIUnits math. I know that these are s⁻¹ & s.
# TODO: should I give up trying to store time as an SI array? It can be a pain.
samplingfreq(sig::RegularSignal) = (v = float(1/step(sig.time)); SIUnits.SIQuantity{typeof(v),0,0,-1,0,0,0,0,0,0}(v))
samplingrate(sig::RegularSignal) = (v = float(step(sig.time));   SIUnits.SIQuantity{typeof(v),0,0,1,0,0,0,0,0,0}(v))
