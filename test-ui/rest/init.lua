--
-- Test-Ui initialization
-- 
-- (c) 2024, github.com/hipBali
--

local path = string.gsub(ngx.var.request_uri, "?.*", ""):sub(2)
local params = ngx.req.get_uri_args()
---------------------------------------------------------------
-- adds id parameter if any number found at the end of the path 
local t_path = {}
for p in string.gmatch(path, '([^/]+)') do
	table.insert(t_path,p)
end
if tonumber(t_path[#t_path]) then
	local param = t_path[#t_path]
	t_path[#t_path] = nil
	params["id"] = tonumber(param)
	path = table.concat(t_path,"/")
end
----------------------------------------------------------------
-- check test-ui endpoint
local lua_script = path.."/gen-ui/generator.lua"
local f=io.open(lua_script,"r")
if f~=nil then 
	io.close(f) 
	ngx.header.content_type = 'text/html'
	local res = require(path..".gen-ui.generator").create(path,params)
	ngx.say( res ) 
else
	-- handle request ...
	-- ...
	-- the sample rest api
	local res = require("test-ui.sample.api")
	ngx.say( res )
end

