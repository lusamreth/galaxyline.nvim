local vim = vim
local common = require('galaxyline.common')
local colors = require('galaxyline.colors')
local uv = vim.loop
local M = {}

M.section = {}
M.section.left = {}
M.section.right = {}
M.section.short_line_left = {}
M.section.short_line_right = {}
M.short_line_list = {}

local provider_group = {}
local async_load

-- why async load providers? because found the diagnostic providers
-- take a lot of startup time
async_load = uv.new_async(vim.schedule_wrap(function ()
  local vcs = require('galaxyline.provider_vcs')
  local fileinfo = require('galaxyline.provider_fileinfo')
  local buffer = require('galaxyline.provider_buffer')
  local extension = require('galaxyline.provider_extensions')
  local whitespace =require('galaxyline.provider_whitespace')
  provider_group = {
   BufferIcon  = buffer.get_buffer_type_icon,
   BufferNumber = buffer.get_buffer_number,
   FileTypeName = buffer.get_buffer_filetype,
   GitBranch = vcs.get_git_branch,
   DiffAdd = vcs.diff_add,
   DiffModified = vcs.diff_modified,
   DiffRemove = vcs.diff_remove,
   LineColumn = fileinfo.line_column,
   FileFormat = fileinfo.get_file_format,
   FileEncode = fileinfo.get_file_encode,
   FileSize = fileinfo.get_file_size,
   FileIcon = fileinfo.get_file_icon,
   FileName = fileinfo.get_current_file_name,
   SFileName = fileinfo.filename_in_special_buffer,
   LinePercent = fileinfo.current_line_percent,
   ScrollBar = extension.scrollbar_instance,
   VistaPlugin = extension.vista_nearest,
   WhiteSpace = whitespace.get_item,
  }
  local diagnostic = require('galaxyline.provider_diagnostic')
  provider_group.DiagnosticError = diagnostic.get_diagnostic_error
  provider_group.DiagnosticWarn = diagnostic.get_diagnostic_warn
  provider_group.DiagnosticHint = diagnostic.get_diagnostic_hint
  provider_group.DiagnosticInfo = diagnostic.get_diagnostic_info
  async_load:close()
end))

do
  if next(provider_group) == nil then
    async_load:send()
  end
end

local function check_component_exists(component_name)
  for _,pos_value in pairs(M.section) do
    for _,v in pairs(pos_value) do
      if v[component_name] ~= nil then
        return true,v[component_name]
      end
    end
  end
  return false,nil
end

local function exec_provider(icon,cmd)
  local output = cmd()
  if output == nil then return '' end
  if string.len(icon) ~= 0 and string.len(output) ~= 0 and output then
    return icon .. output
  end
  return output
end

-- component decorator
-- that will output the component result with icon
-- component provider and icon can be string or table
function M.component_decorator(component_name)
  -- if section doesn't have component just return
  local ok,component_info = check_component_exists(component_name)
  if not ok then
    print(string.format('Does not found this component: %s',component_name))
    return
  end
  local provider = component_info.provider or ''
  local icon = component_info.icon or ''

  local _switch = {
    ['string'] = function()
      if provider_group[provider] == nil then
        if next(provider_group) ~= nil then
          print(string.format('The provider of %s does not exist in default provider group',component_name))
          return ''
        end
        return ''
      end
      return exec_provider(icon,provider_group[provider])
    end,
    ['function'] = function()
      return exec_provider(icon,provider)
    end,
    ['table'] = function()
      local output = ''
      for _,v in pairs(provider) do
        if type(v) ~= 'string' and type(v) ~= 'function' then
          print(string.format('Wrong provider type in %s',component_name))
          return ''
        end

        if type(v) == 'string' then
          if type(provider_group[v]) ~= 'function' then
            if next(provider_group) ~= nil then
              print(string.format('Does not found the provider in default provider provider in %s',component_name))
              return ''
            end
            return ''
          end
          output = output .. exec_provider(icon,provider_group[v])
        end

        if type(v) == 'function' then
          output = output .. exec_provider(icon,v)
        end
      end
      return output
    end
  }

  local _switch_metatable = {
    __index = function(_type)
      return print(string.format('Type %s of provider does not support',_type))
    end
  }
  setmetatable(_switch,_switch_metatable)

  return _switch[type(provider)]()
