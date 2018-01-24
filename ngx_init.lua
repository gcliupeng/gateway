-- 重启时拉取全量配置
local _M = {}
_M.url = "http://127.0.0.1:90/data"
_M.ip = "10.0.0.1"

_M.init_fuse_domain = function (fuse_domains)
-- 初始化fuse_domain
    local cjson = require('cjson.safe')
    local dict = ngx.shared.policy
    local fuse_domain_map = {}
    local fuse_glabal_map = {}
    local fuse_glabal_time
    local fuse_domain_prefixs
    local i


    for i=1,#fuse_domains do
        local item = fuse_domains[i]
        fuse_glabal_time = fuse_glabal_map[item.domain]
        if not fuse_glabal_time then
            fuse_glabal_time = -1
        end

        if item.persist_time > fuse_glabal_time then
            fuse_glabal_time = item.persist_time
            fuse_glabal_map[item.domain] = fuse_glabal_time
        end

        fuse_domain_prefixs = fuse_domain_map[item.domain]
        if not fuse_domain_prefixs then
            fuse_domain_prefixs = {}
        end
        --判断type
        local typei = item.type
        fuse_domain_prefixs[item.uri_prefix] = typei
        fuse_domain_map[item.domain] = fuse_domain_prefixs
        if tonumber(typei) == 1 then
            local fuse_domain_data_key = "fuse_domain_data%_%"..item.domain.."%_%"..item.uri_prefix
            local fuse_domain_code_key = "fuse_domain_code%_%"..item.domain.."%_%"..item.uri_prefix
            local rt,msg = dict:safe_set(fuse_domain_data_key,cjson.encode(item.fuse_return_str),item.persist_time)
            if not rt then
              ngx.log(ngx.WARN,"init gate error, msg :"..msg)
            end

            rt,msg = dict:safe_set(fuse_domain_code_key,item.fuse_return_httpcode,item.persist_time)
            if not rt then
                ngx.log(ngx.WARN,"init gate error, msg :"..msg)
            end
        end
    end
         
    for k,v in pairs(fuse_glabal_map) do
        local global_switch = "global%_%"..k
        dict:safe_set(global_switch,ngx.time()+tonumber(v),tonumber(v))
    end

    for k,v in pairs(fuse_domain_map) do
        local fuse_domain_key = "fprefix%_%"..k
        dict:safe_set(fuse_domain_key,cjson.encode(v))
    end
    ngx.log(ngx.WARN, "init gateway fuse_domain_conf ok , data:".. cjson.encode(fuse_domains))
end

_M.init_fuse_exact = function (fuse_domain_exact)
  -- 初始化fuse_domain_exact
    local cjson = require('cjson.safe')
    local dict = ngx.shared.policy
    local i
    for i=1,#fuse_domain_exact do
        local item = fuse_domain_exact[i]

        local data_key = "fuse_exact_data%_%"..item.domain.."%_%"..item.uri
        local code_key = "fuse_exact_code%_%"..item.domain.."%_%"..item.uri
        local rt,msg = dict:safe_set(data_key,cjson.encode(item.fuse_return_str),item.persist_time)
        if not rt then
          ngx.log(ngx.WARN,"init gate error, msg :"..msg)
        end

        rt,msg = dict:safe_set(code_key,item.fuse_return_httpcode,item.persist_time)
        if not rt then
          ngx.log(ngx.WARN,"init gate error, msg :"..msg)
        end
    end
    ngx.log(ngx.WARN, "init gateway fuse_domain_exact_conf ok , data:".. cjson.encode(fuse_domain_exact))
end

_M.init_limit = function (limit_confs)
  -- 初始化限流配置
    local cjson = require('cjson.safe')
    local dict = ngx.shared.policy
    local i
    for i=1,#limit_confs do
        local item = limit_confs[i]

        local conf_key = 'limitc%_%'..item.domain..'%_%'..item.uri
        local data_key = 'limitd%_%'..item.domain..'%_%'..item.uri
        local conf_data = {type = item.lf_limit_type, code = item.lf_return_httpcode, qps = item.qps, last = -1, current = 0, mark =item.lf_param_mark}
        
        local rt,msg = dict:safe_set(data_key,cjson.encode(item.fuse_return_str))
        if not rt then
          ngx.log(ngx.WARN,"init gate error, msg :"..msg)
        end

        rt,msg = dict:safe_set(conf_key,cjson.encode(conf_data))
        if not rt then
          ngx.log(ngx.WARN,"init gate error, msg :"..msg)
        end

        local params_key = 'limitp%_%'..item.domain..'%_%'..item.uri
        table.sort(item.lf_param_transfer)
        rt,msg = dict:safe_set(params_key,cjson.encode(item.lf_param_transfer))
        if not rt then
          ngx.log(ngx.WARN,"init gate error, msg :"..msg)
        end
    end
    ngx.log(ngx.WARN, "init gateway fuse_domain_exact_conf ok , data:".. cjson.encode(fuse_domain_exact))
end

_M.init_conf = function ()
  local cjson = require('cjson.safe')
  local dict = ngx.shared.policy
  if(type(dict) == 'nil') then
    return
  end

  local http = require "resty.http"
  local httpc = http.new()
  local res, err = httpc:request_uri(_M.url.."?ip=".._M.ip, {
        method = "GET",
        body = "ip=".._M.ip,
      })

  if not res then
      -- ngx.say("failed to request: ", err)
      ngx.log(ngx.WARN, "init gateway conf error , url:".._M.url..", ip:".._M.ip..", err:"..err)
      return
  else
      local data = res.body
      if #data == 0 then
          ngx.log(ngx.WARN, "init gateway error , return empty")
          return
      end
      
      data = cjson.decode(data)
      if not data then
          ngx.log(ngx.WARN, "init gateway conf error ,not json,data:"..res.body)
          return
      end
      
      data = data.data
      if not data then
          ngx.log(ngx.WARN, "init gateway conf error ,not json,data:"..res.body)
          return
      end

      _M.init_fuse_domain(data.fuse_domain)
      _M.init_fuse_exact(data.fuse_uri)
      _M.init_limit(data.limit)
      -- bngx.say(cjson.encode(data.fuse_domain))
  end
end
ngx.timer.at(1,_M.init_conf)
-- _M.init_conf()
