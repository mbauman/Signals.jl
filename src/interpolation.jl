# Interpolation between different time bases

# Brainstorm: How do I want to do interpolation? I think I want something like
# interp1 / qinterp1. What about Grid.jl? Is that kind of dynamic interpolation
# worth investigating?  I mean, maybe a signal could become:
#      typealias InterpSignal{N, T<:AbstractInterpGrid, S<:AbstractInterpGrid} Signal{N,T,S}
# But perhaps simply returning the result is all we need here.
import Grid
import ArrayViews: ArrayView

# Can't parameterize RegularSignal due to typealias issues (#7453: #2552, #6721)
function Grid.interp{N,T<:Range,S}(s::Signal{N,T,S}, ti::AbstractVector)
    vi = S<:ArrayView ? Array(Array{eltype(S),1},N) : Array(S,N)
    # Using a Regular Grid is a little awkward, but more performant; it assumes the original basis is 1:N
    t = s.time
    # So convert ti to "indices" relative to s.time
    tidxs = (ti-t[1])/step(t) + 1
    for (i,chan) in enumerate(s)
        gi = Grid.InterpGrid(chan, Grid.BCnan, Grid.InterpLinear)
        vi[i] = gi[tidxs]
    end
    Signal(ti, vi)
end

function Grid.interp{N,T,S}(s::Signal{N,T,S}, ti::AbstractVector)
    vi = S<:ArrayView ? Array(Array{eltype(S),1},N) : Array(S,N)
    t = s.time
    for (i,chan) in enumerate(s)
        gi = Grid.InterpIrregular(t, chan, Grid.BCnan, Grid.InterpLinear)
        vi[i] = gi[ti]
    end
    Signal(ti, vi)
end
