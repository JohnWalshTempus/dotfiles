local keymap = vim.api.nvim_set_keymap

require("Comment").setup(
  {
    ---Add a space b/w comment and the line
    ---@type boolean
    padding = true,
    ---Whether the cursor should stay at its position
    ---NOTE: This only affects NORMAL mode mappings and doesn't work with dot-repeat
    ---@type boolean
    sticky = true,
    ---Lines to be ignored while comment/uncomment.
    ---Could be a regex string or a function that returns a regex string.
    ---Example: Use '^$' to ignore empty lines
    ---@type string|function
    ignore = nil,
    ---LHS of toggle mappings in NORMAL + VISUAL mode
    ---@type table
    toggler = {
      ---line-comment keymap
      line = "gcc",
      ---block-comment keymap
      block = "gbc"
    },
    ---LHS of operator-pending mappings in NORMAL + VISUAL mode
    ---@type table
    opleader = {
      ---line-comment keymap
      line = "gc",
      ---block-comment keymap
      block = "gb"
    },
    ---Create basic (operator-pending) and extended mappings for NORMAL + VISUAL mode
    ---@type table
    mappings = {
      ---operator-pending mapping
      ---Includes `gcc`, `gbc`, `gc[count]{motion}` and `gb[count]{motion}`
      ---NOTE: These mappings can be changed individually by `opleader` and `toggler` config
      basic = true,
      ---extra mapping
      ---Includes `gco`, `gcO`, `gcA`
      extra = true,
      ---extended mapping
      ---Includes `g>`, `g<`, `g>[count]{motion}` and `g<[count]{motion}`
      extended = false
    },
    ---Pre-hook, called before commenting the line
    ---@type fun(ctx: Ctx):string
    pre_hook = function(ctx)
      -- Only calculate commentstring for tsx filetypes
      if vim.bo.filetype == "typescriptreact" then
        local U = require("Comment.utils")

        -- Detemine whether to use linewise or blockwise commentstring
        local type = ctx.ctype == U.ctype.line and "__default" or "__multiline"

        -- Determine the location where to calculate commentstring from
        local location = nil
        if ctx.ctype == U.ctype.block then
          location = require("ts_context_commentstring.utils").get_cursor_location()
        elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
          location = require("ts_context_commentstring.utils").get_visual_start_location()
        end

        return require("ts_context_commentstring.internal").calculate_commentstring(
          {
            key = type,
            location = location
          }
        )
      end
    end,
    ---Post-hook, called after commenting is done
    ---@type fun(ctx: Ctx)
    post_hook = nil
  }
)
