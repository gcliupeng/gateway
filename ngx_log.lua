-- ngx.log(4,"hello_world")
-- ngx.header.fuse = 'on'
-- ngx.say('hello_world')
local cjson = require('cjson.safe')
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

local r = checkSignature(data)
if r == 1 then
	ngx.say("ok")
else
	ngx.say("error")
end