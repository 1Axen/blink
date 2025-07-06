-- From dphfox/tiniest, licenced under BSD
--!strict

local tiniest = require("./tiniest")
type Test = tiniest.Test

export type TestRunResult = tiniest.TestRunResult
export type RunResult = tiniest.RunResult

export type Options = {
	disable_annotations: boolean?
}

local tiniest_github_actions = {}

local function extract_filename(source: string)
	return string.sub(source, 10, #source - 2)
end

function tiniest_github_actions.configure(
	options: Options
)
	
	local self = {}
	self.is_tiniest_plugin = true

	function self.after_run(
		original_run_result: tiniest.RunResult,
		_
	): ()
        if options.disable_annotations then
            return
        end

		local run_result = original_run_result :: RunResult
		for test, result in run_result.individual do
            if result.status == "pass" then
                continue
            end

			local err = result.error
			local file = extract_filename(err.source)
			local title = table.concat(test.labels, " > ")

			local message = err.message
			if err.code then
				message = `{message}\n  {err.code.snippet}`
			end
			
			-- need to URL encode new lines for them to show up
			message = string.gsub(message, "\n", "%%0A")
			print(`::error file={file},line={err.line},title={title}::{message}`)
		end
	end

	return self
end

return tiniest_github_actions