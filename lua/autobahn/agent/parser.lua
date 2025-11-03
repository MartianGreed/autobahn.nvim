local M = {}

local content_blocks = {}

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
        table.insert(result, "> " .. line)
      else
        if in_code then
          table.insert(code_lines, line)
        else
          table.insert(result, "> " .. line)
        end
      end
    end
  end

  if in_code then
    table.insert(result, "```")
  end

  return result
end

local function format_as_blockquote(text)
  local formatted = format_code_blocks(text)

  for i, line in ipairs(formatted) do
    if not line:match("^```") and not line:match("^>") then
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
  table.insert(lines, "<details>")
  table.insert(lines, string.format("<summary>🔧 %s</summary>", title))
  table.insert(lines, "")

  if type(content) == "table" then
    vim.list_extend(lines, content)
  else
    table.insert(lines, content or "")
  end

  table.insert(lines, "</details>")
  return lines
end

function M.format_output(data)
  if not data then
    return nil
  end

  local lines = {}

  if data.type == "system" then
    if data.subtype == "init" then
      local table_rows = {
        {"Property", "Value"},
        {"Session ID", data.session_id or "unknown"},
        {"Model", data.model or "unknown"}
      }
      vim.list_extend(lines, create_markdown_table(table_rows))
      table.insert(lines, "")
    end
  elseif data.type == "assistant" then
    if data.message and data.message.content then
      for _, content in ipairs(data.message.content) do
        if content.type == "text" and content.text then
          vim.list_extend(lines, format_as_blockquote(content.text))
        elseif content.type == "tool_use" then
          local tool_details = {}
          if content.input then
            local ok, json_str = pcall(vim.json.encode, content.input)
            if ok then
              table.insert(tool_details, "```json")
              table.insert(tool_details, json_str)
              table.insert(tool_details, "```")
            end
          end
          vim.list_extend(lines, create_collapsible_details("Tool: " .. (content.name or "unknown"), tool_details))
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
      end
    end
  elseif data.type == "content_block_stop" then
    if data.index ~= nil then
      local block = content_blocks[data.index]
      if block and block.type == "tool_use" and block.accumulated_json ~= "" then
        local tool_details = {}
        table.insert(tool_details, "```json")
        table.insert(tool_details, block.accumulated_json)
        table.insert(tool_details, "```")
        vim.list_extend(lines, create_collapsible_details("Tool: " .. (block.name or "unknown"), tool_details))
      end
      content_blocks[data.index] = nil
    end
  elseif data.type == "text" then
    vim.list_extend(lines, format_as_blockquote(data.result or ""))
  elseif data.type == "tool_use" then
    local tool_name = data.subtype or "unknown"
    local tool_details = {}
    if data.result then
      table.insert(tool_details, data.result)
    end
    vim.list_extend(lines, create_collapsible_details("Tool: " .. tool_name, tool_details))
  elseif data.type == "result" then
    table.insert(lines, "")
    local table_rows = {
      {"Property", "Value"},
      {"Status", "Session Complete"}
    }
    if data.total_cost_usd then
      table.insert(table_rows, {"Total Cost", string.format("$%.4f", data.total_cost_usd)})
    end
    if data.duration_ms then
      table.insert(table_rows, {"Duration", string.format("%.2fs", data.duration_ms / 1000)})
    end
    vim.list_extend(lines, create_markdown_table(table_rows))
  elseif data.type == "error" then
    table.insert(lines, string.format("> ⚠️  **Error**: %s", data.result or "Unknown error"))
  end

  return #lines > 0 and lines or nil
end

return M
