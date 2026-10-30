-- Private key logger for the Vim course.
--
-- Records every *typed* key (not mapping expansions) as one JSON object per
-- line in `stdpath('state')/keylog/YYYY-MM-DD.jsonl`:
--
--   {"t":<epoch ms>,"m":"<mode>","k":"<keytrans(key)>","ft":"<filetype>","f":"<~-shortened buffer name>"}
--
-- Privacy:
--   * In insert/replace modes (mode starts with `i` or `R`), in prompt and
--     terminal buffers, and in `input()`-style prompts, printable characters
--     are logged as "·" so the count survives but the text doesn't. Special
--     keys (<BS>, <C-W>, <Esc>, arrows, <CR>, <Tab>, ...) are logged as-is.
--   * Nothing is logged for buffers named `.env`/`.env.*`, `*.pem`, `*.key`,
--     or whose path contains "secret".
--   * Nothing is logged while `vim.g.keylog_disabled` is true (`:KeylogToggle`).
--
-- which-key replays: which-key reads the keys after a trigger (`g`, `z`,
-- `<Space>`, `<C-W>`, and motions in operator-pending/visual mode) with
-- getcharstr(), then re-feeds them with nvim_feedkeys(..., "mit"). The `t`
-- flag makes Neovim report them to on_key as typed a second time, so keys
-- which-key feeds that way are recorded and dropped when they come back.
--
-- Keys are buffered in memory and appended to disk about every 2s and on exit.

local M = {}

local FLUSH_MS = 2000
local MASK = '·'

local ns = vim.api.nvim_create_namespace 'custom.keylog'
local uv = vim.uv or vim.loop

local dir -- set in setup()
local pending = {} -- { [date] = { line, ... } }
local has_pending = false
local timer

-- Keys that are noise for grading (and can fire constantly).
local ignored = {
  ['<MouseMove>'] = true,
  ['<FocusGained>'] = true,
  ['<FocusLost>'] = true,
  ['<Ignore>'] = true,
  ['<Nop>'] = true,
  ['<CursorHold>'] = true,
}

-- keytrans() spells these printable characters as <...>; they still get masked.
local printable_names = {
  ['<Space>'] = true,
  ['<lt>'] = true,
  ['<Bslash>'] = true,
  ['<Bar>'] = true,
  ['<kPlus>'] = true,
  ['<kMinus>'] = true,
  ['<kMultiply>'] = true,
  ['<kDivide>'] = true,
  ['<kPoint>'] = true,
  ['<kComma>'] = true,
  ['<kEqual>'] = true,
}

local function is_printable(k)
  if k:sub(1, 1) ~= '<' then
    return true
  end
  -- Keypad digits type text too.
  return printable_names[k] == true or k:match '^<k%d>$' ~= nil
end

