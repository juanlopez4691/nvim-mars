-- Native file explorer: netrw restyled as a tree-view sidebar. See
-- AGENTS.md's Native-First Philosophy: netrw already covers what a sidebar
-- file tree needs, so no plugin is added for this.

-- Netrw reads these globals the first time one of its buffers is created,
-- which happens lazily on first use, but this module loads during init
-- (see lua/mars/core/), well before that, so setting them here is early
-- enough. Kept short; each earns its place:
vim.g.netrw_liststyle = 3 -- tree-style listing instead of the flat one-name-per-line default
vim.g.netrw_banner = 0 -- drop the verbose help banner; more room for the tree itself
vim.g.netrw_winsize = -30 -- fixed 30-column sidebar rather than the default 50% of the window

--- Finds the window currently showing a netrw buffer, if any. Netrw buffers
--- keep 'buftype' empty and only identify themselves via 'filetype' (see
--- lua/mars/ui/winbar.lua for the same convention), so detection goes
--- through that rather than a buffer name pattern.
---@return integer?
local function explorer_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "netrw" then
      return win
    end
  end
  return nil
end

--- Whether the sidebar belongs on the right, per `vim.g.mars_explorer_position`
--- ("left" by default, "right" to flip it). Netrw spells that as :Lexplore's
--- bang, which also points |g:netrw_chgwin| at window 1 so opened files
--- still land in the main window rather than beside the tree.
---
--- Read on each open, never memoized: lua/mars/local.lua (where the global
--- is actually set) loads after this module, so an upvalue captured here
--- would freeze to the default (see AGENTS.md's Icons section for the same
--- rule).
---@return boolean
local function on_right()
  return vim.g.mars_explorer_position == "right"
end

--- Opens the sidebar on the configured side if no netrw window is open
--- anywhere, rooted at `dir` when given; otherwise does nothing, leaving the
--- existing one in place. Netrw is only ever allowed this one window, so
--- every entry point below converges here.
---@param dir string|nil Root directory for a freshly opened sidebar.
local function open_explorer(dir)
  if explorer_win() then
    return
  end
  -- The `:Lexplore` command is redefined below to route here, so call the
  -- autoload function directly rather than recursing through the command.
  vim.fn["netrw#Lexplore"](0, on_right() and 1 or 0, dir or "")
end

--- Toggles the sidebar: closes it if a netrw window is already open,
--- otherwise opens one as a vertical split on the configured side. Always
--- looks the window up by filetype rather than assuming a window number, so
--- this stays correct no matter what other splits are open, and repeated
--- toggles never stack a second netrw window.
local function toggle_explorer()
  local win = explorer_win()
  if win then
    vim.api.nvim_win_close(win, false)
    return
  end
  open_explorer()
end

--- Opens the sidebar rooted at the current buffer's directory. Reuses an
--- already-open sidebar in place (navigating it) instead of opening a
--- second one.
local function explore_current_file()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    -- getcwd() rather than vim.uv.cwd(): it can't fail (so `dir` stays a
    -- plain string all the way to netrw), and it honours a window- or
    -- tab-local :lcd, which is the directory the user is actually working
    -- in. Matches how the rest of Mars falls back: see lua/mars/lang/
    -- format.lua and lua/mars/core/rootdir.lua.
    dir = vim.fn.getcwd()
  end

  local win = explorer_win()
  if win then
    vim.api.nvim_set_current_win(win)
    -- Navigate the existing sidebar in place rather than recursing through
    -- the redefined :Explore command (which would no-op while a netrw window
    -- is open). netrw#Explore's first arg is the count, which the :Explore
    -- command would have filled from `-count`.
    vim.fn["netrw#Explore"](0, 0, 0, dir)
    return
  end
  open_explorer(dir)
end

--- Netrw's window-creating commands (:Explore, :Sexplore, ...) each open a
--- netrw window in a different layout, the split multiplication this module
--- exists to prevent. All of them are redefined to converge on the single
--- sidebar: open it on the configured side if none is open, do nothing
--- otherwise.
local EXPLORE_COMMANDS = { "Explore", "Sexplore", "Vexplore", "Hexplore", "Lexplore", "Texplore" }

--- Replaces the netrw explore commands with `open_explorer`. Netrw defines
--- them with `command!`, so it clobbers overrides that came earlier; this
--- must run after netrw's plugin loads, which is why it is called both
--- eagerly at require time (covering :source reloads) and again on VimEnter
--- (covering first startup, where netrw loads between the two). Each pass
--- deletes the previous definition first, whatever it is.
local function redefine_explore_commands()
  for _, name in ipairs(EXPLORE_COMMANDS) do
    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, function(cmd)
      open_explorer(cmd.args)
    end, { nargs = "*", bang = true, bar = true, complete = "dir" })
  end
