local Benches = {}
for Index, Bench in script:GetChildren() do
    --> Reset random seed to a constant value
    --> This results in the same values being generated on both server and client
    math.randomseed(0)
    Benches[Bench.Name] = require(Bench)
end
return Benches
