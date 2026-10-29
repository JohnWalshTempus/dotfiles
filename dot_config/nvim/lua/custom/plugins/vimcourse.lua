-- Vim course plugin (keylog grading, lessons). Lives outside this repo, so
-- only load it on machines where the course is checked out.
local dir = vim.fn.expand '~/projects/vim-course/nvim'

return {
  dir = dir,
  name = 'vimcourse',
  cond = vim.fn.isdirectory(dir) == 1,
  config = function()
    require('vimcourse').setup()
  end,
}