end

local function generate_section(component_name)
  local line = ''
  line = line .. '%#'..'Galaxy'.. component_name..'#'
  line = line .. [[%{luaeval('require("galaxyline").component_decorator')]]..'("'..component_name..'")}'
  return line
end

local function generate_separator_section(component_name,separator)
  local separator_name = component_name .. 'Separator'
  local line = ''
  line = line .. '%#'..separator_name..'#' .. separator
  return line
end

local function section_complete_with_option(component,component_info,position)
  local tmp_line = ''
  -- get the component condition and dynamicswitch
  local condition = component_info.condition or nil
  local separator = component_info.separator or ''

  if condition ~= nil then
    if condition() then
      tmp_line = tmp_line .. generate_section(component)
      if string.len(separator) ~= 0 then
        if position == 'left' then
          tmp_line = tmp_line .. generate_separator_section(component,separator)
        else
          tmp_line = generate_separator_section(component,separator) .. tmp_line
        end
      end
    end
    return tmp_line
  end

  tmp_line = tmp_line .. generate_section(component)
  if string.len(separator) ~= 0 then
    if position == 'left' then
      tmp_line = tmp_line .. generate_separator_section(component,separator)
    else
      tmp_line = generate_separator_section(component,separator) .. tmp_line
    end
  end

  return tmp_line
end

local function load_section(section_area,pos)
  local section = ''
  if section_area ~= nil then
    for _,component in pairs(section_area) do
      for component_name,component_info in pairs(component) do
        local ls = section_complete_with_option(component_name,component_info,pos)
        section = section .. ls
      end
    end
  end
  return section
end

local function register_user_events()
  local user_events = {}
  for _,section in pairs(M.section) do
    for _,component_info in pairs(section) do
      local event = component_info['event'] or ''
      if string.len(event) > 0 then
        table.insert(user_events,event)
      end
    end
  end
  if next(user_events) == nil then return end
  common.nvim_create_augroups(user_events)
end

local async_combin
local short_line = ''

async_combin = uv.new_async(vim.schedule_wrap(function()
  local left_section = load_section(M.section.left,'left')
  local right_section = load_section(M.section.right,'right')
  local short_left_section = load_section(M.section.short_line_left,'left')
  local short_right_section = load_section(M.section.short_line_right,'right')
  local line = ''

  line = left_section .. '%=' .. right_section
  short_line =  short_left_section .. '%=' .. short_right_section

  if common.has_value(M.short_line_list,vim.bo.filetype) then
    line = short_line
  end

  vim.wo.statusline = line
end))

function M.load_galaxyline()
  async_combin:send()
  colors.init_theme(M.section)
  register_user_events()
end

function M.inactive_galaxyline()
  vim.wo.statusline = short_line
end

function M.init_colorscheme()
  colors.init_theme(M.section)
end

function M.disable_galaxyline()
  vim.wo.statusline = ''
  vim.api.nvim_command('augroup galaxyline')
  vim.api.nvim_command('autocmd!')
  vim.api.nvim_command('augroup END!')
end

function M.galaxyline_augroup()
  local events = { 'ColorScheme', 'FileType','BufWinEnter','BufReadPost','BufWritePost',
                  'BufEnter','WinEnter','FileChangedShellPost','VimResized','TermOpen'}
  vim.api.nvim_command('augroup galaxyline')
  vim.api.nvim_command('autocmd!')
  for _, def in ipairs(events) do
    local command = string.format('autocmd %s * lua require("galaxyline").load_galaxyline()',def)
    vim.api.nvim_command(command)
  end
  vim.api.nvim_command('autocmd WinLeave * lua require("galaxyline").inactive_galaxyline()')
  vim.api.nvim_command('augroup END')
end

return M
