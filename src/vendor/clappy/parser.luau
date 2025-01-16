type ElementKind = "assignment" | "longIndicator" | "shortIndicator" | "identifier" | "value"
type CharacterClass = "indicator" | "assignment" | "regular" | "whitespace" | "string"

type StackElement = {
	kind: ElementKind,
	value: string,
}

type KeyValueNode = {
	key: string,
	value: string,
}

local function newNode(): KeyValueNode
	return {
		key = "",
		value = "",
	}
end

local function newElement(kind: ElementKind): StackElement
	return {
		kind = kind,
		value = "",
	}
end

local function fetchTop<T>(stack: { T }): T
	return stack[#stack]
end

local function decideCharacterClass(char: string): CharacterClass
	if char == "-" then
		return "indicator"
	end
	if char == "=" then
		return "assignment"
	end
	if char == " " then
		return "whitespace"
	end
	if char == "'" or char == '"' then
		return "string"
	end

	return "regular"
end

local function lexer(input: string): { StackElement }
	local charArray = string.split(input, "")
	local completedStack: { StackElement } = {}
	local workingElement: StackElement? = nil

	local index = 1
	local inString = false
	local stringDelimiter = ""
	while index <= #charArray do
		local char = charArray[index]
		local charClass: CharacterClass = decideCharacterClass(char)

		if inString then
			assert(workingElement, "Luau")

			if charClass == "string" and stringDelimiter == char then
				inString = false

				table.insert(completedStack, workingElement)
				workingElement = nil
				index += 1
				continue
			else
				workingElement.value ..= char
				index += 1
				continue
			end
		end

		if not workingElement then
			if charClass == "regular" then
				local identifierElement = newElement("identifier")
				identifierElement.value ..= char

				workingElement = identifierElement

				index += 1
				continue
			elseif charClass == "indicator" then
				if charArray[index + 1] == nil then
					return error("Unexpected end after operator")
				end

				local isNextCharacterIndicator = decideCharacterClass(charArray[index + 1]) == "indicator"

				table.insert(
					completedStack,
					newElement(if isNextCharacterIndicator then "longIndicator" else "shortIndicator")
				)

				index += if isNextCharacterIndicator then 2 else 1
				continue
			elseif charClass == "string" then
				local stringElement = newElement("value")

				stringDelimiter = char
				inString = true
				workingElement = stringElement

				index += 1
				continue
			elseif charClass == "assignment" then
				local lastElement = fetchTop(completedStack)

				if
					lastElement.kind == "value"
					or lastElement.kind == "shortIndicator"
					or lastElement.kind == "longIndicator"
				then
					return error("Expected identifer before assignment, got " .. lastElement.kind)
				end

				index += 1
				continue
			elseif charClass == "whitespace" then
				index += 1
				continue
			end
		end

		if workingElement then
			if charClass == "regular" then
				workingElement.value ..= char
			elseif charClass == "whitespace" then
				table.insert(completedStack, workingElement)
				workingElement = nil
			elseif charClass == "assignment" then
				if
					workingElement.kind == "value"
					or workingElement.kind == "shortIndicator"
					or workingElement.kind == "longIndicator"
				then
					return error("Expected identifer before assignment, got " .. workingElement.kind)
				end

				table.insert(completedStack, workingElement)
				table.insert(completedStack, newElement("assignment"))
				workingElement = newElement("value")
			end
		end

		index += 1
	end

	if workingElement then
		table.insert(completedStack, workingElement)
	end

	return completedStack
end

local function parser(elements: { StackElement }): { arguments: { string }, options: { [string]: any } }
	local arguments = {}
	local options = {}
	local workingNode: KeyValueNode? = nil

	local index = 1
	while index <= #elements do
		local currentElement = elements[index]

		if not workingNode then
			if currentElement.kind == "assignment" then
				return error("Unexpected assignment")
			elseif currentElement.kind == "value" or currentElement.kind == "identifier" then
				table.insert(arguments, currentElement.value)
			elseif currentElement.kind == "longIndicator" or currentElement.kind == "shortIndicator" then
				workingNode = newNode()
			end
		end

		if workingNode then
			if currentElement.kind == "identifier" then
				workingNode.key = currentElement.value

				if not elements[index + 1] or (elements[index + 1] and elements[index + 1].kind == "identifier") then
					options[workingNode.key] = "true"
					workingNode = nil
				end
			end

			if currentElement.kind == "value" then
				workingNode.value = currentElement.value
				options[workingNode.key] = workingNode.value
				workingNode = nil
			end
		end

		index += 1
	end

	return {
		arguments = arguments,
		options = options,
	}
end

return function(input: string)
	return parser(lexer(input))
end