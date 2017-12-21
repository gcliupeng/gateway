-- 判断某一个接口是否满足产品线熔断策略，根据host+prefix
local cjson = require('cjson.safe')
local dict = ngx.shared.policy
local uri = ngx.var.uri
local host = ngx.var.host
-- local host = 'dd'
-- local hostLeng = string.len(host)
-- uri = string.sub(uri,2)

-- no policy data
if(type(dict) == 'nil') then
	return
end

-- 检查总开关
local global_switch = "global_"..host
local global_data = dict:get(global_switch)
-- 大部分接口在此返回，熔断某一前缀功能较影响性能
if not global_data then
	return
end

-- 取出前缀列表
local fuse_domain_key = "fprefix_"..host
local fuse_domain_confs = dict:get(fuse_domain_key)
if not fuse_domain_confs then
	return
end
fuse_domain_confs = cjson.decode(fuse_domain_confs)
if not fuse_domain_confs then
	return
end

local prex_match
local length_match = -1
local i
local fuse_domain_data_key
local fuse_domain_code_key
local fuse_domain_data
local fuse_domain_code
local needSave = 0
for i=1,#fuse_domain_confs do
	local prefixLen = string.len(fuse_domain_confs[i])
	local prefix = fuse_domain_confs[i]
	if string.sub(uri,1,prefixLen) == prefix then
		if  length_match < prefixLen then
			-- 判断数据是否过期
			fuse_domain_data_key = "fuse_domain_data_"..host.."_"..prefix
			fuse_domain_code_key = "fuse_domain_code_"..host.."_"..prefix
			local v1 = dict:get(fuse_domain_data_key)
			local v2 = dict:get(fuse_domain_code_key)
			if not v1 or not v2 then
				table.remove(fuse_domain_confs,i)
				needSave = 1
			else
				fuse_domain_data = v1
				fuse_domain_code = v2
				length_match = prefixLen
				prex_match = prefix
			end
		end
	end
end

if needSave == 1 then
	dict:safe_set(fuse_domain_key,cjson.encode(fuse_domain_confs))
end

if length_match ~= -1 then
	ngx.status = fuse_domain_code
	ngx.say(fuse_domain_data)
end