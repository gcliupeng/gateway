local dict = ngx.shared.policy
-- local var = require('resty/core/var')
local uri = ngx.var.uri
local host = ngx.var.host
-- no policy data
if(type(dict) == 'nil') then
	return
end

local code = dict:get('fuse_exact_code_'..host..'_'..uri)
local data = dict:get('fuse_exact_data_'..host..'_'..uri)
if(type(data) == 'nil' or type(code) == 'nil') then
	return
end

-- ngx.say while stop the phase loop and finilize request
ngx.status = code
ngx.say(data)
