local cjson = require('cjson')
local dict = ngx.shared.policy
local uri = ngx.var.uri
local host = ngx.var.host
-- uri = string.sub(uri,2)
-- no policy data
if(type(dict) == 'nil') then
	return
end

-- 看看是否有配置
local limit_conf_key = 'lc'..host..'_'..uri
local limit_conf = dict:get(limit_conf_key)
if not limit_conf then
	return
end

limit_conf = cjson.decode(limit_conf)
if(type(limit_p) == 'nil') then
	return
end

local now_t = ngx.now() --毫秒级
-- 令牌桶算法，速率毫秒级
if limit_conf.last == -1 then
   limit_conf.last = now_t
else
   limit_conf.current = limit_conf.current - (now_t - limit_conf.last)*limit_conf.pqs/1000
   if limit_conf.current < 0 then
   		limit_conf.current = 0
   end
end

if limit_conf.current > limit_conf.qps then
   if limit_conf.type == 1 then
   		ngx.say(limit_conf.data)
	else

	end
	return
end

-- 更新，写入
limit_conf.current = limit_conf.current + 1
limit_conf.last = now_t
dic:safe_set(limit_conf_key,json.encode(limit_conf),limit_conf.time - now_t)


