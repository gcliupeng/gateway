-- 每个worker维护自己的限流计数器
g_limit = {}
-- require('resty/core/var')