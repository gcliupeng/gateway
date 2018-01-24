return function()
local cjson = require('cjson')
local dict = ngx.shared.policy
local keys = dict:get_keys()
local data = {}

for i,k in ipairs(keys) do
	data[k] = dict:get(k)
end

ngx.say(cjson.encode(data))
end