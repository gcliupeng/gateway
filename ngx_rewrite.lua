-- 首先判断具体接口熔断
local fuse_exact = require('ngx_process_fuse_exact')
local r = fuse_exact.check_fuse()
if r == fuse_exact.STOP then
	return
end
-- 其次判断产品线熔断
local fuse_domain = require('ngx_process_fuse_domain')
r = fuse_domain.check_fuse_domain()
if r == fuse_domain.STOP then
	return
end
-- 限流处理

local limit = require('ngx_process_limit')
r = limit.check_limit()
if r == fuse_domain.STOP then
	return
end