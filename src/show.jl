
Base.summary{N}(s::Signal{N}) = "$(typeof(s).name) with $N channel$(N==1?"":"s") over t=$(s.time[1]) to $(s.time[end])"

# Show the sampling rate if we know it
function Base.summary(s::RegularSignal)
    string(invoke(summary, (Signal,), s), ", at $(round(1/step(s.time),1)) Hz")
end

function Base.writemime{N,T,S}(io::IO, m::MIME"text/plain", s::Signal{N,T,S})
    print(io, summary(s))
    N == 0 && return
    println(io, ":")
    print(io, "  Each channel has $(length(s.time)) datapoints")
    if ishomogeneous(s)
        print(io, " of type $S")
    else
        println(io, " with types:")
        writemime(io, m, [typeof(c) for c in s]') # dirty hack to display them
    end

    show_signal(io, s)
end

# Only one channel of nested Signals. Display this nicely with a Sparkline
function show_signal{T<:AbstractVector,S<:Signal}(io::IO, s::Signal{1, T, S}, limit_output::Bool=true)
    # Determine screen size
    rows, cols = limit_output ? Base.tty_size() : (typemax(Int), typemax(Int))
    rows = min(rows-5, length(s.time))

    # Gather the times
    ts = Array(ByteString, rows)
    for i=1:min(length(ts), rows)
        ts[i] = string(s.time[i], ": ")
    end
    twidth = maximum([strwidth(t) for t in ts]) + 2

    # And display the signal for each time
    sig = s[1]
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
    if rows < length(s.time)
        println(io)
        print(io, "  ⋮", lpad(": ", twidth-3), "⋮")
    end
end

function show_signal(io::IO, s::Signal, limit_output::Bool=true)
    # TODO: How should generic signals of many channels display?
end
