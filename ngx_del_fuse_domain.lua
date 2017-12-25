-- 删除某一个url的熔断策略
-- 输入post，json格式
-- {
-- "domain":"bigapp.rong360.com",
-- "prefix":"/controller/module/action"
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

if(type(data.prefix) == 'nil' or type(data.domain) == 'nil')then
	errData.errno = 20005
	errData.errmsg = 'input data error, domain or prefix misssing'
	ngx.say(cjson.encode(errData))
	return
end


local fuse_domain_key = "fprefix_"..data.domain
local fuse_domain_data = dict:get(fuse_domain_key)
if not fuse_domain_data then
	reerrData.errno = 20008
	errData.errmsg = 'no config found'
	ngx.say(cjson.encode(errData))
	return
end
fuse_domain_data = cjson.decode(fuse_domain_data)
if not fuse_domain_data then
	reerrData.errno = 20008
	errData.errmsg = 'no config found'
	ngx.say(cjson.encode(errData))
	return
end

local i
local have = 0
for i=1,#fuse_domain_data do
	if fuse_domain_data[i] == data.prefix then
		have =1
		table.remove(fuse_domain_data,i)
		break
	end
end

local rt,msg
if have then
	rt,msg = dict:safe_set(fuse_domain_key,cjson.encode(fuse_domain_data))
	if not rt then
		errData.errno = 20005
		errData.errmsg = 'dict set error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
	rt,msg = dict:delete("fuse_domain_data_"..data.domain.."_"..data.prefix)
	if not rt then
		errData.errno = 20007
		errData.errmsg = 'dict delete error , msg '.. msg 
		ngx.say(cjson.encode(errData))
		return
	end
	rt,msg = dict:delete("fuse_domain_code_"..data.domain.."_"..data.prefix)
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