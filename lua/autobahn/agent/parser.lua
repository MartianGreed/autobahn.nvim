local M = {}

local content_blocks = {}
local session_metadata_shown = {}

local function format_timestamp(timestamp)
	if not timestamp then
		return ""
	end
	return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

function M.parse_stream_json(line)
	if not line or line == "" then
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, line)
	if not ok then
		return nil
	end

	return decoded
end

function M.reset_state()
	content_blocks = {}
	session_metadata_shown = {}
end

local function detect_language(text)
	local lower = text:lower()

	if lower:match("%.lua") or lower:match("function%s+%w+") or lower:match("local%s+") then
		return "lua"
	elseif lower:match("%.json") or text:match("^%s*[{%[]") then
		return "json"
	elseif lower:match("%.py") or lower:match("def%s+%w+") or lower:match("import%s+") then
		return "python"
	elseif lower:match("%.js") or lower:match("%.ts") or lower:match("const%s+") or lower:match("function%s*%(") then
		return "javascript"
	elseif lower:match("%.sh") or lower:match("%.bash") or text:match("^%s*#!/bin/") then
		return "bash"
	elseif lower:match("%.rs") or lower:match("fn%s+%w+") then
		return "rust"
	elseif lower:match("%.go") or lower:match("func%s+%w+") then
		return "go"
	end

	return nil
end

local function format_code_blocks(text)
	local result = {}
	local in_code = false
	local code_lines = {}
	local code_lang = nil

	for line in text:gmatch("[^\r\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")

		if trimmed:match("^```") then
			if in_code then
				table.insert(result, "```")
				in_code = false
				code_lines = {}
				code_lang = nil
			else
				in_code = true
				code_lang = trimmed:match("^```(%w+)")
				table.insert(result, line)
			end
		elseif in_code then
			table.insert(result, line)
			if not code_lang then
				table.insert(code_lines, line)
			end
		else
			local looks_like_code = line:match("^%s%s%s%s") or line:match("^    ")

			if looks_like_code and not in_code then
				local code_text = table.concat(code_lines, "\n")
				local lang = detect_language(line) or detect_language(code_text) or ""
				table.insert(result, "```" .. lang)
				for _, cl in ipairs(code_lines) do
					table.insert(result, cl)
				end
				table.insert(result, line)
				in_code = true
			elseif in_code and not looks_like_code then
				table.insert(result, "```")
				in_code = false
				code_lines = {}
				table.insert(result, "" .. line)
			else
				if in_code then
					table.insert(code_lines, line)
				else
					table.insert(result, "" .. line)
				end
			end
		end
	end

	if in_code then
		table.insert(result, "```")
	end

	return result
end

local function is_formatted_markdown(text)
	return text:match("^#+%s")
		or text:match("^%s*[-*+]%s")
		or text:match("^%s*%d+%.%s")
		or text:match("^```")
		or text:match("^>%s")
		or text:match("^|.*|")
		or text:match("^%s*<")
end

local function format_as_blockquote(text)
	local formatted = format_code_blocks(text)

	for i, line in ipairs(formatted) do
		if not line:match("^```") and not line:match("^>") and not is_formatted_markdown(line) then
			formatted[i] = "> " .. line
		end
	end

	return formatted
end

local function create_markdown_table(rows)
	local lines = {}

	for i, row in ipairs(rows) do
		table.insert(lines, string.format("| %s | %s |", row[1], row[2]))
		if i == 1 then
			table.insert(lines, "|---|---|")
		end
	end

	return lines
end

local function create_collapsible_details(title, content)
	local lines = {}
	table.insert(lines, "<details open>")
	table.insert(lines, string.format("<summary>🔧 %s</summary>", title))
	table.insert(lines, "")

	if type(content) == "table" then
		vim.list_extend(lines, content)
	else
		table.insert(lines, content or "")
	end

	table.insert(lines, "</details>")
	table.insert(lines, "")
	return lines
end

