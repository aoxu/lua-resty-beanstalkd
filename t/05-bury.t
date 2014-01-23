# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_BEANSTALKD_PORT} ||= 11300;

no_long_string();
no_shuffle();

run_tests();

__DATA__

=== TEST 1: bury
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            local ok, err = bean:watch("default")
            if not ok then
                ngx.say("2: failed to watch: ", err)
                return
            end

            local id, data = bean:reserve()
            if not id then
                ngx.say("3: failed to reserve: ", id)
                return
            else
                ngx.say("1: reserve: ", id)
                local ok, err = bean:bury(id)
                if not ok then
                    ngx.say("4: failed to bury, id:", id, " error:", err)
                    return
                else
                    ngx.say("2: bury: ", id)
                end
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
1: reserve: \d+
2: bury: \d+
--- no_error_log
[error]

