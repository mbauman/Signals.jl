module Signals

import Base: elsize
import ArrayViews: view
import Sparklines: spark

export Signal,
       RegularSignal,
       regularize,
       isregular,
       ishomogeneous,
       channeltypes

include("signal.jl")

end # module