function M.format_session_header(session)
	local lines = {}
	table.insert(lines, "# Autobahn Agent Session")
	table.insert(lines, "")

	local vcs_type = "git"
	if session.workspace_path and session.workspace_path:match("jj") then
		vcs_type = "jujutsu"
	end

	local table_rows = {
		{ "Property", "Value" },
		{ "Session ID", session.id or "unknown" },
		{ "Agent", session.agent_type or "claude-code" },
		{ "Branch", session.branch or "N/A" },
		{ "VCS", vcs_type },
		{ "Workspace", session.workspace_path or "N/A" },
		{ "Created", format_timestamp(session.created_at) },
	}

	vim.list_extend(lines, create_markdown_table(table_rows))
	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "")

	return lines
end

function M.format_user_message(message, timestamp)
	local lines = {}
	table.insert(lines, "")
	table.insert(lines, "")
	if timestamp then
		table.insert(lines, string.format("**User** [%s]", format_timestamp(timestamp)))
	else
		table.insert(lines, "**User**")
	end

	for line in message:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	table.insert(lines, "")
	table.insert(lines, "")
	return lines
end

function M.format_thinking_placeholder()
	return { "thinking..." }
end

function M.format_question(question_data)
	if not question_data or not question_data.questions then
		return nil
	end

	local lines = {}
	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "")
	table.insert(lines, "❓ **Agent Question**")
	table.insert(lines, "")

	for idx, question in ipairs(question_data.questions) do
		table.insert(lines, string.format("**Q%d**: %s", idx, question.question))
		table.insert(lines, "")
		if question.options then
			table.insert(lines, "**Options:**")
			for i, option in ipairs(question.options) do
				table.insert(lines, string.format("%d. **%s** - %s", i, option.label, option.description or ""))
			end
		end
		table.insert(lines, "")
		table.insert(lines, "> Press `<CR>` on this line to answer")
		table.insert(lines, "")
	end

	table.insert(lines, "---")
	table.insert(lines, "")

	return lines
end

function M.extract_question_data(data)
	if not data or data.type ~= "assistant" then
		return nil
	end

	if data.message and data.message.content then
		for _, content in ipairs(data.message.content) do
			if content.type == "tool_use" and content.name == "AskUserQuestion" and content.input then
				return {
					tool_id = content.id,
					questions = content.input.questions,
				}
			end
		end
	end

	return nil
end

