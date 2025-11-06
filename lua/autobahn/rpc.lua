local M = {}

function M.handle_question(request_id, questions_json)
	vim.schedule(function()
		local ok, data = pcall(vim.json.decode, questions_json)
		if not ok or not data.questions then
			M.write_answer(request_id, { error = "Invalid question data" })
			return
		end

		local question = data.questions[1]
		local items = {}

		for i, opt in ipairs(question.options or {}) do
			table.insert(items, {
				idx = i,
				text = opt.label .. " - " .. (opt.description or ""),
				answer_key = opt.label,
			})
		end

		table.insert(items, {
			idx = #items + 1,
			text = "Other (type custom response)",
			answer_key = "__OTHER__",
		})

		require("snacks").picker.pick({
			items = items,
			prompt = " " .. question.question .. " ",
			format = "text",
			layout = { preview = false },
			confirm = function(picker, item)
				picker:close()
				if not item then
					M.write_answer(request_id, { cancelled = true })
					return
				end

				if item.answer_key == "__OTHER__" then
					vim.ui.input({ prompt = question.question }, function(input)
						if input and input ~= "" then
							M.write_answer(request_id, { [question.header or "answer"] = input })
						else
							M.write_answer(request_id, { cancelled = true })
						end
					end)
				else
					M.write_answer(request_id, { [question.header or "answer"] = item.answer_key })
				end
			end,
		})
	end)

	return "ok"
end

function M.write_answer(request_id, answer)
	local answer_file = "/tmp/claude-answer-" .. request_id .. ".json"
	local json = vim.json.encode(answer)
	vim.fn.writefile({ json }, answer_file)
end

return M
