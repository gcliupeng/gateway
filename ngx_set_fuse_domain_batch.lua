-- 设置某一个domain+prefix的熔断策略
-- 输入post，json格式
-- {
--	"domain" : "www.rong360.com",
--	"list":[
-- 		{
-- 			"prefix":"/credit",
--			"type":0,  type 0 表明放过，此接口不处理
--		},
--		{
-- 			"prefix":"/credit",
-- 			"data":"{errno:200,\"msg\":\"系统异常\"}",
-- 			"code":555,
-- 			"expire":5 单位是秒,
--			"type":1
-- 		}
-- 	]
--}

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

local dataAll = cjson.decode(body)
if(type(dataAll) == 'nil') then
	errData.errno = 20003
	errData.errmsg = 'input data not json'
	ngx.say(cjson.encode(errData))
	return
end

local cr = checkSignature(dataAll)
if cr ~= 1 then
	errData.errno = 20013
	errData.errmsg = 'token check error'
	ngx.say(cjson.encode(errData))
	return
end

-- 必须包含domain项
local domain = dataAll['domain']
if type(domain) == 'nil' then
	errData.errno = 20023
	errData.errmsg = 'domain missing'
	ngx.say(cjson.encode(errData))
	return
end

local  dataA = dataAll['list']
-- dataA 是一个数组
if type(dataA) == 'nil' or #dataA == 0 then
	errData.errno = 20023
	errData.errmsg = 'input list not a array'
	ngx.say(cjson.encode(errData))
	return
end

-- 数据校验及计算
local expireMost = 0

local fuse_domain_key = "fprefix%_%"..domain
local fuse_domain_data = dict:get(fuse_domain_key)
if not fuse_domain_data then
	fuse_domain_data = {}
else
	fuse_domain_data = cjson.decode(fuse_domain_data)
	if not fuse_domain_data then
		fuse_domain_data = {}
	end
end

for i=1,#dataA do
	local data = dataA[i]
	if tonumber(data['type']) == 0 then
		if(type(data.prefix) == 'nil') then
		 	errData.errno = 20005
			errData.errmsg = 'input data error,domain or prefix field missing'
			ngx.say(cjson.encode(errData))
			return
		end
		-- 将domain => type 插入
		fuse_domain_data[data.prefix] = 0

	elseif tonumber(data['type']) == 1 then
		if(type(data.prefix) == 'nil' or type(data.data) == 'nil' or type(data.code) == 'nil' or type(data.expire) == 'nil')then
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

		if tonumber(data.expire) > expireMost then
			expireMost = tonumber(data.expire)
		end
		fuse_domain_data[data.prefix] = 1

	else
		errData.errno = 20015
		errData.errmsg = 'input type error'
		ngx.say(cjson.encode(errData))
		return
	end
end


local now = ngx.time()
-- 首先更新总开关
local global_switch = "global%_%"..domain
local global_data = dict:get(global_switch)
if global_data then
	-- 修改值和过期时间
	if now + expireMost > tonumber(global_data) then
		rt,msg = dict:safe_set(global_switch,now + expireMost,expireMost)
		if not rt then
			errData.errno = 20005
			errData.errmsg = 'dict set error , msg '.. msg 
			ngx.say(cjson.encode(errData))
			return
		end
	end
else
	rt,msg = dict:safe_set(global_switch,now + expireMost,expireMost)
	if not rt then
		errData.errno = 20005
		errData.errmsg = 'dict set error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
end

rt,msg = dict:safe_set(fuse_domain_key,cjson.encode(fuse_domain_data))
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end

-- -- 插入返回数据和code
for i=1,#dataA do
	local data = dataA[i]
	if tonumber(data['type']) == 1 then
		local fuse_domain_data_key = "fuse_domain_data%_%"..domain.."%_%"..data.prefix
		local fuse_domain_code_key = "fuse_domain_code%_%"..domain.."%_%"..data.prefix
		rt,msg = dict:safe_set(fuse_domain_data_key,cjson.encode(data.data),data.expire)
		if not rt then
			errData.errno = 20005
			errData.errmsg = 'dict set error , msg '.. msg 
			ngx.say(cjson.encode(errData))
			return
		end
		rt,msg = dict:safe_set(fuse_domain_code_key,data.code,data.expire)
		if not rt then
			errData.errno = 20005
			errData.errmsg = 'dict set error , msg '.. msg 
			ngx.say(cjson.encode(errData))
			return
		end
	end
end
ngx.say(cjson.encode(res))