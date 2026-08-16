-- Per-key debounce: a burst of calls within the window collapses into a
-- single run of the latest-requested callback. Shared by the indent-guide
-- and pattern-highlight redraws (lua/mars/ui/indent.lua, patterns.lua).

local M = {}

local pending = {}

--- Schedules `fn` to run after `ms`, superseded by a newer call for `key`.
---@param key any
---@param fn fun()
---@param ms? integer
function M.debounced(key, fn, ms)
  local generation = (pending[key] or 0) + 1
  pending[key] = generation
  vim.defer_fn(function()
    if pending[key] == generation then
      fn()
    end
  end, ms or 100)
end

--- Drops bookkeeping for `key`, e.g. when its window/buffer is closed.
---@param key any
function M.drop(key)
  pending[key] = nil
end

return M
