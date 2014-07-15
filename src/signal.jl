# I'm not sure that these would be useful in dispatch
# abstract AbstractSignal{N, T<:AbstractVector, S<:AbstractVector} <: AbstractVector{S}
# What'sig the difference between a discrete and continuous signal? They're all
# discrete. It'sig just when the signal is based on a Range time type that there'sig
# special optimizations we can make.
# abstract DiscreteSignal{N, T, S}   <: AbstractSignal{N, T, S}
# abstract RegularSignal{N, T, S} <: AbstractSignal{N, T, S}

import SIUnits
typealias SecondT{T} SIUnits.SIQuantity{T,0,0,1,0,0,0,0}

# A signal has a common timebase (a vector of type T) in seconds, 
# and a vector of N channels (a number of vectors of type S).
type Signal{N, T<:AbstractVector, S<:AbstractVector} <: AbstractVector{S}
    time::T
    channels::Vector{S}
end

# The canonical parametric constructor, with error checking
function Signal{T<:SecondT, S<:AbstractVector}(time::AbstractVector{T}, channels::Vector{S})
    issorted(time,lt=(<=)) || throw(ArgumentError("time vector must be monotonically increasing"))
    for c in channels
        length(time) != length(c) && throw(ArgumentError("each channel must be the same length as time"))
    end
    @assert(eltype(time) <: SecondT, "time must be specified in seconds")
    Signal{length(channels), typeof(time), S}(time, channels)
end
# Convert the time ranges and vectors to Seconds. 
# TODO: There has got to be a better way! github.com/Keno/SIUnits.jl/issues/25
Signal{T<:Real, S<:AbstractVector}(time::Range{T}, channels::Vector{S})  = Signal(SIUnits.SIRange{T,0,0,1,0,0,0,0}(time), channels)
Signal{T<:Real, S<:AbstractVector}(time::Range1{T}, channels::Vector{S}) = Signal(SIUnits.SIRange1{T,0,0,1,0,0,0,0}(time), channels)
Signal{T<:Real, S<:AbstractVector}(time::Vector{T}, channels::Vector{S}) = Signal(convert(Array{SecondT{T},1}, time), channels)
Signal{T<:Real, S<:AbstractVector}(time::Vector{SIUnits.SIQuantity{T}}, channels::Vector{S}) = Signal(convert(Array{SecondT{T},1}, time), channels)
Signal{T<:Real, S<:AbstractVector}(time::AbstractVector{T}, channels::Vector{S}) = throw(ArgumentError("unsupported time vector type"))

# The more user-friendly APIs
signal(time::AbstractVector, ::()) = Signal(time, [])
signal(time::AbstractVector, channels::(AbstractVector...)) = Signal(time, [c for c in channels])
signal(time::AbstractVector, channels::AbstractVector...) = signal(time, channels)
# Matrices are assumed to be grouped signals. If you want multiple datapoints
# per timepoint within one channel (which is uncommon), use a vector of vectors.
signal(time::AbstractVector, data::AbstractMatrix) = Signal(time, [view(data, :, i) for i in 1:size(data,2)])
# For simple testing, allow vectorized functions
signal(time::AbstractVector, fcns::(Function...)) = signal(time, map(f->f(time), fcns))

# An evenly sampled signal. Allows for optimizations and saves storage space
typealias RegularSignal{N, T<:Range, S<:AbstractVector} Signal{N, T, S}
# Not sure about the naming here. I want to describe an evenly sampled signal,
# with functions to test (is*) and convert/ensure the signal is* (make*?)
# RegularSignal: nice verb (regularize); Grid.jl uses Irregular for the opposite
# ContinuousSignal: has a nice connotation with time, but isn't accurate
# UniformSignal: isuniform sounds nice
# GriddedSignal: aligns with Grid.jl, but strong connotations with 2D data
# LinearSignal: linspace; nice verb, but sounds like the signal itself is linear
# StepSignal? EvenlySampledSignal?

# Convert to a RegularSignal by blindly shifting time underneath the channels
# TODO: perhaps I should check the variance of diff(sig.time)?
regularize(sig::RegularSignal) = sig
regularize(sig::Signal) = Signal(linrange(float(sig.time[1]),float(sig.time[end]),length(sig.time)), sig.channels)
if !isdefined(Base, :linrange)
    # PR 6627: https://github.com/JuliaLang/julia/pull/6627
    linrange(a::Real,b::Real,len::Integer) = len >= 2 ? range(a, (b-a)/(len-1),len) : len == 1 && a == b ? range(a, zero((b-a)/(len-1)), 1) : error("invalid range length")
end
# Test if a signal is "regular" -- that is, it is sampled at an exact interval
isregular(::Signal) = false
isregular(::RegularSignal) = true

# Test if the channels are all of the same type
ishomogeneous{N,T,S}(::Signal{N,T,S}) = isleaftype(S) || S === None
# Return an array of the type of each channel
channeltypes(sig::Signal) = Type[typeof(c) for c in sig]

## Index and iterate over the signal columns of .channels
Base.length{N}(::Signal{N}) = N
Base.size{N}(::Signal{N}) = (N,)
Base.size{N}(::Signal{N}, I::Int) = I==1 ? N : I>1 ? 1 : throw(BoundsError())
Base.ndims(::Signal) = 1
Base.elsize(sig::Signal) = (length(sig.time),)
Base.eltype{N,T,S}(::Signal{N,T,S}) = S

# TODO: Perhaps allow custom names/indexes like DataFrames?
Base.getindex(sig::Signal, idx::Real=1) = sig.channels[idx]
Base.getindex(sig::Signal, idx::Range)  = sig.channels[idx]
view(sig::Signal, idx::Real=1) = view(sig.channels, idx)
view(sig::Signal, idx::Range)  = view(sig.channels, idx)

# Iteration
Base.start(::Signal) = 1
Base.next(sig::Signal, i) = (sig.channels[i], i+1)
Base.done{N}(sig::Signal{N}, i) = (i > N)
Base.isempty{N}(sig::Signal{N}) = (N == 0)

# Information about regular signals:
fs(sig::RegularSignal) = 1/step(sig.time)
rate(sig::RegularSignal) = step(sig.time)
