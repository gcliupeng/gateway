return function ()
-- 删除某一个url的熔断策略
-- 输入post，json格式
-- {
-- "domain":"bigapp.rong360.com",
-- "url":"/controller/module/action"
-- }

local cjson = require('cjson.safe')
local dict = ngx.shared.policy

local errData = {}
local res = {errno=0,errmsg}

if(type(dict) == 'nil') then
	errData.errno = 20001
	errData.errmsg = 'no dict in the nginx config file'
	ngx.say(cjson.encode(errData))
	return
end

local body = ngx.req.get_body_data()
if(type(body) == 'nil') then
	errData.errno = 20003
	errData.errmsg = 'no input data'
	ngx.say(cjson.encode(errData))
	return
end

local data = cjson.decode(body)
if(type(data) == 'nil') then
	errData.errno = 20003
	errData.errmsg = 'input data not json'
	ngx.say(cjson.encode(errData))
	return
end

local cr = checkSignature(data)
if cr ~= 1 then
	errData.errno = 20013
	errData.errmsg = 'token check error'
	ngx.say(cjson.encode(errData))
	return
end

if(type(data.url) == 'nil' or type(data.domain) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or url misssing'
	ngx.say(cjson.encode(errData))
	return
end

local rt,msg = dict:delete('fuse_exact_code%_%'..data.domain..'%_%'..data.url)

if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict delete error , msg '.. msg 
	ngx.say(cjson.encode(errData))
end
rt,msg = dict:delete('fuse_exact_data%_%'..data.domain..'%_%'..data.url)

if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict delete error , msg '.. msg 
	ngx.say(cjson.encode(errData))
end

ngx.say(cjson.encode(res))
end