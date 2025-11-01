return {
  "your-name/autobahn.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
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
          auto_accept_flag = "--dangerously-skip-permissions",
          max_cost_usd = 1.0,
          output_format = "stream-json",
        },

        ["aider"] = {
          cmd = "aider",
          auto_accept = true,
          auto_accept_flag = "--yes",
          max_cost_usd = 0.5,
        },

        ["custom-script"] = {
          cmd = vim.fn.expand("~/.local/bin/my-coding-agent"),
          auto_accept = false,
          auto_accept_flag = { "--auto", "--no-confirm" },
          max_cost_usd = 2.0,
        },
      },
    })

    local events = require("autobahn.events")

    events.on(events.EventType.SESSION_COMPLETED, function(data)
      local autobahn = require("autobahn")
      autobahn.view_session(data.id)
    end)

    events.on(events.EventType.SESSION_ERROR, function(data)
      local autobahn = require("autobahn")
      autobahn.view_session(data.id)
    end)
  end,

  keys = {
    { "<leader>a", "<cmd>Autobahn<cr>", desc = "Autobahn Sessions" },
    { "<leader>ad", "<cmd>AutobahnDashboard<cr>", desc = "Autobahn Dashboard" },
    { "<leader>al", "<cmd>Autobahn last<cr>", desc = "Last Session" },
    { "<leader>ar", "<cmd>Autobahn running<cr>", desc = "Running Sessions" },
    { "<leader>ae", "<cmd>Autobahn errors<cr>", desc = "Error Sessions" },
    { "<leader>an", "<cmd>AutobahnNew<cr>", desc = "New Session" },

    {
      "<leader>as",
      function()
        require("telescope").extensions.autobahn.sessions()
      end,
      desc = "Search Sessions (Telescope)",
    },
  },
}
