-- 判断某一个具体接口是否需要熔断
local _M = {}
_M.OK = 0
_M.STOP = 1
_M.check_fuse = function()
	local dict = ngx.shared.policy
	-- local var = require('resty/core/var')
	local uri = ngx.var.uri
	local host= ngx.var.host
	-- no policy data
	if(type(dict) == 'nil') then
		return _M.OK
	end

	local code = dict:get('fuse_exact_code%_%'..host..'%_%'..uri)
	local data = dict:get('fuse_exact_data%_%'..host..'%_%'..uri)
	if(type(data) == 'nil' or type(code) == 'nil') then
		return _M.OK
	end
	-- ngx.say while stop the phase loop and finilize request
	ngx.header.fuse = 'on'
	ngx.status = code
	ngx.say(data)
 	return _M.STOP
end
return _M