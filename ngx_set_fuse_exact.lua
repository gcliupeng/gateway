-- 设置某一个url的熔断策略
-- 输入post，json格式
-- {
-- "domain":"www.rong350.com",
-- "url":"/controller/module/action",
-- "data":"{errno:200,\"msg\":\"系统异常\"}",
-- "code":555,
-- "expire":5 单位是秒
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

if(type(data.domain) == 'nil' or type(data.url) == 'nil' or type(data.data) == 'nil' or type(data.code) == 'nil' or type(data.expire) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or url or data or expire or code field missing'
	ngx.say(cjson.encode(errData))
	return
end

if(tonumber(data.expire) < 0) then
	errData.errno = 20004
	errData.errmsg = 'input expire time < 0 '
	ngx.say(cjson.encode(errData))
	return
end

local rt,msg = dict:safe_set('fuse_exact_data_'..data.domain..'_'..data.url,cjson.encode(data.data),data.expire)
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
end

rt,msg = dict:safe_set('fuse_exact_code_'..data.domain..'_'..data.url,data.code,data.expire)
if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict set error , msg '.. msg 
	ngx.say(cjson.encode(errData))
end
ngx.say(cjson.encode(res))
-- ngx.say(data.key)