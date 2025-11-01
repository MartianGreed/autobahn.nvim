local Input = require("nui.input")
local M = {}

function M.prompt_message(session_id, callback)
  local input = Input({
    position = "50%",
    size = {
      width = 80,
      height = 3,
    },
    border = {
      style = "rounded",
      text = {
        top = " Send Message to Agent ",
        top_align = "center",
      },
    },
  }, {
    prompt = "> ",
    on_submit = function(value)
      if value and value ~= "" then
        callback(value)
      else
        vim.notify("Message cannot be empty", vim.log.levels.WARN)
      end
    end,
  })

  input:mount()

  input:map("n", "<Esc>", function()
    input:unmount()
  end)
end

return M
