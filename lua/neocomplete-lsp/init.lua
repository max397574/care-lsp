local lsp_source = {}

lsp_source.clients = {}

function lsp_source.setup()
    vim.api.nvim_create_autocmd("InsertEnter", {
        callback = function()
            -- TODO: always check if clients are from buf and not `is_stopped()`
            for _, client in ipairs(vim.lsp.get_clients()) do
                if not lsp_source.clients[client.id] then
                    local source = lsp_source.new(client)
                    if not source then
                        return
                    end
                    lsp_source.clients[client.id] = source
                    require("neocomplete.sources").register_source(source)
                end
            end
        end,
    })
end

---@param item lsp.CompletionItem
---@param defaults lsp.ItemDefaults
local function apply_defaults(item, defaults)
    if not defaults then
        return
    end
    ---@diagnostic disable-next-line: undefined-field
    item.commitCharacters = item.commitCharacters or defaults.commitCharacters
    if defaults.editRange then
        item.textEdit = item.textEdit or {}
        item.textEdit.newText = item.textEdit.newText or item.textEditText or item.insertText
        if defaults.editRange.insert then
            item.textEdit.insert = defaults.editRange.insert
            item.textEdit.replace = defaults.editRange.replace
        else
            item.textEdit.range = item.textEdit.range or defaults.editRange
        end
    end
    item.insertTextFormat = item.insertTextFormat or defaults.insertTextFormat
    item.insertTextMode = item.insertTextMode or defaults.insertTextMode
    item.data = item.data or defaults.data
end

--- @param result vim.lsp.CompletionResult
--- @return lsp.CompletionItem[]
local function get_items(result)
    if result.items then
        for _, item in ipairs(result.items) do
            ---@diagnostic disable-next-line: param-type-mismatch
            apply_defaults(item, result.itemDefaults)
        end
        return result.items
    else
        return result
    end
end

---@param client vim.lsp.Client
---@return neocomplete.source?
function lsp_source.new(client)
    if not client.server_capabilities.completionProvider then
        return nil
    end
    ---@type neocomplete.source
    local source = {
        -- TODO: name needs to be same for all clients to allow configuration
        name = "nvim-lsp " .. client.name,
        ---@param context neocomplete.completion_context
        complete = function(context, callback)
            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            params.context = context.completion_context
            ---@type lsp.CompletionItem
            local items
            local is_incomplete
            client.request(vim.lsp.protocol.Methods.textDocument_completion, params, function(err, result)
                if err then
                    vim.print(err)
                end
                if result then
                    if result.isIncomplete then
                        is_incomplete = true
                    end
                    items = get_items(result)
                end
                callback(items, is_incomplete)
            end)
        end,
        get_trigger_characters = function()
            return client.server_capabilities.completionProvider.triggerCharacters
        end,
        is_available = function()
            return not client.is_stopped()
        end,
    }
    return source
end

return lsp_source
