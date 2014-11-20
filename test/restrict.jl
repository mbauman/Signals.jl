# test the time restriction methods
t = 0:.25:10
sig = signal(t, [t])
b1 = before(sig, 5.0s)
@test b1.time == 0s:0.25s:5s
@test all(b1[1] .== 0:0.25:5)
a1 = after(sig, 5.0s)
@test a1.time == 5s:.25s:10s
@test all(a1[1] .== 5:.25:10)
w1 = within(sig, 2s, 3s)
@test w1.time == 2s:.25s:3s
@test all(w1[1] .== 2:.25:3)

# Matrix Signal
t = 0:.25:10
sig = signal(t, [t 2t])
b1 = before(sig, 5.0s)
@test b1.time == 0s:0.25s:5s
@test all(b1[1] .== 0:0.25:5)
@test all(b1[2] .== 2*(0:0.25:5))
a1 = after(sig, 5.0s)
@test a1.time == 5s:.25s:10s
@test all(a1[1] .== 5:.25:10)
@test all(a1[2] .== 2*(5:.25:10))
w1 = within(sig, 2s, 3s)
@test w1.time == 2s:.25s:3s
@test all(w1[1] .== 2:.25:3)
@test all(w1[2] .== 2*(2:.25:3))

