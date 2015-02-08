# Unlike normal Signals, RaggedSignals do *not* have a common timebase;
# their timebase may vary from vector to vector. They are predominantly here to
# support windowed repetitions of irregular signals (e.g., spike rasters).
type RaggedSignal{T, S, N, M, D} <: AbstractSignal{T, S, N}
    time::Array{T, M}
    data::D

    dims::NTuple{N, Symbol}

    meta::Dict{Symbol, Any}
    RaggedSignal(t,d,n,m) = new(t,d,n,m)
end
