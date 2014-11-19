import SIUnits
typealias SecondT{T} SIUnits.SIQuantity{T,0,0,1,0,0,0,0}

# A signal has a common timebase (an abstract vector of type T) in seconds, 
# and a number of channels that it iterates over (each of type S).
abstract Signal{T<:AbstractVector, S<:AbstractVector} <: AbstractVector{S}
# An evenly sampled signal. Allows for optimizations and saves storage space
abstract RegularSignal{T<:Range, S} <: Signal{T, S}

# The VectorSignal and RegularVectorSignal are the simplest concrete Signals
# with their channels simply placed in a Vector
type VectorSignal{T, S} <: Signal{T, S}
    time::T
    channels::Vector{S}

    VectorSignal(t,c) = (_checkargs(t,c); new(t,c))
end
type RegularVectorSignal{T, S} <: RegularSignal{T, S}
    time::T
    channels::Vector{S}

    RegularVectorSignal(t,c) = (_checkargs(t,c); new(t,c))
end
typealias AnyVectorSignal{T,S} Union(VectorSignal{T,S}, RegularVectorSignal{T,S})

function _checkargs(t, v::Vector)
    ( (isa(t, Range) && step(t) > 0s) || issorted(t,lt=(<=)) ) || throw(ArgumentError("time vector must be monotonically increasing"))
    for c in v
        length(t) != length(c) && throw(ArgumentError("each channel must be the same length as time"))
    end
    eltype(t) <: SecondT || throw(ArgumentError("time must be specified in seconds"))
end
# The canonical constructor for both VectorSignals and RegularVectorSignals
VectorSignal{T<:SecondT, S<:AbstractVector}(time::Range{T}, channels::Vector{S}) =
    RegularVectorSignal{typeof(time), S}(time, channels) # TODO: is this ok? The VectorSignal constructor can return a type that's not VectorSignal!
VectorSignal{T<:SecondT, S<:AbstractVector}(time::AbstractVector{T}, channels::Vector{S}) =
    VectorSignal{typeof(time), S}(time, channels)

# The lowercase s-signal is more forgiving than the strictly-typed constructors.
# It will automatically convert time vectors into seconds (is this a good idea?)
# and since inference can get messy with vectors of vectors (especially at the
# REPL prompt) it takes a varargs list or tuple of the channel vectors.
signal(time::AbstractVector, channels::(AbstractVector...)) = VectorSignal(inseconds(time), [c for c in channels])
signal(time::AbstractVector, channels...) = signal(time, channels)
signal(time::AbstractVector, ::()) = VectorSignal(inseconds(time), Array{None,1}[])
# For simple testing, allow vectorized functions
signal(time::AbstractVector, fcns::(Function...)) = signal(time, map(f->f(time), fcns))

# Convert the time ranges and vectors to Seconds. 
# TODO: There has got to be a better way! github.com/Keno/SIUnits.jl/issues/25
inseconds{T<:Real}(time::Range{T})  = SIUnits.SIRange{typeof(time),T,0,0,1,0,0,0,0}(time)
inseconds{T<:Real}(time::Vector{T}) = convert(Vector{SecondT{T}}, time)
inseconds{T<:Real}(time::Vector{SIUnits.SIQuantity{T}}) = convert(Vector{SecondT{T}}, time)
inseconds{T<:SecondT}(time::AbstractVector{T}) = time
inseconds(time::AbstractVector) = throw(ArgumentError("unsupported time vector type"))

### These methods must be defined for all subtypes of Signal ###
time(sig::AnyVectorSignal)      = sig.time
time(sig::AnyVectorSignal, idx) = sig.time[idx]
channels(sig::AnyVectorSignal)      = sig.channels
channels(sig::AnyVectorSignal, idx) = sig.channels[idx]
# TODO: Perhaps allow custom names/indexes like DataFrames?
Base.getindex(sig::AnyVectorSignal, idx::Real=1)         = sig.channels[idx]
Base.getindex(sig::AnyVectorSignal, idx::AbstractVector) = VectorSignal(sig.time, sig.channels[idx])
###

# Basic view support; other Signal subtypes can specialize if it makes sense
view(sig::Signal, idx::Real=1)         = sig[idx]
view(sig::Signal, idx::AbstractVector) = sig[idx]

# Convert to a RegularSignal by blindly shifting time underneath the channels
# TODO: perhaps I should check the variance of diff(time(sig))?
regularize(sig::RegularSignal) = sig
regularize{T<:Range}(sig::Signal{T}) = VectorSignal(time(sig), channels(sig))
regularize(sig::Signal) = VectorSignal(inseconds(linrange(float(time(sig)[1]),float(time(sig)[end]),length(time(sig)))), channels(sig))

# Test if a signal is "regular" -- that is, is it sampled at an exact interval?
isregular(::Signal) = false
isregular(::RegularSignal) = true

# Test if the channels are all of the same type
ishomogeneous{T,S}(::Signal{T,S}) = isleaftype(S) || S === None
# Return an array of the type of each channel
channeltypes(sig::Signal) = Type[typeof(c) for c in sig]

## Index and iterate over the channels of the signal
Base.length(sig::Signal) = length(channels(sig))
Base.size(sig::Signal) = (length(sig),)
Base.size(sig::Signal, I::Int) = I==1 ? length(sig) : I>1 ? 1 : throw(BoundsError())
Base.ndims(::Signal) = 1
Base.elsize(sig::Signal) = (length(time(sig)),)
Base.eltype{T,S}(::Signal{T,S}) = S

# Iteration
Base.start(::Signal) = 1
Base.next(sig::Signal, i) = (channels(sig, i), i+1)
Base.done(sig::Signal, i) = (i > length(sig))
Base.isempty(sig::Signal) = (length(sig) == 0)

# Information specific to regular signals:
# Hack to get around poor typing in SIUnits math. I know that this is s⁻¹.
# TODO: should I give up trying to store time as an SI array? It can be a pain.
samplingfreq(sig::RegularSignal) = (v = float(1/step(time(sig))); SIUnits.SIQuantity{typeof(v),0,0,-1,0,0,0,0}(v))
samplingrate(sig::RegularSignal) = (v = float(step(time(sig)));   SIUnits.SIQuantity{typeof(v),0,0,1,0,0,0,0}(v))
