-- 
-- (c) 2024, github.com/hipBali
--

-- external files
local API_PATH, API_URL, TEMP_PATH
local TITLE = "Resty Test Ui"
local _TEMP_PATH = "/gen-ui/"
local TEMP_LIST = "tmpl_list.html"
local TEMP_ITEM = "tmpl_item.html"
local TEMP_FORM = "tmpl_form.html"

-- constants
local DEFAULT_CFG = "default_config"
local DEFAULT_CTYPE = "application/json"

-- requirements
local json = require "cjson"
local function file_load(filename)
	local file,err=io.open(filename, "rb")
	if not err then
		local data = file:read("*a")
		file:close()
		return data
	else
		-- ngx.log(ngx.ERR,"File open error: "..tostring(err))
	end
end
local json_decode = function (s, catch)
	local success, res = pcall(json.decode, s);
	if not success then
		ngx.log(ngx.ERR,"JSON decode: "..tostring(res))
	end
	return res
end
local json_encode = function (t, catch)
	local success, res = pcall(json.encode, t);
	if not success then
		ngx.log(ngx.ERR,"JSON encode: "..tostring(res))
	end
	return res
end
local function table_locate( tab, token ) 
    for key in pairs( tab ) do
        if key == token then  
            return tab[key]
        end  
    end  
	for key in pairs( tab ) do
		if type( tab[key] ) == 'table' then  
           return table_locate( tab[key], token ) 
        end  
    end
