-- Coaching hints for inefficient motions (e.g. `jjjj` -> `4j`).
-- Hint mode only: nothing is blocked and the mouse stays enabled.
return {
  'm4xshen/hardtime.nvim',
  event = 'VeryLazy',
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {
    restriction_mode = 'hint',
    disable_mouse = false,
    -- hardtime blocks the arrow keys by default, even in hint mode. Allow them;
    -- the course's key log still sees them.
    disabled_keys = {
      ['<Up>'] = false,
      ['<Down>'] = false,
      ['<Left>'] = false,
      ['<Right>'] = false,
    },
  },
}