-- Split a raw keycode string (possibly several keys, e.g. a typed mapping
-- like "<Space>sf") into one raw chunk per key.
local K_SPECIAL = 0x80
local KS_MODIFIER = 0xFC
local KS_SPECIAL = 0xFE
local function split_keys(s)
  local keys = {}
  local i, n = 1, #s
  while i <= n do
    local start = i
    -- Modifier prefixes (K_SPECIAL KS_MODIFIER <mods>) bind to the next key.
    while s:byte(i) == K_SPECIAL and s:byte(i + 1) == KS_MODIFIER do
      i = i + 3
    end
    local b = s:byte(i)
    if b == nil then
      break
    elseif b == K_SPECIAL then
      i = i + 3
    else
      local len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
      i = i + 1
      for _ = 2, len do
        -- A 0x80 continuation byte is escaped as K_SPECIAL KS_SPECIAL KE_FILLER.
        if s:byte(i) == K_SPECIAL and s:byte(i + 1) == KS_SPECIAL then
          i = i + 3
        else
          i = i + 1
        end
      end
    end
    keys[#keys + 1] = s:sub(start, i - 1)
  end
  return keys
end

-- Per-buffer-name cache of { shortened name, skip? }.
local name_cache = {}
local function buf_info(name)
  local info = name_cache[name]
  if not info then
    local base = vim.fn.fnamemodify(name, ':t')
    local skip = base == '.env'
      or base:sub(1, 5) == '.env.'
      or base:match '%.pem$' ~= nil
      or base:match '%.key$' ~= nil
      or name:lower():find('secret', 1, true) ~= nil
    info = { name == '' and '' or vim.fn.fnamemodify(name, ':~'), skip }
    name_cache[name] = info
  end
  return info[1], info[2]
end

local function write_all()
  if not has_pending then
    return
  end
  local batch = pending
  pending, has_pending = {}, false
  for date, lines in pairs(batch) do
    local fd = uv.fs_open(dir .. '/' .. date .. '.jsonl', 'a', 384) -- 0600
    if fd then
      uv.fs_write(fd, table.concat(lines, '\n') .. '\n')
      uv.fs_close(fd)
    end
  end
end

function M.flush()
  if timer then
    timer:stop()
  end
  write_all()
end

local function schedule_flush()
  if not timer then
    timer = uv.new_timer()
  end
  if not timer:is_active() then
    timer:start(FLUSH_MS, 0, write_all)
  end
end

-- Keys which-key has fed back as "typed" and that haven't come through
-- on_key yet, in order (keytrans() form), plus when the expectation lapses.
local replay = {}
local replay_head = 1
local replay_deadline = 0

local function now_ms()
  local sec, usec = uv.gettimeofday()
  return sec * 1000 + math.floor(usec / 1000)
end

local function expect_replay(feed)
  for _, raw in ipairs(split_keys(feed)) do
    replay[#replay + 1] = vim.fn.keytrans(raw)
  end
  -- The replay sits at the front of the typeahead, so it normally arrives
  -- within a few ms. It can wait up to 'timeoutlen' when it's the prefix of
  -- a longer mapping (e.g. `gr` vs `grn`), so allow that plus some slack.
  replay_deadline = now_ms() + vim.o.timeoutlen + 1000
end

-- Returns true if `k` is the next key of a pending which-key replay (and
-- consumes it). Any other key cancels the pending replay.
local function is_replay(k)
  if replay[replay_head] == nil then
    return false
  end
  if replay[replay_head] == k and now_ms() <= replay_deadline then
    replay_head = replay_head + 1
    if replay[replay_head] == nil then
      replay, replay_head = {}, 1
    end
    return true
  end
  replay, replay_head = {}, 1
  return false
end

-- Wrap which-key's State.execute (the only place it feeds keys as typed) to
-- capture exactly what it re-feeds. Behaviour is unchanged. Only runs once
-- which-key is loaded, so it never changes when which-key loads.
local function hook_which_key()
  if not package.loaded['which-key'] then
    return
  end
  local ok, State = pcall(require, 'which-key.state')
  if not ok or type(State) ~= 'table' or type(State.execute) ~= 'function' or State._keylog_hooked then
    return
  end
  local execute = State.execute
  State._keylog_hooked = true
  State.execute = function(...)
    replay, replay_head = {}, 1
    local api = vim.api
    local feedkeys = api.nvim_feedkeys
    api.nvim_feedkeys = function(keys, mode, escape_ks)
      if type(keys) == 'string' and type(mode) == 'string' and mode:find('t', 1, true) then
        expect_replay(escape_ks and api.nvim_replace_termcodes(keys, true, true, true) or keys)
      end
      return feedkeys(keys, mode, escape_ks)
    end
    local res = vim.F.pack_len(pcall(execute, ...))
    api.nvim_feedkeys = feedkeys
    if not res[1] then
      error(res[2], 0)
    end
    return vim.F.unpack_len(res, 2)
  end
end

local cur_sec, cur_date = -1, nil
local enc = vim.json.encode

local function on_key(_, typed)
  if typed == nil or typed == '' then
    return
  end

  local keys = split_keys(typed)
  -- Neovim quirk: the body of a non-typed `<Cmd>...<CR>` (e.g. nvim-cmp's
  -- `<Cmd>lua require"cmp.utils.feedkeys".run(1)<CR>`) can leak into the next
  -- key's {typed}, giving e.g. `un(1)<CR>i`. A real multi-key {typed} (a typed
  -- mapping LHS) practically never has <CR> before its last key, so drop
  -- everything up to such a <CR>.
  for j = #keys - 1, 1, -1 do
    if keys[j] == '\r' then
      keys = { unpack(keys, j + 1) }
      break
    end
  end
  -- Drop which-key replays before any other check, so an unlogged replay
  -- (paused, skipped buffer) can't linger and swallow a later real key.
  local names = {}
  for _, raw in ipairs(keys) do
    local k = vim.fn.keytrans(raw)
    if k ~= '' and not ignored[k] and not is_replay(k) then
      names[#names + 1] = k
    end
  end
  if #names == 0 or vim.g.keylog_disabled then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local f, skip = buf_info(vim.api.nvim_buf_get_name(bufnr))
  if skip then
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  local first = mode:sub(1, 1)
  local bt = vim.bo[bufnr].buftype
  local mask = first == 'i'
    or first == 'R'
    or bt == 'prompt'
    or bt == 'terminal'
    -- input()/inputsecret() and :append/:insert text, not Ex commands.
    or (first == 'c' and (vim.fn.getcmdtype() == '@' or vim.fn.getcmdtype() == '-'))

  local sec, usec = uv.gettimeofday()
  local t = sec * 1000 + math.floor(usec / 1000)
  if sec ~= cur_sec then
    cur_sec, cur_date = sec, os.date('%Y-%m-%d', sec)
  end
  local lines = pending[cur_date]
  if not lines then
    lines = {}
    pending[cur_date] = lines
  end

  local prefix = string.format('{"t":%d,"m":%s,"k":', t, enc(mode))
  local suffix = string.format(',"ft":%s,"f":%s}', enc(vim.bo[bufnr].filetype), enc(f))
  for _, k in ipairs(names) do
    if mask and is_printable(k) then
      k = MASK
    end
    lines[#lines + 1] = prefix .. enc(k) .. suffix
    has_pending = true
  end

  if has_pending then
    schedule_flush()
  end
  -- Must return nil: returning '' would swallow the key.
end

function M.enable()
  vim.on_key(on_key, ns)
end

function M.disable()
  vim.on_key(nil, ns)
  M.flush()
end

function M.setup()
  dir = vim.fn.stdpath 'state' .. '/keylog'
  vim.fn.mkdir(dir, 'p', 448) -- 0700

  M.enable()

  local group = vim.api.nvim_create_augroup('custom-keylog', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.flush })

  -- which-key is usually lazy-loaded (kickstart: on VimEnter), after this runs.
  hook_which_key()
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'LazyLoad',
    callback = function(ev)
      if ev.data == 'which-key.nvim' then
        hook_which_key()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    callback = function()
      vim.schedule(hook_which_key)
    end,
  })

  vim.api.nvim_create_user_command('KeylogToggle', function()
    vim.g.keylog_disabled = not vim.g.keylog_disabled
    if vim.g.keylog_disabled then
      M.flush()
    end
    vim.notify('Keylog ' .. (vim.g.keylog_disabled and 'paused' or 'recording'), vim.log.levels.INFO)
  end, { desc = 'Pause/resume the Vim course key logger' })
end

return M
