local M = {}

function M.get_plugin_path()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(source, ":h:h:h")
end

function M.read_json(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local content = file:read("*a")
	file:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok then
		return data
	end
	return nil
end

function M.write_json(path, data)
	local json = vim.json.encode(data)
	local formatted = vim.fn.system({ "jq", "." }, json)
	if vim.v.shell_error ~= 0 then
		formatted = json
	end
	local file = io.open(path, "w")
	if file then
		file:write(formatted)
		file:close()
		return true
	end
	return false
end

function M.ensure_gitignore(project_path, pattern)
	local gitignore_path = project_path .. "/.gitignore"
	local lines = {}
	local found = false

	local file = io.open(gitignore_path, "r")
	if file then
		for line in file:lines() do
			table.insert(lines, line)
			if line:match("^" .. vim.pesc(pattern) .. "$") then
				found = true
			end
		end
		file:close()
	end

	if not found then
		table.insert(lines, pattern)
		file = io.open(gitignore_path, "w")
		if file then
			file:write(table.concat(lines, "\n") .. "\n")
			file:close()
		end
	end
end

function M.setup_project(project_path)
	project_path = project_path or vim.fn.getcwd()

	local plugin_path = M.get_plugin_path()
	local source_script = plugin_path .. "/scripts/prompt-nvim.sh"

	if vim.fn.filereadable(source_script) == 0 then
		vim.notify("Source script not found: " .. source_script, vim.log.levels.ERROR)
		return false
	end

	local claude_dir = project_path .. "/.claude"
	local scripts_dir = claude_dir .. "/scripts"
	vim.fn.mkdir(scripts_dir, "p")

	local dest_script = scripts_dir .. "/prompt-nvim.sh"
	vim.fn.system({ "cp", source_script, dest_script })
	vim.fn.system({ "chmod", "+x", dest_script })

	local settings_file = claude_dir .. "/settings.local.json"
	local settings = M.read_json(settings_file) or {}

	settings.hooks = settings.hooks or {}
	settings.hooks.PreToolUse = {
		{
			matcher = "AskUserQuestion",
			hooks = {
				{
					type = "command",
					command = ".claude/scripts/prompt-nvim.sh",
					timeout = 600000,
				},
			},
		},
	}

	if not M.write_json(settings_file, settings) then
		vim.notify("Failed to write settings file", vim.log.levels.ERROR)
		return false
	end

	M.ensure_gitignore(project_path, ".claude/scripts/")
	M.ensure_gitignore(project_path, ".claude/settings.local.json")

	vim.notify("Autobahn hooks configured for " .. project_path, vim.log.levels.INFO)
	return true
end

return M
