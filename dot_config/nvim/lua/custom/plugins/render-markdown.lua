-- Render markdown in place: headings, tables, code blocks, checkboxes,
-- callouts. The cursor line (anti-conceal) and insert mode show the raw text.
-- Uses `vim.treesitter` directly (markdown + markdown_inline parsers).
return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = 'markdown',
  -- Icon provider for code block language icons. mini.icons would need its
  -- own setup() call, and devicons is already installed for telescope.
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    {
      '<leader>tm',
      function()
        require('render-markdown').toggle()
      end,
      desc = '[T]oggle [M]arkdown rendering',
    },
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {},
}
