# Interpolation between different time bases

import Grid

function Grid.interp{S<:SecondT}(sig::RegularSignal, ti::AbstractVector{S})
    # Using a Regular Grid is a little awkward, but more performant; it assumes the original basis is 1:length(sig)
    t = sig.time
    # So convert ti to "indices" relative to the signal's time
    tidxs = Array(Float64, length(ti))
    for i=1:length(ti) tidxs[i] = (ti[i] - t[1])/step(t) + 1; end

    g = Grid.InterpGrid(sig.data, Grid.BCnan, Grid.InterpLinear)
    vi = [g[tidx, chan] for tidx in tidxs, chan=1:length(sig)]
    reshape(vi, tuple(length(ti), size(sig)...))
    Signal(ti, vi, sig.dims, sig.meta)
end

function Grid.interp{S<:SecondT}(sig::Signal, ti::AbstractVector{S})
    # Grid doesn't support multidimensional irregular interpolation, so work
    # around it for now
    gs = [Grid.InterpIrregular(sig.time, sig.data[:,chan], Grid.BCnan, Grid.InterpLinear) for chan=1:length(sig)]
    vi = eltype(sig.data)[g[t] for t in ti, g in gs]
    reshape(vi, tuple(length(ti), size(sig)...))
    Signal(ti, vi, sig.dims, sig.meta)
end