end
local function sort_yaml( text , level, filter )
	local lines = {}
    for line in text:gmatch("[^\r\n]+") do
		local _, spaces = line:find("^(%s*)")
		if line:len()>spaces then
			table.insert(lines, { line = line, spaces = spaces })
		end
    end
	local smallestIndents = {}
	local top_n = {}
    for i = 1, #lines do
		local used = false
		for n,s in pairs(top_n) do
			used = top_n[n] == lines[i].spaces or used
			if used then break end
		end
		if not used then
			if #top_n == 0 or (#top_n < level+1 and lines[i].spaces >= top_n[#top_n]) then
				table.insert(top_n,lines[i].spaces)
			elseif lines[i].spaces < top_n[#top_n] then
				top_n[#top_n] = lines[i].spaces
			end
		end
    end
	top_n[#top_n] = nil -- remove tmp
	for k,v in pairs(top_n) do
		smallestIndents[v]=k
	end
	local res = {}
	local flt_level
    for _, entry in ipairs(lines) do
        if smallestIndents[entry.spaces] then
            local indent, key, value = entry.line:match("^(%s*)([*/%w_-]+):%s*(.*)$")
			local idx = smallestIndents[entry.spaces]
			if filter then
				-- end?
				if flt_level and flt_level>=idx then
					break
				end
				-- start
				if key == filter then
					flt_level = idx
				end
				if flt_level and flt_level<idx then
					table.insert(res, {key=key,level=idx})
				end
			else
				table.insert(res, {key=key,level=idx})
			end
        end
    end
	return res
end

local m = {}

string.tk = function(self,tkn,value)
	local src = self
	local _TKNID = "{{%s}}"
	if type(tkn) == "table" then
		for k,v in pairs(tkn) do
			src = src:gsub(string.format(_TKNID,k),v) 
		end
		return src
	else
		return src:gsub(string.format(_TKNID,tkn),value) 
	end
end

local function add_label(t, itm, asis)
	local sep = asis and "" or ":"
	-- label
	table.insert( t, string.format('<label for="%s">%s%s</label>',itm.name,itm.label or itm.name,sep) )
	return t
end

local function parse_attr(s,attr, itm)
	for k,v in pairs(attr) do
		s = s .. string.format(' %s="%s"', k,v)
	end
	-- style attrs
	if itm.style then
		s = s .. string.format(' style="%s" ',itm.style) 
	end
	s = s .. ">"
	return s
end

local function add_input(t, itm)
	-- input
	local attr = { type=itm.type or "text", id=itm.id or itm.name, 
		name=itm.name, placeholder=itm.example, value=itm.value }
	local s = parse_attr('<input class="form-control" ', attr, itm)
	table.insert( t, s )
	return t
end

local function add_select(t, itm)
	-- select
	local attr = { id=itm.name, name=itm.name, placeholder=itm.example }
	local s = parse_attr('<select class="form-control" ', attr, itm)
	table.insert( t, s )
	return t
end

-- GET/POST form generator
local function make_form(all_config, params, cfgfile)
	
	local config = {}
	local opt = params 
	local frm = file_load(TEMP_PATH..TEMP_FORM)
	
	local paths = {} -- current config
	local fdata = {} -- table for labels and input
	local pdata = {} -- table for entered value
	local sdata = {} -- table for servers
	
	-- loads all config
	for path, c in pairs(all_config.paths) do
		for method,itm in pairs(c or {}) do
			itm.path = path
			itm.method = method:lower()
			config[method..path] = itm
		end
	end
	-- params contains the table index mathod+path
	local key = (opt.method or ""):lower() .. "/".. (opt.path or "")
	config = config[key]
	if not config then
		return "<b>Invalid index</b>"
	end
	-- list servers
	local server_url = API_URL
	local servers = {}
	if all_config.servers and all_config.servers[1] then
		server_url = all_config.servers[1].url or API_URL
		servers = all_config.servers
	end
	table.insert(servers, 1, {url=server_url, description="Default server"} )
	for _,v in pairs(servers) do
		local desc = v.description and v.description..": " or ""
		local item = v.url and desc..v.url or API_URL
		table.insert( sdata, string.format('<option value="%s">%s</option>', v.url or API_URL,item))
	end
	-- Content type
	local content_type = DEFAULT_CTYPE
	local request_data = {}
	-- get parameters
	if config.method == "get" and config.parameters then
		local params = config.parameters
		if #params>0 then
			for _,p in pairs(params) do
				table.insert(request_data,{})		
				for key,value in pairs(p) do
					-- process schema
					if type(value)=="table" then
						for k,v in pairs(value) do
							request_data[#request_data][k]=v	
						end
					else
						request_data[#request_data][key]=value	
					end
				end
			end
		end
		
	end
	-- post requestbody
	if config.method == "post" then 
		if config.requestBody then
			local params = table_locate(config.requestBody,"schema").properties  or {}
			if #params > 0 then
				for key,p in pairs(params) do
					table.insert(request_data,{name=key})
					for k,v in pairs(p) do
						request_data[#request_data][k]=v
					end
				end
			else
				-- add input for json or text 
				table.insert( fdata, '<div class="row form-group">')
				table.insert( fdata, '<label for="postData">Post data:</label>' )
				table.insert( fdata, [[ 
					<textarea id="postData" placeholder="Content goes here ..."
						style="flex-grow: 1; height: 60px; border: 1px solid #ccc; border-radius: 5px; padding: 5px; width: auto;"></textarea>
				]])
				table.insert( fdata, '</div>')
				if content_type == DEFAULT_CTYPE then
					pdata = "const data = JSON.parse(document.getElementById('postData').value);"
				else
					pdata = "const data = document.getElementById('postData').value;"
				end
			end
		end
	end

	local uni_idx = 1
	for id,itm in pairs(request_data) do
		-- FORMDATA group	
			table.insert( fdata, '<div class="row form-group">')
			-- type fix
			itm.type = itm.type == "string" and itm.enum and itm["x-tui-type"] =="radio" and "radio" or itm.type
			itm.type = itm.type == "string" and itm.enum and itm["x-tui-type"] =="checkbox" and "checkbox" or itm.type
			itm.type = itm.type == "string" and itm.enum and "select" or itm.type
			itm.type = itm.type == "string" and "text" or itm.type
			itm.type = itm.type == "integer" and "number" or itm.type
			itm.type = itm.type == "boolean" and "checkbox" or itm.type
			-- formats
			local p_fmt_types = {email=1,uuid=1,date=1,["date-time"]=1,password=1,uri=1,hostname=1,html=1}
			itm.type = p_fmt_types[itm.format] and itm.format or itm.type

			-- labels
			local labels = {}
			itm.label = itm["x-tui-label"] or itm.name
			if itm.enum and itm["x-tui-enum"] then
				local lbl = itm["x-tui-enum"]
				if type(lbl) == "table" then
					labels = lbl
				end
			end
			
			-- style patch
			itm.style = itm["x-tui-style"]
			
			-- radio button or checkbox group
			local cb_group = {}
			if itm.enum and (itm.type == "radio" or itm.type == "checkbox") then
				table.insert( fdata, string.format('<label for="%s">%s:</label>',itm.name,itm.label) )
				table.insert( fdata, string.format('<div class="%s-group">',itm.type))
				for n,v in pairs(itm.enum) do
					-- uni_idx = uni_idx + 1
					-- itm.name..uni_idx
					local elem = { id=v, name=itm.name, value=v, type=itm.type, example=itm.example }
					fdata = add_input(fdata, elem)
					table.insert(cb_group, elem )
					fdata = add_label(fdata, { name=v, label=labels[n] or v }, true )
				end
				table.insert( fdata, '</div>')
			-- select
			elseif itm.enum and itm.type == "select" then
				table.insert( fdata, string.format('<label for="%s">%s:</label>',itm.name,itm.label) )
				fdata = add_select(fdata, itm)
				for n,v in pairs(itm.enum) do
					-- uni_idx = uni_idx + 1
					table.insert( fdata, string.format(
						'<option id="%s"value="%s">%s</option>', 
						v,v,labels[n] or v)
					)
				end
				table.insert( fdata, '</select>')
			-- checkbox
			elseif itm.type == "checkbox" then
				fdata = add_label(fdata, itm)
				fdata = add_input(fdata, itm)
			-- generic
			else
				fdata = add_label(fdata, itm)
				fdata = add_input(fdata, itm)
			end
			table.insert( fdata, '</div>')

		-- Postdata javasctip injection
		
			if itm.type == "number" then
				table.insert(pdata, string.format("%s: Number(document.getElementById('%s').value)", itm.name, itm.name))
			elseif itm.type == "radio" then
				table.insert(pdata, string.format("%s: document.querySelector('input[name="..'"%s"'.."]:checked')?.value || null", itm.name, itm.name))
			elseif itm.type == "checkbox" then
				if #cb_group>0 then
					for _,elem in pairs(cb_group) do
						table.insert(pdata, string.format("%s: document.getElementById('%s').checked", elem.id, elem.id))
					end
				else
					table.insert(pdata, string.format("%s: document.getElementById('%s').checked", itm.name, itm.name))
				end
			else
				table.insert(pdata, string.format("%s: document.getElementById('%s').value", itm.name, itm.name))
			end
	end
	
	-- get post parameters to string
	if type(pdata)=="table" then
		pdata = "const data = {\n"..table.concat(pdata,",\n").."\n};\n" 
	end

	local parsed_form = frm:tk {
		API_URL = server_url,
		API_PATH = config.path,
		TESTUI_PATH = API_URL,
		TITLE = TITLE,
		FORMNAME = config.summary or config.description or config.path,
		METHOD = config.method:upper(),
		FORMDATA = table.concat(fdata,"\n"),
		JSONDATA = pdata,
		POST_CONTENT_TYPE = content_type,
		SERVERS = table.concat(sdata,",\n"),
		USE_TOKEN = config.security and "" or "hidden",
		CONFIG = cfgfile
	} 
	return parsed_form
end

-- list of paths generator
local function make_menu(all_config, order, cfgfile)
	tui_config = {}
	local lst = file_load(TEMP_PATH..TEMP_LIST)
	local list_item = file_load(TEMP_PATH..TEMP_ITEM)
	local t = {}
	local p
	for k,v in pairs(order) do
		if v.key:sub(1,1) == "/" then
			p = v.key
		elseif p then
			for path, c in pairs(all_config.paths) do
				for method, itm in pairs(c or {}) do
					if path == p and v.key == method then
						c.path=path
						c.method=method
						table.insert( t, list_item:tk{
							DESCRIPTION = c[c.method].summary or c[c.method].description or c.path,
							PATH = c.path:sub(2),
							METHOD = c.method:upper(),
							METHOD_LCASE = c.method,
							CONFIG = cfgfile
						})	
						break
					end
				end
			end
		end
	end
	local parsed_list = lst:tk{
		ITEMS = table.concat(t,"\n"),
		API_URL = API_URL,
		TITLE = TITLE
	}
	return parsed_list
end

function m.create(path, params)
	-- sets variables and config
	API_PATH = path
	TEMP_PATH = API_PATH .. _TEMP_PATH
	API_URL = ngx.var.scheme.."://".. ngx.var.http_host .. "/"..API_PATH
	-- custom or default config using yaml or json
	local hasyaml,lyaml = pcall(require,"lyaml")
	local cfg = params.config or DEFAULT_CFG
	local all_tests, order
	if hasyaml then
		cfg = cfg
		local cfg_data = file_load(API_PATH.."/"..cfg..".yaml")
		if type(cfg_data) == "string" then
			all_tests = lyaml.load(cfg_data)
			order = sort_yaml(cfg_data,3,"paths") -- path+method level!
		else
			return string.format("Config not found: <b>%s</b>", tostring(cfg)..".yaml")
		end
	end
	-- generates the requested html 
	if all_tests then
		if params and params.method and params.path then
			return make_form(all_tests, params, cfg)
		else
			return make_menu(all_tests, order, cfg)
		end
	end
	return "<b>Oops...</b>"
end

return m