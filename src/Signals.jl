module Signals

import Sparklines: spark

# Functions from packages that Signals extends
import ArrayViews: view
import Grid: interp # This is a little shady to extend

# Things from other packages to re-export.
# Seconds are a great way to differentiate indices from time.
import SIUnits: Second, ShortUnits.s, ShortUnits.ms, ShortUnits.µs
const μs = µs # \mu != \micro. https://github.com/Keno/SIUnits.jl/issues/23
export Second, s, ms, µs, μs

export Signal,
       signal,
       RegularSignal,
       regularize,
       isregular,
       ishomogeneous,
       channeltypes,
       interp,
       samplingfreq,
       samplingrate,
       before,
       after,
       within,
       window

include("signal.jl")
include("matrix.jl")
include("show.jl")
include("interpolation.jl")
include("time.jl")

end # module
