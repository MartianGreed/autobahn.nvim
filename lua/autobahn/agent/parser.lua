local M = {}

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

function M.format_output(data)
  if not data then
    return nil
  end

  local lines = {}

  if data.type == "system" then
    if data.subtype == "init" then
      table.insert(lines, string.format("Session: %s", data.session_id or "unknown"))
      table.insert(lines, string.format("Model: %s", data.model or "unknown"))
      table.insert(lines, "")
    end
  elseif data.type == "assistant" then
    if data.message and data.message.content then
      for _, content in ipairs(data.message.content) do
        if content.type == "text" and content.text then
          table.insert(lines, content.text)
        elseif content.type == "tool_use" then
          table.insert(lines, string.format("[Tool: %s]", content.name or "unknown"))
        end
      end
    end
  elseif data.type == "text" then
    table.insert(lines, data.result or "")
  elseif data.type == "tool_use" then
    local tool_name = data.subtype or "unknown"
    table.insert(lines, string.format("[Tool: %s]", tool_name))
    if data.result then
      table.insert(lines, data.result)
    end
  elseif data.type == "result" then
    table.insert(lines, "")
    table.insert(lines, "=== Session Complete ===")
    if data.total_cost_usd then
      table.insert(lines, string.format("Total Cost: $%.4f", data.total_cost_usd))
    end
    if data.duration_ms then
      table.insert(lines, string.format("Duration: %.2fs", data.duration_ms / 1000))
    end
  elseif data.type == "error" then
    table.insert(lines, string.format("Error: %s", data.result or "Unknown error"))
  end

  return #lines > 0 and lines or nil
end

return M
