
Base.summary(sig::Signal) = "$(typeof(sig).name) with $(length(sig)) channel$(length(sig)==1?"":"s") over t=$(sig.time[1]) to $(sig.time[end])"

# Show the sampling rate if we know it
function Base.summary(sig::RegularSignal)
    string(invoke(summary, (Signal,), sig), ", at $(round(1/step(sig.time),1)) Hz")
end

function Base.writemime{T,S}(io::IO, m::MIME"text/plain", sig::Signal{T,S})
    print(io, summary(sig))
    length(sig) == 0 && return
    println(io, ":")
    print(io, "  Each channel has $(length(sig.time)) datapoints")
    if ishomogeneous(sig)
        print(io, " of type $(eltype(S))")
    else
        println(io, " of types: $(tuple([eltype(c) for c in sig]...))") # dirty hack to display them
    end

    show_signal(io, sig)
end

# Channels of nested Signals. Display this nicely with a Sparkline
function show_signal{T<:AbstractVector,S<:Signal}(io::IO, sig::Signal{T, S}, limit_output::Bool=true)
    length(sig) > 1 && return # TODO: display multiple signals?
    
    # Determine screen size
    rows, cols = limit_output ? Base.tty_size() : (typemax(Int), typemax(Int))
    rows = min(rows-5, length(sig.time))

    # Gather the times
    ts = Array(ByteString, rows)
    for i=1:min(length(ts), rows)
        ts[i] = string(sig.time[i], ": ")
    end
    twidth = maximum([strwidth(t) for t in ts]) + 2

    # And display the signal for each time
    sig = sig[1]
    for i=1:length(ts)
        println(io)
        print(io, lpad(ts[i], twidth))
        if length(sig[i]) > cols - twidth
            spark(io, view(sig[i], 1:(cols - twidth - 2)))
            print(io, " …")
        else
            spark(io, sig[i])
        end
    end

    # And display a continuation mark if we have more data
    if rows < length(sig.time)
        println(io)
        print(io, "  ⋮", lpad(": ", twidth-3), "⋮")
    end
end

function show_signal(io::IO, sig::Signal, limit_output::Bool=true)
    # TODO: How should generic signals of many channels display?
end
