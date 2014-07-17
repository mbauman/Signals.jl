# Test windowing.

## Regular Signals:
for loc in ([20,30,40], [2s,3s,4s]), win in ((-1s,1s), (-10,10), (-1.04s, 1.04s))
    t = 0.1s:0.1s:10.0s
    sig = signal(t, collect(1:100))
    reps = window(sig, loc, win)
    @test reps.time == [2.0s,3.0s,4.0s]
    @test reps[1].time == -1s:0.1s:1s
    @test length(reps) == 1
    @test length(reps[1]) == 3
    @test reps[1][1] == collect(10:30)
    @test reps[1][2] == collect(20:40)
    @test reps[1][3] == collect(30:50)
end

## Irregular signals are tougher to test the edge-cases (with 4 different cases)
# Start with basic behavior like Regular Signals
for loc in ([20,30,40], [2s,3s,4s]), win in ((-1s,1s), (-10,10), (-1.04s, 1.04s))
    t = collect(0.1s:0.1s:10.0s)
    sig = signal(t, collect(1:100))
    reps = window(sig, loc, win)
    @test reps.time == [2.0s,3.0s,4.0s]
    @test length(reps) == 1
    @test length(reps[1]) == 3
    # Unlike regular signals, reps[1] is an array, not a Signal.
    @test reps[1][1].time == t[10:30] - t[20]
    @test reps[1][2].time == t[20:40] - t[30]
    @test reps[1][3].time == t[30:50] - t[40]
    @test reps[1][1][1] == collect(10:30)
    @test reps[1][2][1] == collect(20:40)
    @test reps[1][3][1] == collect(30:50)
end
