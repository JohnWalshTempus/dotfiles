return {

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
      }

      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil

      -- Only run linters whose executable is installed, so a missing tool
      -- (e.g. markdownlint on a fresh machine) doesn't error on every buffer.
      local function is_installed(name)
        local linter = lint.linters[name]
        if type(linter) == 'function' then
          linter = linter()
        end
        local cmd = type(linter) == 'table' and linter.cmd or nil
        if type(cmd) == 'function' then
          cmd = cmd()
        end
        return type(cmd) == 'string' and vim.fn.executable(cmd) == 1
      end

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          local names = {}
          for _, ft in ipairs(vim.split(vim.bo.filetype, '.', { plain = true })) do
            for _, name in ipairs(lint.linters_by_ft[ft] or {}) do
              if not vim.list_contains(names, name) and is_installed(name) then
                table.insert(names, name)
              end
            end
          end
          if #names > 0 then
            lint.try_lint(names)
          end
        end,
      })
    end,
  },
}
