return {
  "your-name/autobahn.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "ThePrimeagen/git-worktree.nvim",
  },
  config = function()
    require("autobahn").setup({
      default_agent = "claude-code",

      vcs = "auto",

      dashboard_position = "right",
      dashboard_size = "30%",

      persist = true,
      restore_on_startup = false,

      max_concurrent_sessions = 10,

      agents = {
        ["claude-code"] = {
          cmd = "claude",
          auto_accept = false,
          max_cost_usd = 1.0,
          output_format = "stream-json",
        },

        ["aider"] = {
          cmd = "aider",
          auto_accept = true,
          max_cost_usd = 0.5,
        },

        ["custom-script"] = {
          cmd = vim.fn.expand("~/.local/bin/my-coding-agent"),
          auto_accept = false,
          max_cost_usd = 2.0,
        },
      },
    })

    local events = require("autobahn.events")

    events.on(events.EventType.SESSION_COMPLETED, function(data)
      vim.notify(
        string.format("Session %s completed!", data.id),
        vim.log.levels.INFO
      )
    end)

    events.on(events.EventType.SESSION_ERROR, function(data)
      vim.notify(
        string.format("Session %s failed with code %d", data.id, data.exit_code),
        vim.log.levels.ERROR
      )
    end)
  end,

  keys = {
    { "<leader>ad", "<cmd>AutobahnDashboard<cr>", desc = "Autobahn Dashboard" },
    { "<leader>an", "<cmd>AutobahnNew<cr>", desc = "New Autobahn Session" },
    { "<leader>ar", "<cmd>AutobahnRestore<cr>", desc = "Restore Sessions" },
    { "<leader>ac", "<cmd>AutobahnClear<cr>", desc = "Clear Sessions" },

    {
      "<leader>as",
      function()
        require("telescope").extensions.autobahn.sessions()
      end,
      desc = "Search Sessions",
    },

    {
      "<leader>aq",
      function()
        local session_id = vim.fn.input("Session ID: ")
        if session_id ~= "" then
          require("autobahn").view_session(session_id)
        end
      end,
      desc = "Quick View Session",
    },
  },
}
