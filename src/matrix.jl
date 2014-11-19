import ArrayViews: ContiguousView

type MatrixSignal{T, S} <: Signal{T, ContiguousView{S,1,Matrix{S}}}
    time::T
    channels::Matrix{S}
    
    MatrixSignal(t,c) = (_checkargs(t,c); new(t,c))
end
type RegularMatrixSignal{T, S} <: RegularSignal{T, ContiguousView{S,1,Matrix{S}}}
    time::T
    channels::Matrix{S}
    
    RegularMatrixSignal(t,c) = (_checkargs(t,c); new(t,c))
end
typealias AnyMatrixSignal{T,S} Union(MatrixSignal{T,S}, RegularMatrixSignal{T,S})

function _checkargs(t, m::Matrix)
    ( (isa(t, Range) && step(t) > 0s) || issorted(t,lt=(<=)) ) || throw(ArgumentError("time vector must be monotonically increasing"))
    length(t) != size(m, 1) && throw(ArgumentError("the data matrix must have the same number of rows as the length of time"))
    eltype(t) <: SecondT || throw(ArgumentError("time must be specified in seconds"))
end
# The canonical constructor for both MatrixSignals and RegularMatrixSignals
MatrixSignal{T<:SecondT, S}(time::Range{T}, data::Matrix{S}) = 
    RegularMatrixSignal{typeof(time), S}(time, data)
MatrixSignal{T<:SecondT, S}(time::AbstractVector{T}, data::Matrix{S}) = 
    MatrixSignal{typeof(time), S}(time, data)

# Matrices are assumed to be grouped signals. If you want multiple datapoints
# per timepoint within one channel (which is uncommon), use a vector of vectors.
signal(time::AbstractVector, data::Matrix) = MatrixSignal(inseconds(time), data)

### These methods must be defined for all subtypes of Signal ###
time(sig::AnyMatrixSignal)      = sig.time
time(sig::AnyMatrixSignal, idx) = sig.time[idx]
channels(sig::AnyMatrixSignal)      = [view(sig.channels, :, i) for i in 1:length(sig.channels)]
channels(sig::AnyMatrixSignal, idx::Real) = view(sig.channels, :, idx)
channels(sig::AnyMatrixSignal, idx) = [view(sig.channels, :, i) for i in idx]
# TODO: Perhaps allow custom names/indexes like DataFrames?
Base.getindex(sig::AnyMatrixSignal, idx::Real=1)         = 1 <= idx <= length(sig) ? view(sig.channels, :, idx) : throw(BoundsError())
Base.getindex(sig::AnyMatrixSignal, idx::AbstractVector) = all(1 .<= idx .<= length(sig)) ? VectorSignal(sig.time, [view(sig.channels, :, i) for i in idx]) : throw(BoundsError())
###

# Convert to a RegularSignal by blindly shifting time underneath the channels
# TODO: perhaps I should check the variance of diff(time(sig))?
regularize{T<:Range}(sig::AnyMatrixSignal{T}) = MatrixSignal(sig.time, sig.channels)
regularize(sig::AnyMatrixSignal) = MatrixSignal(linrange(float(time(sig)[1]),float(time(sig)[end]),length(time(sig))), sig.channels)

## Index and iterate over the channels of the signal
Base.length(sig::AnyMatrixSignal) = size(sig.channels, 2)
