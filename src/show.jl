
pluralize(io, n) = n == 1 ? print(io, n) : print(io, n, "s")

function Base.summary{T,S,N}(sig::AbstractSignal{T,S,N})
    b = IOBuffer()
    N == 1 && print(b, length(sig), "-", sig.dims[1] == symbol("") ? "element" : sig.dims[1])
    N > 1 && print(b, join(size(sig), "x"))

    print(b, " ", typeof(sig).name)
    N > 1 && sig.dims[1] != symbol("") && (print(b, " with "); pluralize(b, size(sig, 1)); print(b, " ", sig.dims[1]))
    N > 2 && sig.dims[2] != symbol("") && (print(b, " across "); pluralize(b, size(sig, 2)); print(b, " ", sig.dims[2]))
    # N > 3 && ... # TODO: how do I show other dimension names? Do I at all?
    takebuf_string(b)
end

function Base.writemime(io::IO, m::MIME"text/plain", sig::Signal)
    print(io, summary(sig))
    length(sig) == 0 && return
    println(io, ":")
    print(io, "  Each ", !isempty(sig.dims) && sig.dims[1] != symbol("") ? sig.dims[1] : "element", 
              " has ", length(sig.time), " datapoints from ", sig.time[1], " to ", sig.time[end])
    isa(sig, RegularSignal) && print(io, ", at ", samplingfreq(sig))
    
    show_signal(io, sig)
end

# If the signal contains nested signals display them nicely with sparklines
# I'm not sure I like this since it displays the shape of the data transposed
function show_signal{T,S<:Signal}(io::IO, sig::Signal{T, S}, limit_output::Bool=true)
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
    s = sig[1]
    for i=1:length(ts)
        println(io)
        print(io, lpad(ts[i], twidth))
        if length(s[i]) > cols - twidth
            spark(io, s[i][1:(cols - twidth - 2)])
            print(io, " …")
        else
            spark(io, s[i])
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
    println(io)
    Base.showarray(io, sig.data; header=false)
end
