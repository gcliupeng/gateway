return function ()
-- 删除某一个url的熔断策略
-- 输入post，json格式
-- {
-- "domain":"bigapp.rong360.com",
-- "prefix":"/controller/module/action"
-- }


local cjson = require('cjson.safe')
local dict = ngx.shared.policy

local errData = {}
local res = {errno=0,errmsg='ok'}

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

if(type(data.prefix) == 'nil' or type(data.domain) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or prefix misssing'
	ngx.say(cjson.encode(errData))
	return
end


local fuse_domain_key = "fprefix%_%"..data.domain
local fuse_domain_data = dict:get(fuse_domain_key)
if not fuse_domain_data then
	errData.errno = 20008
	errData.errmsg = 'no config found'
	ngx.say(cjson.encode(errData))
	return
end
fuse_domain_data = cjson.decode(fuse_domain_data)
if not fuse_domain_data then
	errData.errno = 20008
	errData.errmsg = 'no config found'
	ngx.say(cjson.encode(errData))
	return
end

local i
local have = 0
if type(fuse_domain_data[data.prefix]) ~='nil' then
	have =1
	fuse_domain_data[data.prefix] = nil
	-- table.remove(fuse_domain_data,data.prefix)
end

local rt,msg
if have  == 1 then
	rt,msg = dict:safe_set(fuse_domain_key,cjson.encode(fuse_domain_data))
	if not rt then
		errData.errno = 20005
		errData.errmsg = 'dict set error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
	rt,msg = dict:delete("fuse_domain_data%_%"..data.domain.."%_%"..data.prefix)
	if not rt then
		errData.errno = 20007
		errData.errmsg = 'dict delete error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
	rt,msg = dict:delete("fuse_domain_code%_%"..data.domain.."%_%"..data.prefix)
	if not rt then
		errData.errno = 20007
		errData.errmsg = 'dict delete error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
else
	errData.errno = 20008
	errData.errmsg = 'no config found'
	ngx.say(cjson.encode(errData))
	return
end

ngx.say(cjson.encode(res))
end