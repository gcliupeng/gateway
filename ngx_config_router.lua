-- 定义全局函数
function checkSignature(data)
  if type(data) ~= 'table' then
    return 0
  end
  local tmp = {}
  local pos
  for k,v in pairs(data) do
    if k ~= 'token' and type(v)~='table' then
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

-- all the controller
local controllers = {}

controllers.fuse_set_exact = require('ngx_set_fuse_exact')
controllers.fuse_delete_exact = require('ngx_del_fuse_exact')

controllers.fuse_set_domain = require('ngx_set_fuse_domain')
controllers.fuse_delete_domain = require('ngx_del_fuse_domain')
controllers.fuse_set_domain_batch = require('ngx_set_fuse_domain_batch')

controllers.limit_set = require('ngx_set_limit')
controllers.limit_delete = require('ngx_del_limit')

controllers.status = require('ngx_status')

controllers.config_dump = require('ngx_config_dump')


local cjson = require('cjson.safe')
local res = {errno=2222,errmsg='unknown api'}
local uri = string.sub(ngx.var.uri,2)

if type(controllers[uri]) ~= 'nil' then
	controllers[uri]()
else
	ngx.say(cjson.encode(res))
end