end

redefine_explore_commands()

vim.keymap.set("n", "<leader>e", toggle_explorer, { desc = "Explorer: toggle sidebar" })
vim.keymap.set("n", "<leader>E", explore_current_file, { desc = "Explorer: open at current file" })

--- Nesting depth of a tree-listing line: netrw prefixes each level with
--- "| " under `netrw_liststyle = 3` (`| | mars/` is two levels deep).
---@param line string
---@return integer
local function tree_depth(line)
  local indent = line:match("^[| ]*")
  return math.floor(#indent / 2)
end

--- Whether the cursor sits on an unfolded directory, the one state where
--- netrw's <CR> folds rather than opens, so both keymaps below branch on
--- it. Netrw does track its expanded set in `w:netrw_treedict`, but keyed
--- by absolute path, which would mean rebuilding the current line's path
--- from its ancestors; the listing already encodes the answer, since a
--- directory's children are the lines directly below it, one level deeper.
---
--- A file never has children, so deeper lines below imply a directory and
--- this doubles as the "is this a directory" test. Keeping it off netrw's
--- trailing-slash convention also sidesteps the `ls -F` decorations that
--- convention doesn't survive (`name@ --> target` for symlinks, `name*`
--- for executables).
---
--- Reads false in the flat list styles (no "| " prefixes, so nothing is
--- ever deeper), which is what makes `l` fall through to plain "enter this
--- directory" there.
---@return boolean
local function on_unfolded_dir()
  local lnum = vim.fn.line(".")
  local next_line = vim.fn.getline(lnum + 1)

  return next_line ~= "" and tree_depth(next_line) > tree_depth(vim.fn.getline(lnum))
end

--- Last window focused before the sidebar, per tab (see the WinEnter tracker
--- below); split-opens land there instead of in the netrw window.
---@type table<integer, integer>
local last_main = {}

--- Window a split-open should land in: the last non-netrw window focused in
--- this tab (WinEnter tracker), falling back to the previous window and then
--- to any non-netrw window. Never the sidebar.
---@return integer win
local function split_target()
  local tab = vim.api.nvim_get_current_tabpage()
  local target = last_main[tab]
  if not (target and vim.api.nvim_win_is_valid(target)) then
    vim.cmd("wincmd p")
    target = vim.api.nvim_get_current_win()
  end
  if vim.bo[vim.api.nvim_win_get_buf(target)].filetype == "netrw" then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "netrw" then
        target = win
        break
      end
    end
  end
  return target
end

--- Netrw's <CR> opens the file into the window `g:netrw_chgwin` names;
--- pointing it at `target_win` redirects the open there. Netrw reads chgwin
--- while the <CR> runs, so "x" keeps it in effect through the feed. The
--- sidebar must be focused when called.
---@param target_win integer
local function feed_open(target_win)
  local prev = vim.g.netrw_chgwin
  vim.g.netrw_chgwin = vim.fn.win_id2win(target_win)
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "mtx", false)
  vim.g.netrw_chgwin = prev
end

--- Triggers netrw's own <CR> on the current line, to open a file or toggle
--- a directory's fold. Fed remappably rather than calling a netrw function,
--- so local and remote listings both work. File opens land in the last
--- active window (feed_open) instead of :Lexplore's window 1; the sidebar
--- is re-asserted since split_target's fallback runs `wincmd p`.
local function activate()
  local netrw_win = vim.api.nvim_get_current_win()
  local target = split_target()
  vim.api.nvim_set_current_win(netrw_win)
  feed_open(target)
end

--- `l`: unfolds the directory under the cursor, or opens the file under
--- it. No-op on an already-unfolded directory; <CR> toggles, so passing
--- it through there would fold what the user asked to open.
local function unfold_or_open()
  if not on_unfolded_dir() then
    activate()
  end
end

--- Line number of the foldable directory containing the current line: the
--- nearest line above it at a shallower indent level. Nil at the top
--- level, where there's nothing left to fold into.
---@return integer?
local function parent_line()
  local lnum = vim.fn.line(".")
  local depth = tree_depth(vim.fn.getline(lnum))

  for n = lnum - 1, 1, -1 do
    local parent_depth = tree_depth(vim.fn.getline(n))
    if parent_depth < depth then
      -- Depth 0 is the tree root, which has no folded state to reach:
      -- netrw always lists its children, so <CR> there merely re-lists the
      -- tree and drops the cursor back on "../".
      return parent_depth > 0 and n or nil
    end
  end
  return nil
end

