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
	if string.sub(key,1,16) == 'fuse_exact_data_' then
		-- 完全匹配熔断
		res = string.sub(key,16)
		arr =  split(res,"_")
		domain, url = arr[1],arr[2]
		table.insert(fuses_exact_d,{domain=domain,url=url}) 
	elseif string.sub(key,1,3) == 'lc_' then
		-- 匹配限流
		res = string.sub(key,4)
		arr =  split(res,"_")
		domain, url = arr[1],arr[2]
		table.insert(limits_d,{domain=domain,url=url}) 
	end
end
local output = {errno = 0 , limits=limits_d, fuses_exact = fuses_exact_d,fuses_domain = fuses_domain_d}
ngx.say(cjson.encode(output))