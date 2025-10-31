local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This extension requires telescope.nvim")
end

local integration = require("autobahn.integrations.telescope")

return telescope.register_extension({
  exports = {
    sessions = integration.sessions_picker,
  },
})