--- `o`/`v`: open the file under the cursor in a split of the last active
--- window, never the sidebar. `o` splits horizontally, `v` (netrw's own
--- vertical-split key) vertically. Netrw's split keys split the netrw window
--- itself, so this creates the split in the main window first and points
--- `g:netrw_chgwin` at it, then lets netrw's own <CR> (which knows tree
--- paths, symlinks and decorations) open the file into it. Directories keep
--- netrw's <CR> (navigate in place), so no second netrw window appears.
---@param vertical boolean
local function open_in_split(vertical)
  local word = vim.fn.getline("."):gsub("^[| ]*", ""):gsub("\t.*$", "")
  if word == "" or word:sub(-1) == "/" then
    activate()
    return
  end
  local netrw_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(split_target())
  -- A fresh, unmodified buffer in the split, so netrw will edit the file
  -- into it even when the main buffer has unsaved changes.
  vim.cmd(vertical and "vsplit" or "split")
  vim.cmd("enew")
  local split_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(netrw_win)
  feed_open(split_win)
end

--- Netrw keymap reference, shown by `?` in the sidebar. Covers the
--- day-to-day keys; the Mars deviations from stock netrw are called out
--- (`o`/`v` open in the last active window, not the sidebar).
local NETRW_HELP = {
  "  Mars netrw keymaps",
  "  " .. string.rep("─", 24),
  "",
  "  Browse",
  "    <CR>  open file / enter directory",
  "    h     fold directory",
  "    l     unfold directory / open file",
  "    -     go up one directory",
  "    u/U   history back / forward",
  "",
  "  Open",
  "    o     horizontal split (last active window)",
  "    v     vertical split (last active window)",
  "    P     previous window",
  "    p     preview",
  "    t     new tab",
  "    O     obtain (copy file into cwd)",
  "",
  "  Files",
  "    %     new file",
  "    d     new directory",
  "    D     delete",
  "    R     rename",
  "",
  "  Display",
  "    i     listing style",
  "    I     toggle banner",
  "    a     toggle hidden files",
  "    s     sort by",
  "    cd    make browsed dir the cwd",
  "",
  "  Mark",
  "    mf    mark / unmark file",
  "    mc    copy marked",
  "    mm    move marked",
  "    mu    unmark all",
  "",
  "  ?  this help     q / <Esc>  close",
}

--- Shows the netrw keymap reference in a centered floating window.
--- Dismissible with `q`/`<Esc>`.
local function show_netrw_help()
  require("mars.helpers.popup").show(NETRW_HELP)
end

--- Namespace for the tree-line overlay (see draw_tree_lines).
local tree_ns = vim.api.nvim_create_namespace("mars_netrw_tree")

