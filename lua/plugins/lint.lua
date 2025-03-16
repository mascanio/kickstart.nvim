return {
  {
    'mfussenegger/nvim-lint',
    -- event = 'LazyFile',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      -- Event to trigger linters
      events = { 'BufWritePost', 'BufReadPost', 'InsertLeave' },
      linters_by_ft = {
        fish = { 'fish' },
        -- Use the "*" filetype to run linters on all filetypes.
        -- ['*'] = { 'global linter' },
        -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
        -- ['_'] = { 'fallback linter' },
        -- ["*"] = { "typos" },
      },
      -- LazyVim extension to easily override linter options
      -- or add custom linters.
      ---@type table<string,table>
      linters = {
        -- -- Example of using selene only when a selene.toml file is present
        -- selene = {
        --   -- `condition` is another LazyVim extension that allows you to
        --   -- dynamically enable/disable linters based on the context.
        --   condition = function(ctx)
        --     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
        --   end,
        -- },
      },
    },
    config = function(_, opts)
      local M = {}

      local lint = require 'lint'
      for name, linter in pairs(opts.linters) do
        if type(linter) == 'table' and type(lint.linters[name]) == 'table' then
          lint.linters[name] = vim.tbl_deep_extend('force', lint.linters[name], linter)
          if type(linter.prepend_args) == 'table' then
            lint.linters[name].args = lint.linters[name].args or {}
            vim.list_extend(lint.linters[name].args, linter.prepend_args)
          end
        else
          lint.linters[name] = linter
        end
      end
      lint.linters_by_ft = opts.linters_by_ft

      function M.debounce(ms, fn)
        local timer = vim.uv.new_timer()
        return function(...)
          local argv = { ... }
          timer:start(ms, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(unpack(argv))
          end)
        end
      end

      function M.lint()
        -- Use nvim-lint's logic first:
        -- * checks if linters exist for the full filetype first
        -- * otherwise will split filetype by "." and add all those linters
        -- * this differs from conform.nvim which only uses the first filetype that has a formatter
        local names = lint._resolve_linter_by_ft(vim.bo.filetype)

        -- Create a copy of the names table to avoid modifying the original.
        names = vim.list_extend({}, names)

        -- Add fallback linters.
        if #names == 0 then
          vim.list_extend(names, lint.linters_by_ft['_'] or {})
        end

        -- Add global linters.
        vim.list_extend(names, lint.linters_by_ft['*'] or {})

        -- Filter out linters that don't exist or don't match the condition.
        local ctx = { filename = vim.api.nvim_buf_get_name(0) }
        ctx.dirname = vim.fn.fnamemodify(ctx.filename, ':h')
        names = vim.tbl_filter(function(name)
          local linter = lint.linters[name]
          -- if not linter then
          --   LazyVim.warn('Linter not found: ' .. name, { title = 'nvim-lint' })
          -- end
          return linter and not (type(linter) == 'table' and linter.condition and not linter.condition(ctx))
        end, names)

        -- Run linters.
        if #names > 0 then
          lint.try_lint(names)
        end
      end

      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup('nvim-lint', { clear = true }),
        callback = M.debounce(100, M.lint),
      })
    end,
  },
}
--
-- return {
--
--   { -- Linting
--     'mfussenegger/nvim-lint',
--     event = { 'BufReadPre', 'BufNewFile' },
--     config = function()
--       local lint = require 'lint'
--       lint.linters_by_ft = {
--         markdown = { 'markdownlint' },
--       }
--
--       -- To allow other plugins to add linters to require('lint').linters_by_ft,
--       -- instead set linters_by_ft like this:
--       -- lint.linters_by_ft = lint.linters_by_ft or {}
--       -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
--       --
--       -- However, note that this will enable a set of default linters,
--       -- which will cause errors unless these tools are available:
--       -- {
--       --   clojure = { "clj-kondo" },
--       --   dockerfile = { "hadolint" },
--       --   inko = { "inko" },
--       --   janet = { "janet" },
--       --   json = { "jsonlint" },
--       --   markdown = { "vale" },
--       --   rst = { "vale" },
--       --   ruby = { "ruby" },
--       --   terraform = { "tflint" },
--       --   text = { "vale" }
--       -- }
--       --
--       -- You can disable the default linters by setting their filetypes to nil:
--       -- lint.linters_by_ft['clojure'] = nil
--       -- lint.linters_by_ft['dockerfile'] = nil
--       -- lint.linters_by_ft['inko'] = nil
--       -- lint.linters_by_ft['janet'] = nil
--       -- lint.linters_by_ft['json'] = nil
--       -- lint.linters_by_ft['markdown'] = nil
--       -- lint.linters_by_ft['rst'] = nil
--       -- lint.linters_by_ft['ruby'] = nil
--       -- lint.linters_by_ft['terraform'] = nil
--       -- lint.linters_by_ft['text'] = nil
--
--       -- Create autocommand which carries out the actual linting
--       -- on the specified events.
--       local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
--       vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
--         group = lint_augroup,
--         callback = function()
--           -- Only run the linter in buffers that you can modify in order to
--           -- avoid superfluous noise, notably within the handy LSP pop-ups that
--           -- describe the hovered symbol using Markdown.
--           if vim.opt_local.modifiable:get() then
--             lint.try_lint()
--           end
--         end,
--       })
--     end,
--   },
-- }
