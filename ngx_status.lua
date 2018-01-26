return function()
-- 返回当前nginx状态
local cjson = require('cjson')
local dict = ngx.shared.policy

if(type(dict) == 'nil') then
	errData.errno = 20001
	errData.errmsg = 'no dict in the nginx config file'
	ngx.say(cjson.encode(errData))
	return
end

function split(input, delimiter)  
    input = tostring(input)  
    delimiter = tostring(delimiter)  
    if (delimiter=='') then return false end  
    local pos,arr = 0, {}  
    -- for each divider found  
    for st,sp in function() return string.find(input, delimiter, pos, true) end do  
        table.insert(arr, string.sub(input, pos, st - 1))  
        pos = sp + 1  
    end  
    table.insert(arr, string.sub(input, pos))  
    return arr  
end 

local keys = dict:get_keys()
local limits_d = {}
local fuses_exact_d = {}
local fuses_domain_d = {}

for i=1,#keys do
	local key = keys[i]
	local domain, prefix, url, arr
	if string.sub(key,1,18) == 'fuse_exact_data%_%' then
		-- 完全匹配熔断
		res = string.sub(key,19)
		arr =  split(res,"%_%")
		domain, url = arr[1],arr[2]
		local code = dict:get('fuse_exact_code%_%'..domain..'%_%'..url)
		local data = dict:get('fuse_exact_data%_%'..domain..'%_%'..url)
		table.insert(fuses_exact_d,{domain=domain,url=url,code=code,data=data}) 
	elseif string.sub(key,1,19) == 'fuse_domain_data%_%' then
		-- 匹配前缀熔断
		res = string.sub(key,20)
		arr =  split(res,"%_%")
		domain, prefix = arr[1],arr[2]
		local code = dict:get('fuse_domain_code%_%'..domain..'%_%'..prefix)
		local data = dict:get('fuse_domain_data%_%'..domain..'%_%'..prefix)
		table.insert(fuses_domain_d,{domain=domain,prefix=prefix,code=code,data=data}) 
	elseif string.sub(key,1,9) == 'limitc%_%' then
		-- 匹配限流
		res = string.sub(key,10)
		arr =  split(res,"%_%")
		domain, url = arr[1],arr[2]
		local conf = dict:get(key)
		conf = cjson.decode(conf)		
		table.insert(limits_d,{domain=domain,url=url,qps=conf.qps,code=conf.code,type=conf.type}) 
	end
end
local data_all = {limits=limits_d, fuses_exact = fuses_exact_d,fuses_domain = fuses_domain_d}
local output = {errno = 0 , errmsg = 'ok', data = data_all}
ngx.say(cjson.encode(output))
end