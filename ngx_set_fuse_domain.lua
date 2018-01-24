return function ()
-- 设置某一个domain+prefix的熔断策略
-- 输入post，json格式
-- {
-- "domain":"www.rong350.com",
-- "prefix":"/credit",
-- "data":"{errno:200,\"msg\":\"系统异常\"}",
-- "code":555,
-- "expire":5 单位是秒
-- }

local cjson = require('cjson.safe')
local dict = ngx.shared.policy

local errData = {}
local res = {errno=0,errmsg}
local rt
local msg

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

if(type(data.domain) == 'nil' or type(data.prefix) == 'nil' or type(data.data) == 'nil' or type(data.code) == 'nil' or type(data.expire) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error,domain or prefix or data or code or expire field missing'
	ngx.say(cjson.encode(errData))
	return
end

if(tonumber(data.expire) < 0) then
	errData.errno = 20004
	errData.errmsg = 'input expire time < 0 '
	ngx.say(cjson.encode(errData))
	return
end

local now = ngx.time()
-- 首先更新总开关
local global_switch = "global%_%"..data.domain
local global_data = dict:get(global_switch)
if global_data then
	-- 修改值和过期时间
	if now + data.expire > tonumber(global_data) then
		rt,msg = dict:safe_set(global_switch,now + data.expire,data.expire)
		if not rt then
			errData.errno = 20005
			errData.errmsg = 'dict set error , msg '.. msg 
			ngx.say(cjson.encode(errData))
			return
		end
	end
else
	rt,msg = dict:safe_set(global_switch,now + data.expire,data.expire)
	if not rt then
		errData.errno = 20005
		errData.errmsg = 'dict set error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
end

-- 其次，更新具体配置
local fuse_domain_key = "fprefix%_%"..data.domain
local fuse_domain_data = dict:get(fuse_domain_key)
if not fuse_domain_data then
	fuse_domain_data = {}
	fuse_domain_data[data.prefix] = 1
	-- table.insert(fuse_domain_data,data.prefix)
else
	fuse_domain_data = cjson.decode(fuse_domain_data)
	if not fuse_domain_data then
		fuse_domain_data = {}
	end
	fuse_domain_data[data.prefix] = 1
end

rt,msg = dict:safe_set(fuse_domain_key,cjson.encode(fuse_domain_data))
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end

-- 插入返回数据和code
local fuse_domain_data_key = "fuse_domain_data%_%"..data.domain.."%_%"..data.prefix
local fuse_domain_code_key = "fuse_domain_code%_%"..data.domain.."%_%"..data.prefix

rt,msg = dict:safe_set(fuse_domain_data_key,cjson.encode(data.data),data.expire)
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end
rt,msg = dict:safe_set(fuse_domain_code_key,cjson.encode(data.code),data.expire)
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end

ngx.say(cjson.encode(res))
end