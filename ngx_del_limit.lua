-- 删除某一个url的限流策略
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

local function checkSignature(data)
	if type(data) ~= 'table' then
		return 0
	end
	local tmp = {}
	local pos
	for k,v in pairs(data) do
		if k ~= 'token' then
			pos = 1
			for i=1,#tmp do
				if k < tmp[i] then
					break
				else
					pos = pos+1
				end
			end
			table.insert(tmp,pos,k)
		end
	end

	local s=''
	for i=1,#tmp do
		s = s..tmp[i]..'='..data[tmp[i]]
	end

	local token = ngx.md5(s)
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

local cr = checkSignature(data)
if cr ~= 1 then
	errData.errno = 20013
	errData.errmsg = 'token check error'
	ngx.say(cjson.encode(errData))
	return
end

if(type(data.url) == 'nil' or type(data.domain) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or url missing'
	ngx.say(cjson.encode(errData))
	return
end

local rt,msg = dict:delete('lmitc%_%'..data.domain..'%_%'..data.url)

if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict delete error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end
rt,msg = dict:delete('limitd%_%'..data.domain..'%_%'..data.url)

if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict delete error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end

rt,msg = dict:delete('limitp%_%'..data.domain..'%_%'..data.url)

if not rt then
	errData.errno = 20005
	errData.errmsg = 'dict delete error , msg '.. msg 
	ngx.say(cjson.encode(errData))
	return
end
ngx.say(cjson.encode(res))
-- ngx.say(data.key)