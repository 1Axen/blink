local RunService = game:GetService("RunService")
if not RunService:IsRunning() then
	print("Press F5 to start the benchmark.")
	while task.wait(9e9) do
	end
end

local Result: StringValue
while Result == nil do
	Result = game:FindFirstChild("Result")
	task.wait(1)
end

print("--RESULTS JSON--")
print(Result.Value)
