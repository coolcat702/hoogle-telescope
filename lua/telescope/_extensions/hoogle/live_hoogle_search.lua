local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local previewer_utils = require("telescope.previewers.utils")
local entry_display = require("telescope.pickers.entry_display")
local PreprocessJob = require("telescope._extensions.hoogle.preprocess_job")
local json = require("telescope._extensions.hoogle.json")

local function prompt_to_hoogle_cmd(opts)
	return function(_, prompt)
		if not prompt or prompt == "" then
			return nil
		end

		local count = opts.count or 50
		return {
			command = "hoogle",
			args = vim.iter({ "--json", "--count=" .. count, prompt }):flatten():totable(),
		}
	end
end

local function format_for_preview(doc)
	return doc:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp", "&")
end

local function show_preview(entry, buf)
	local docs = format_for_preview(entry.docs)
	local lines = vim.split(docs, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
	previewer_utils.highlighter(buf, "hoogle_telescope_doc")

	vim.api.nvim_buf_call(buf, function()
		local win = vim.fn.win_findbuf(buf)[1]
		vim.wo[win].conceallevel = 2
		vim.wo[win].wrap = true
		vim.wo[win].linebreak = true
		vim.bo[buf].textwidth = 80
	end)
end

local function make_display(entry)
	local module = entry.module_name

	local displayer = entry_display.create({
		separator = "",
		items = {
			{ width = module and #module + 1 or 0 },
			{ remaining = true },
		},
	})
	return displayer({ { module, "Include" }, { entry.type_sig, "Type" } })
end

local function entry_maker(data)
	return {
		valid = true,
		module_name = (data.module or {}).name,
		type_sig = data.item,
		url = data.url,
		docs = data.docs,
		display = make_display,
		ordinal = data.item .. data.url,
		preview_command = show_preview,
	}
end

local function preprocess_data(data)
	if data == "No results found" then
		return {}
	end
	return json.parse(data)
end

local function merge(...)
	return vim.tbl_extend("keep", ...)
end

local function copy_to_clipboard(text)
	local reg = vim.o.clipboard == "unnamedplus" and "+" or '"'
	vim.fn.setreg(reg, text)
end

local function open_browser(url)
	vim.cmd(":silent !xdg-open " .. vim.fn.fnameescape(url))
end

local function live_hoogle_search(opts)
	local finder = PreprocessJob:new({
		fn_command = prompt_to_hoogle_cmd(opts),
		fn_preprocess = preprocess_data,
		entry_maker = entry_maker,
	})

	pickers
		.new(opts, {
			prompt_title = "Hoogle search",
			finder = finder,
			previewer = previewers.display_content.new(opts),
			attach_mappings = function(buf, map)
				actions.select_default:replace(function()
					local entry = actions_state.get_selected_entry()
					copy_to_clipboard(entry.type_sig)
					actions.close(buf)
				end)
				map("i", "<C-o>", function()
					local entry = actions_state.get_selected_entry()
					open_browser(entry.url)
					actions.close(buf)
				end)

				return true
			end,
		})
		:find()
end

local function setup(opts)
	if vim.fn.executable("hoogle") == "1" then
		error("'hoogle' executable not found! Aborting.")
		return
	end

	opts = merge(opts or {}, {
		layout_strategy = "horizontal",
		layout_config = { preview_width = 40 },
	})

	live_hoogle_search(opts)
end

return setup
