# I'm not sure that these would be useful in dispatch
# abstract AbstractSignal{N, T<:AbstractVector, S<:AbstractVector} <: AbstractVector{S}
# What's the difference between a discrete and continuous signal? They're all
# discrete. It's just when the signal is based on a Range time type that there's
# special optimizations we can make.
# abstract DiscreteSignal{N, T, S}   <: AbstractSignal{N, T, S}
# abstract RegularSignal{N, T, S} <: AbstractSignal{N, T, S}

# A signal has a common timebase (a vector of type T), and a vector of N
# channels (a number of vectors of type S).
type Signal{N, T<:AbstractVector, S<:AbstractVector} <: AbstractVector{S}
    time::T
    channels::Vector{S}
end
# The canonical parametric constructor, with error checking
function Signal{T<:AbstractVector, S<:AbstractVector}(time::T, channels::Vector{S})
    issorted(time,lt=(<=)) || throw(ArgumentError("time vector must be monotonically increasing"))
    for c in channels
        length(time) != length(c) && throw(ArgumentError("each channel must be the same length as time"))
    end
    Signal{length(channels), T, S}(time, channels)
end
Signal(time::AbstractVector, channels::AbstractVector...) = Signal(time, [c for c in channels])
# Matrices are assumed to be grouped signals. If you want multiple datapoints
# per timepoint within one channel (which is uncommon), use a vector of vectors.
Signal(time::AbstractVector, data::AbstractMatrix) = Signal(time, [view(data, :, i) for i = 1:size(data,2)])
# For simple testing, allow vectorized functions (splat to improve inference)
Signal(time::AbstractVector, fcns::Vector{Function}) = Signal(time, [f(time) for f in fcns]...)

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

## New and specific functions for Signals
# Test if the channels are all of the same type
ishomogeneous{N,T,S}(::Signal{N,T,S}) = isleaftype(S) || S === None
# Technically all signals are discrete, but consider Range time to be continuous
iscontinuous(::Signal) = false
iscontinuous(::RegularSignal) = true
# Return an array of the type of each channel
channeltypes(s::Signal) = Type[typeof(c) for c in s]

## Index and iterate over the signal columns of .channels
Base.length{N}(::Signal{N}) = N
Base.size{N}(::Signal{N}) = (N,)
Base.size{N}(::Signal{N}, I::Int) = I==1 ? N : I>1 ? 1 : throw(BoundsError())
Base.ndims(::Signal) = 1
Base.elsize(s::Signal) = (length(s.time),)
Base.eltype{N,T,S}(::Signal{N,T,S}) = S

# TODO: Perhaps allow custom names/indexes like DataFrames?
Base.getindex(s::Signal, idx::Real=1) = s.channels[idx]
Base.getindex(s::Signal, idx::Range)  = s.channels[idx]
view(s::Signal, idx::Real=1) = view(s.channels, idx)
view(s::Signal, idx::Range)  = view(s.channels, idx)

# Iteration
Base.start(::Signal) = 1
Base.next(s::Signal, i) = (s.channels[i], i+1)
Base.done{N}(s::Signal{N}, i) = (i > N)
Base.isempty{N}(s::Signal{N}) = (N == 0)

# Mutation? Let's leave it out for now.
# With the typed channel vector, push! probably wouldn't work most of the time.
# Base.push!(s::Signal, chan::AbstractVector...) = push!(s.channels, chan...)
# Base.append!(s::Signal, chans::AbstractVector)  = append!(s.channels, chans)
# Base.prepend!(s::Signal, chans::AbstractVector) = prepend!(s.channels, chans)
# Base.deleteat!(s::Signal, i::Integer) = deleteat!(s.channels, i)
# Base.insert!(s::Signal, i::Integer, item<:AbstractVector) = insert!(s.channels, i, item)

# Show
Base.summary{N}(s::Signal{N}) = "$(typeof(s).name) with $N channel$(N==1?"":"s") over t=$(s.time[1]) to $(s.time[end])"
function Base.summary{N,T<:Range}(s::Signal{N,T}) 
    string(invoke(summary, (Signal{N},), s), ", at $(round(1/step(s.time),1)) Hz")
end
function Base.writemime{N,T,S}(io::IO, ::MIME"text/plain", s::Signal{N,T,S})
    print(io, summary(s))
    N == 0 && return
    println(io, ":")
    print(io, "  Each channel has $(length(s.time)) datapoints of type $S")
    
    if N == 1 && elsize(s[1])[1] > 1 && length(elsize(s[1])) == 1
        # Only one channel, but multiple datapoints per timepoint
        # Gather the times
        sig = s[1]
        rows, cols = int(get(ENV, "ROWS", "24"))-3, min(int(get(ENV, "COLS", "80")), length(s.time))
        ts = Array(ByteString, rows)
        for i=1:length(ts)
            ts[i] = string(s.time[i], ": ")
        end
        twidth = maximum([strwidth(t) for t in ts]) + 2
        # And display the values for each time
        for i=1:length(ts)
            println(io)
            print(io, lpad(ts[i], twidth))
            if length(sig[i]) > cols - twidth
                spark(io, view(sig[i], 1:(cols - twidth - 2), i))
                print(io, " …")
            else
                spark(io, sig[i])
            end
        end
    else
    end
end
