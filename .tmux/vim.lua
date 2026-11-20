-- Runs keys in a real (embedded, blank) Neovim for .tmux/vim.sh, over the
-- lines around tmux's copy-mode cursor, and says what they came to:
--   pending                   Vim wants more keys (yt, yi, y/foo)
--   yank                      a yank happened; its text follows
--   select MODE L1 V1 L2 V2   a visual selection (lines and virtual columns)
--   none                      the keys came to nothing (ytQ with no Q)
-- Run as nvim -l vim.lua FILE LINE VCOL KEYS (1-based line and column).
--
-- Neovim runs embedded, not in this script, because a Vim waiting for a key
-- (t's character) runs nothing else; nvim_get_mode still answers over RPC.
local file, lnum, vcol, keys = arg[1], tonumber(arg[2]), tonumber(arg[3]), arg[4]

local nvim = vim.fn.jobstart({ 'nvim', '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' }, { rpc = true })
local function call(...) return vim.rpcrequest(nvim, ...) end

call('nvim_exec_lua', [[
  local file, lnum, vcol = ...
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(file))
  vim.o.selection = 'inclusive'
  vim.o.clipboard = ''
  local col = vim.fn.virtcol2col(0, lnum, vcol)
  vim.api.nvim_win_set_cursor(0, { lnum, math.max(col, 1) - 1 })
  vim.api.nvim_create_autocmd('TextYankPost', { callback = function()
    _G.yanked = { text = table.concat(vim.v.event.regcontents, '\n') }
  end })
]], { file, lnum, vcol })

call('nvim_input', keys)
local mode = call('nvim_get_mode')
local m = mode.mode

local out
if mode.blocking or m == 'no' or m:sub(1, 1) == 'c' then
  out = 'pending'
elseif m == 'v' or m == 'V' or m == '\22' then
  local sel = call('nvim_exec_lua', [[
    -- Not past the line's end (vi{ can end on the line break): tmux would
    -- go on to the next row.
    local function at(pos)
      local last = math.max(vim.fn.strdisplaywidth(vim.fn.getline(pos[2])), 1)
      return pos[2], math.min(vim.fn.virtcol({ pos[2], pos[3] }, 1)[1], last)
    end
    local l1, v1 = at(vim.fn.getpos('v'))
    local l2, v2 = at(vim.fn.getpos('.'))
    return { l1, v1, l2, v2 }
  ]], {})
  out = ('select %s %d %d %d %d'):format(m == '\22' and 'block' or m == 'V' and 'line' or 'char', unpack(sel))
else
  local yanked = call('nvim_exec_lua', 'return _G.yanked', {})
  out = yanked ~= vim.NIL and ('yank\n' .. yanked.text) or 'none'
end

vim.fn.jobstop(nvim)
io.stdout:write(out)
