# Interpolation between different time bases

import Grid
import ArrayViews: ArrayView

# Can't parameterize RegularSignal due to typealias issues (#7453: #2552, #6721)
function Grid.interp{T<:Range,S<:SecondT}(sig::Signal{T}, ti::AbstractVector{S})
    # Using a Regular Grid is a little awkward, but more performant; it assumes the original basis is 1:length(sig)
    t = sig.time
    # So convert ti to "indices" relative to sig.time
    # TODO: SIUnits thinks that the vectorized (ti-t[1])/step(t) is in seconds. https://github.com/Keno/SIUnits.jl/issues/27
    tidxs = Array(Float64, length(ti))
    for i=1:length(ti) tidxs[i] = (ti[i] - t[1])/step(t) + 1; end

    vi = [Grid.InterpGrid(float(c), Grid.BCnan, Grid.InterpLinear)[tidxs] for c in sig]
    Signal(ti, vi)
end

function Grid.interp{T,S<:SecondT}(sig::Signal{T}, ti::AbstractVector{S})
    vi = [Grid.InterpIrregular(sig.time, float(c), Grid.BCnan, Grid.InterpLinear)[ti] for c in sig]
    Signal(ti, vi)
end
