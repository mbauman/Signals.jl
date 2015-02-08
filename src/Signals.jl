module Signals

import Sparklines: spark

# Functions from packages that Signals extends and re-exports
import Grid: interp # TODO: move to Interpolations.jl
export interp

import SIUnits: Second, ShortUnits.s, ShortUnits.ms, ShortUnits.µs
const μs = µs # \mu != \micro. https://github.com/Keno/SIUnits.jl/issues/23
export Second, s, ms, µs, μs

export Signal,
       RegularSignal,
       SignalVector,
       SignalMatrix,
       regularize,
       isregular,
       samplingfreq,
       samplingrate,
       before,
       after,
       within,
       window

include("signal.jl")
include("show.jl")
include("interpolation.jl")
include("time.jl")

end # module
