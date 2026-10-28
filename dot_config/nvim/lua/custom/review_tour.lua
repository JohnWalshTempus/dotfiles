local M = {}

function M.start()
  local tour_file = vim.env.REVIEW_TOUR_QF
  local overview = vim.env.REVIEW_TOUR_MD
  local notes = vim.env.REVIEW_NOTES
  local base = vim.env.REVIEW_BASE
  local wt = vim.fn.getcwd()

  require('lazy').load { plugins = { 'diffview.nvim' } }

  local stops = {}
  for line in io.lines(tour_file) do
    local path, lnum, text = line:match '^([^:]+):(%d+):%s*(.*)$'
    if path then
      table.insert(stops, { path = path, lnum = tonumber(lnum), text = text })
    end
  end
  local cur = 0
  local float

  local function show_note(stop)
    if float and vim.api.nvim_win_is_valid(float) then
      vim.api.nvim_win_close(float, true)
    end
    local lines = { vim.fn.fnamemodify(stop.path, ':t') .. ':' .. stop.lnum, '', stop.text }
    local view = require('diffview.lib').get_current_view()
    local panel = view and view.panel
    local opts = { style = 'minimal', border = 'rounded', title = string.format(' stop %d/%d ', cur, #stops), title_pos = 'left' }
    local width, max_h
    if panel and panel:is_open() then
      local pw, ph = vim.api.nvim_win_get_width(panel.winid), vim.api.nvim_win_get_height(panel.winid)
      width, max_h = math.max(10, pw - 2), math.max(3, math.floor(ph / 2))
      opts = vim.tbl_extend('force', opts, { relative = 'win', win = panel.winid, anchor = 'SW', row = ph, col = 0 })
    else
      width, max_h = math.floor(vim.o.columns * 0.4), 10
      opts = vim.tbl_extend('force', opts, { relative = 'editor', anchor = 'SW', row = vim.o.lines - 2, col = 0 })
    end
    local height = 0
    for _, l in ipairs(lines) do
      height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
    end
    opts.width, opts.height = width, math.min(height, max_h)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    float = vim.api.nvim_open_win(buf, false, opts)
    vim.wo[float].wrap = true
    vim.wo[float].linebreak = true
  end

  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    callback = function()
      if cur > 0 and float and vim.api.nvim_win_is_valid(float) then
        vim.schedule(function()
          show_note(stops[cur])
        end)
      end
    end,
  })

  local function jump_line(stop, tries)
    local view = require('diffview.lib').get_current_view()
    local layout = view and view.cur_layout
    local win = layout and ((layout.b and layout.b.file and layout.b.file.path == stop.path and layout.b) or layout.a)
    if not (win and win.id and vim.api.nvim_win_is_valid(win.id) and win.file and win.file.path == stop.path) then
      if tries > 0 then
        vim.defer_fn(function()
          jump_line(stop, tries - 1)
        end, 100)
      end
      return
    end
    vim.api.nvim_set_current_win(win.id)
    local last = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win.id))
    pcall(vim.api.nvim_win_set_cursor, win.id, { math.max(1, math.min(stop.lnum, last)), 0 })
    vim.cmd 'normal! zz'
  end

  local function go(i)
    if #stops == 0 then
      return vim.notify('review-tour: no stops', vim.log.levels.WARN)
    end
    cur = math.max(1, math.min(i, #stops))
    local stop = stops[cur]
    local view = require('diffview.lib').get_current_view()
    if not view then
      return
    end
    view:set_file_by_path(stop.path, true, true)
    jump_line(stop, 20)
    show_note(stop)
  end

  local function add_note()
    local view = require('diffview.lib').get_current_view()
    local file = view and view:infer_cur_file()
    local path = file and file.path or vim.fn.expand '%:.'
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    vim.ui.input({ prompt = string.format('note %s:%d> ', path, lnum) }, function(text)
      if not text or text == '' then
        return
      end
      local f = assert(io.open(notes, 'a'))
      f:write(string.format('%s:%d: %s\n', path, lnum, text))
      f:close()
      vim.notify 'review-tour: note saved'
    end)
  end

  local function open_overview()
    vim.cmd('tabnew ' .. vim.fn.fnameescape(overview))
    vim.bo.modifiable = false
  end

  local map = function(lhs, fn, desc)
    vim.keymap.set('n', lhs, fn, { desc = 'review-tour: ' .. desc })
  end
  map(']q', function()
    go(cur + 1)
  end, 'next stop')
  map('[q', function()
    go(cur - 1)
  end, 'previous stop')
  map('<leader>rn', add_note, 'add note at cursor')
  map('<leader>rt', open_overview, 'open overview')
  map('<leader>rs', function()
    go(cur)
  end, 're-show current stop')
  map('<leader>rq', function()
    vim.cmd 'qa!'
  end, 'end review')

  vim.cmd('DiffviewOpen ' .. base)
  vim.defer_fn(function()
    go(1)
  end, 300)
  vim.notify(string.format('review-tour %s: %d stops  ]q/[q stops  <leader>rn note  <leader>rt overview  <leader>rq quit', wt, #stops))
end

return M