--- Overlay pieces for one indent level. Each is exactly two cells wide, so
--- it covers netrw's own two-character "| " unit and nothing else; the
--- entry names keep their columns. Plain box-drawing characters rather
--- than Nerd Font glyphs, so this needs no `vim.g.have_nerd_font` gate
--- (see AGENTS.md's Icons section).
local BAR = "│ " -- an ancestor directory continues past this line
local GAP = "  " -- ... and doesn't
local BRANCH = "├─" -- an entry with more entries below it
local LAST_BRANCH = "└─" -- the last entry of its directory

--- Redraws `buf`'s tree lines. Netrw indents each level with "| ", which
--- reads as a column of disconnected pipes; this overlays every indent
--- unit with box-drawing characters that actually join up: bars running
--- through the directories that continue below, a corner on each
--- directory's last entry.
---
--- Drawn as extmarks rather than by rewriting the lines because netrw
--- parses those "| " prefixes back into real paths when an entry is opened
--- (s:NetrwTreePath in its source), so the text itself has to stay put.
---@param buf integer
local function draw_tree_lines(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, tree_ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Whether the directory opened at each level still has entries below the
  -- line being drawn, and so needs its bar carried through it. Walking the
  -- listing bottom-up is what makes that answerable in one pass: a level
  -- is "continuing" exactly while entries at that depth are still behind
  -- us, and any shallower line ends every level below it.
  local continues = {}
  local deepest = 0

  for lnum = #lines, 1, -1 do
    local line = lines[lnum]
    local depth = tree_depth(line)

    if depth > 0 then
      local pieces = {}
      for level = 1, depth - 1 do
        pieces[level] = continues[level] and BAR or GAP
      end

      if line:match("^[| ]*$") then
        -- Netrw pads an unfolded but empty directory with an indent-only
        -- line; branching into a name that isn't there looks like a bug.
        pieces[depth] = GAP
      else
        pieces[depth] = continues[depth] and BRANCH or LAST_BRANCH
      end

      vim.api.nvim_buf_set_extmark(buf, tree_ns, lnum - 1, 0, {
        virt_text = { { table.concat(pieces), "netrwTreeBar" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end

    continues[depth] = true
    for level = depth + 1, deepest do
      continues[level] = false
    end
    deepest = math.max(deepest, depth)
  end
end

--- `h`: folds the directory under the cursor, or on a file or an
--- already-folded directory, where there's nothing to fold in place,
--- folds the directory that contains it, leaving the cursor on that
--- directory so repeated presses walk back up the tree. That parent is
--- necessarily unfolded, since the line the cursor started on is one of
--- the children it's showing.
local function fold()
  if on_unfolded_dir() then
    activate()
    return
  end

  local parent = parent_line()
  if not parent then
    return
  end

  vim.api.nvim_win_set_cursor(0, { parent, 0 })
  activate()
end

-- The tree reads fine without file-type glyphs, so there's no icon table to
-- gate behind vim.g.have_nerd_font here (see AGENTS.md's Icons section);
-- this only trims window chrome the sidebar doesn't need.
local group = vim.api.nvim_create_augroup("mars_netrw", { clear = true })

-- Netrw's plugin loads after this module at startup and redefines its
-- explore commands with `command!`, so re-assert the override once everything
-- is sourced (see redefine_explore_commands).
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  desc = "Route netrw's window-creating commands to the single sidebar",
  callback = redefine_explore_commands,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = group,
  desc = "Track the last non-netrw window for split-opens",
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "netrw" then
      last_main[vim.api.nvim_get_current_tabpage()] = win
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "netrw",
  desc = "Trim window chrome the tree sidebar doesn't need and pin its width",
  callback = function(args)
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.list = false
    -- The sidebar is a deliberate fixed 30 columns (netrw_winsize above),
    -- so exempt it from window equalization, both the manual `<C-w>=` and
    -- the automatic one on terminal resize (lua/mars/core/splits.lua),
    -- which would otherwise stretch it to an even share of the screen.
    vim.wo.winfixwidth = true

    -- This buffer browses a local directory. Netrw only ever sets
    -- `b:netrw_islocal` in its mark-file path, so without this its own
    -- obtain (`O`) always takes the remote branch, which crashes in the
    -- bundled runtime (E118 in netrw#msg#Notify) instead of copying.
    vim.b[args.buf].netrw_islocal = 1

    -- Netrw maps <C-l> buffer-locally to <Plug>NetrwRefresh, which shadows
    -- the global split-navigation keymap (lua/mars/core/splits.lua) and,
    -- from a sidebar, re-lists the tree into the neighbouring window
    -- instead of moving focus there. Dropping the buffer-local map lets
    -- the global <C-l> through; refresh stays reachable via <Plug>NetrwRefresh
    -- and by re-entering the directory. Only <C-l> collides today, but the
    -- whole set is swept so a future netrw mapping can't reintroduce this.
    for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
      pcall(vim.keymap.del, "n", key, { buffer = args.buf })
    end

    -- Tree navigation on h/l, alongside netrw's own <CR> (which keeps
    -- doing all three, since it toggles).
    vim.keymap.set("n", "l", unfold_or_open, {
      buffer = args.buf,
      desc = "Explorer: unfold directory or open file",
    })
    vim.keymap.set("n", "h", fold, { buffer = args.buf, desc = "Explorer: fold directory" })
    vim.keymap.set("n", "?", show_netrw_help, {
      buffer = args.buf,
      desc = "Explorer: show keymap help",
    })
    vim.keymap.set("n", "<Esc>", toggle_explorer, {
      buffer = args.buf,
      desc = "Close sidebar",
    })

    -- Netrw rewrites the whole listing on every fold, unfold and refresh,
    -- so the overlay follows the buffer's own changes rather than the
    -- events behind them; netrw's <CR> and its refresh never pass through
    -- this module. Scheduled because on_lines runs in a context where
    -- extmark calls aren't allowed, and coalesced because netrw rewrites a
    -- listing line by line. FileType fires more than once per netrw
    -- buffer, so the attach guard.
    if not vim.b[args.buf].mars_netrw_tree then
      vim.b[args.buf].mars_netrw_tree = true

      local queued = false
      vim.api.nvim_buf_attach(args.buf, false, {
        on_lines = function(_, buf)
          -- Re-assert `o`/`v` on every listing write, synchronously: netrw
          -- maps them buffer-locally before each render (after FileType), so
          -- this must land after netrw's own maps. `O` (obtain) stays on
          -- netrw's own mapping.
          vim.keymap.set("n", "o", function()
            open_in_split(false)
          end, {
            buffer = buf,
            desc = "Explorer: horizontal split (last window)",
          })
          vim.keymap.set("n", "v", function()
            open_in_split(true)
          end, {
            buffer = buf,
            desc = "Explorer: vertical split (last window)",
          })
          if queued then
            return
          end
          queued = true
          vim.schedule(function()
            queued = false
            draw_tree_lines(buf)
          end)
        end,
      })
    end

    draw_tree_lines(args.buf)
  end,
})