function M.contains_question(data)
	if not data or data.type ~= "assistant" then
		return false
	end

	if data.message and data.message.content then
		local last_text = nil
		for _, content in ipairs(data.message.content) do
			if content.type == "text" and content.text then
				last_text = content.text
			end
		end

		if last_text then
			local lines = {}
			for line in last_text:gmatch("[^\r\n]+") do
				table.insert(lines, line)
			end

			if #lines > 0 then
				local last_line = lines[#lines]:match("^%s*(.-)%s*$")
				if last_line:match("%?%s*$") then
					return true
				end
			end
		end
	end

	return false
end

function M.format_output(data, session_id, timestamp, cost_delta)
	if not data then
		return nil
	end

	local lines = {}

	if data.type == "system" then
		if data.subtype == "init" then
			if session_id and not session_metadata_shown[session_id] then
				local table_rows = {
					{ "Property", "Value" },
					{ "Session ID", data.session_id or "unknown" },
					{ "Model", data.model or "unknown" },
				}
				vim.list_extend(lines, create_markdown_table(table_rows))
				table.insert(lines, "")
				session_metadata_shown[session_id] = true
			end
		end
	elseif data.type == "assistant" then
		if timestamp or cost_delta then
			table.insert(lines, "")
			table.insert(lines, "")
			local header = "**Assistant**"
			if timestamp then
				header = header .. string.format(" [%s]", format_timestamp(timestamp))
			end
			if cost_delta and cost_delta > 0 then
				header = header .. string.format(" 💰 $%.4f", cost_delta)
			end
			table.insert(lines, header)
		end
		if data.message and data.message.content then
			for _, content in ipairs(data.message.content) do
				if content.type == "text" and content.text then
					vim.list_extend(lines, format_as_blockquote(content.text))
				elseif content.type == "tool_use" then
					if content.name == "AskUserQuestion" and content.input then
						local question_lines = M.format_question(content.input)
						if question_lines then
							vim.list_extend(lines, question_lines)
						end
					else
						local tool_details = {}
						if content.input then
							local ok, json_str = pcall(vim.json.encode, content.input)
							if ok then
								table.insert(tool_details, "```json")
								table.insert(tool_details, json_str)
								table.insert(tool_details, "```")
							end
						end
						vim.list_extend(
							lines,
							create_collapsible_details("Tool: " .. (content.name or "unknown"), tool_details)
						)
					end
				end
			end
		end
	elseif data.type == "content_block_start" then
		if data.index ~= nil and data.content_block then
			content_blocks[data.index] = {
				type = data.content_block.type,
				name = data.content_block.name,
				accumulated_text = "",
				accumulated_json = "",
				accumulated_thinking = "",
			}
		end
		return nil
	elseif data.type == "content_block_delta" then
		if data.index ~= nil and data.delta then
			local block = content_blocks[data.index]
			if not block then
				return nil
			end

			if data.delta.type == "text_delta" and data.delta.text then
				block.accumulated_text = block.accumulated_text .. data.delta.text
				vim.list_extend(lines, format_as_blockquote(data.delta.text))
			elseif data.delta.type == "input_json_delta" and data.delta.partial_json then
				block.accumulated_json = block.accumulated_json .. data.delta.partial_json
				return nil
			elseif data.delta.type == "thinking_delta" and data.delta.thinking then
				if not block.accumulated_thinking then
					block.accumulated_thinking = ""
				end
				block.accumulated_thinking = block.accumulated_thinking .. data.delta.thinking
				return nil
			end
		end
	elseif data.type == "content_block_stop" then
		if data.index ~= nil then
			local block = content_blocks[data.index]
			if block then
				if block.accumulated_thinking and block.accumulated_thinking ~= "" then
					local thinking_details = {}
					for line in block.accumulated_thinking:gmatch("[^\r\n]+") do
						table.insert(thinking_details, line)
					end
					vim.list_extend(
						lines,
						{
							"<details open>",
							"<summary>💭 Thinking</summary>",
							"",
							table.concat(thinking_details, "\n"),
							"",
							"</details>",
							"",
						}
					)
				end
				if block.type == "tool_use" and block.accumulated_json ~= "" then
					local tool_details = {}
					table.insert(tool_details, "```json")
					table.insert(tool_details, block.accumulated_json)
					table.insert(tool_details, "```")
					vim.list_extend(lines, create_collapsible_details("Tool: " .. (block.name or "unknown"), tool_details))
				end
			end
			content_blocks[data.index] = nil
		end
	elseif data.type == "user" then
		if data.message and data.message.content then
			for _, content in ipairs(data.message.content) do
				if content.type == "tool_result" then
					local result_details = {}
					if type(content.content) == "table" then
						for _, content_item in ipairs(content.content) do
							if content_item.type == "text" and content_item.text then
								table.insert(result_details, content_item.text)
							end
						end
					elseif content.content then
						table.insert(result_details, tostring(content.content))
					end
					if #result_details > 0 then
						vim.list_extend(
							lines,
							{
								"<details>",
								"<summary>Tool Result</summary>",
								"",
								table.concat(result_details, "\n"),
								"",
								"</details>",
								"",
							}
						)
					end
				end
			end
		end
	elseif data.type == "result" then
		if data.subtype == "success" then
			return nil
		elseif data.subtype == "error_max_turns" then
			table.insert(lines, "> **Session ended**: Maximum turns reached")
		elseif data.subtype == "error_during_execution" then
			table.insert(lines, string.format("> **Error**: %s", data.result or "Execution error"))
		end
	elseif data.type == "error" then
		table.insert(lines, string.format("> ⚠️  **Error**: %s", data.result or "Unknown error"))
	end

	return #lines > 0 and lines or nil
end

return M
