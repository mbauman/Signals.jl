# Interpolation between different time bases

import Grid
import ArrayViews: ArrayView

# Hacks to get arrays of unitful quantities to behave. This is a pain.
datatype{T<:SIUnits.SIQuantity}(::Type{T}) = T.parameters[1]
function stripunits{T<:SIUnits.SIQuantity}(x::Array{T})
    ptr = reinterpret(Ptr{datatype(T)},pointer(x))
    out = pointer_to_array(ptr,length(x))
    reshape(out, size(x))
end
stripunits(x::Union(SIUnits.SIQuantity, SIUnits.SIRanges)) = x.val

# Can't parameterize RegularSignal due to typealias issues (#7453: #2552, #6721)
function Grid.interp{N,T<:Range,S}(sig::Signal{N,T,S}, ti::AbstractVector)
    vi = S<:ArrayView ? Array(Array{eltype(S),1},N) : Array(S,N)
    # Using a Regular Grid is a little awkward, but more performant; it assumes the original basis is 1:N
    t = sig.time
    # So convert ti to "indices" relative to sig.time
    # TODO: This is a terrible hack. SIUnits thinks t/step(t) is still in seconds. https://github.com/Keno/SIUnits.jl/issues/27
    tidxs = Array(Float64, length(ti))
    for i=1:length(ti) tidxs[i] = (ti[i] - t[1])/step(t) + 1; end

    for (i,chan) in enumerate(sig)
        gi = Grid.InterpGrid(chan, Grid.BCnan, Grid.InterpLinear)
        vi[i] = gi[tidxs]
    end
    Signal(ti, vi)
end

function Grid.interp{N,T,S}(sig::Signal{N,T,S}, ti::AbstractVector)
    vi = S<:ArrayView ? Array(Array{eltype(S),1},N) : Array(S,N)
    t = sig.time
    for (i,chan) in enumerate(sig)
        gi = Grid.InterpIrregular(stripunits(t), chan, Grid.BCnan, Grid.InterpLinear)
        vi[i] = gi[stripunits(ti)]
    end
    Signal(ti, vi)
end
