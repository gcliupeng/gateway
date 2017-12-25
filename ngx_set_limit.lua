-- 设置某一个url的限流策略
-- 输入post，json格式
-- {
-- "domain":"bigapp.rong360.com",
-- "url":"/controller/module/action",
-- "qps":500,
-- "type":1, 1表明gateway直接返回，2表明传给业务方
-- "data":"{errno:200,\"msg\":\"系统异常\"}", 直接返回时的数据,type==1时必须有
-- "code":555,直接返回时的code,type==1时必须有
-- "expire":5000
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

local function checkSignature(data)
	if type(data) ~= 'table' then
		return 0
	end
	local tmp = {}
	local i
	for k,v in pairs(data) do
		if k ~= 'token' then
			i = 1
			for i=1,#tmp do
				if k < tmp[i] then
					break
				end
			end
			table.insert(tmp,i,k)
		end
	end

	local s=''
	for i=1,#tmp do
		s = s..tmp[i]..'='..data[tmp[i]]
	end
	local token = ngx.md5(s)
	ngx.say(token)
	if token == data['token'] then
		return 1
	else
		return 0
	end
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

local cr = checkSignature(body)
if cr != 1 then
	errData.errno = 20013
	errData.errmsg = 'token check error'
	ngx.say(cjson.encode(errData))
	return
end

if(type(data.domain) == 'nil' or type(data.url) == 'nil' or type(data.qps) == 'nil' or type(data.expire) == 'nil' or type(data.type) == 'nil') then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or url or qps or type or expire missing'
	ngx.say(cjson.encode(errData))
	return
end

if(tonumber(data.type) == 1) then
	if(type(data.data) == 'nil' or type(data.code) == 'nil') then
		errData.errno = 20005
		errData.errmsg = 'input data error,not data or code'
		ngx.say(cjson.encode(errData))
		return
	end
end

if(tonumber(data.expire) < 0) then
	errData.errno = 20004
	errData.errmsg = 'input expire time < 0 '
	ngx.say(cjson.encode(errData))
	return
end

if(tonumber(data.qps) < 0) then
	errData.errno = 20006
	errData.errmsg = 'input pqs < 0 '
	ngx.say(cjson.encode(errData))
	return
end

local limit_conf_key = 'lc_'..data.domain..'_'..data.url
local limit_conf = {type = data.type, code = data.code, qps = data.qps, last = -1, current = data.qps}
-- 改用cdata
local rt,msg = dict:safe_set(limit_conf_key,cjson.encode(limit_conf),data.expire)
if not rt then
	errData.errno = 20007
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end

local limit_data_key = 'ld_'..data.domain..'_'..data.url
local rt,msg = dict:safe_set(limit_data_key,cjson.encode(data.data),data.expire)
if not rt then
	errData.errno = 20007
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end
ngx.say(cjson.encode(res))
-- ngx.say(data.key)