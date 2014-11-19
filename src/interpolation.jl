# Interpolation between different time bases

import Grid
import ArrayViews: ArrayView

function Grid.interp{S<:SecondT}(sig::RegularSignal, ti::AbstractVector{S})
    # Using a Regular Grid is a little awkward, but more performant; it assumes the original basis is 1:length(sig)
    t = time(sig)
    # So convert ti to "indices" relative to the signal's time
    tidxs = Array(Float64, length(ti))
    for i=1:length(ti) tidxs[i] = (ti[i] - t[1])/step(t) + 1; end

    vi = [Grid.InterpGrid(c, Grid.BCnan, Grid.InterpLinear)[tidxs] for c in sig]
    VectorSignal(ti, vi)
end

function Grid.interp{S<:SecondT}(sig::Signal, ti::AbstractVector{S})
    vi = [Grid.InterpIrregular(time(sig), c, Grid.BCnan, Grid.InterpLinear)[ti] for c in sig]
    VectorSignal(ti, vi)
end
