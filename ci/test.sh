git clone https://github.com/Kong/gojira.git
export GOJIRA_MAGIC_DEV=1
export GOJIRA_USE_SNAPSHOT=1
export GOJIRA_TAG=2.2.0
./gojira/gojira.sh up --egg gojira-compose.yaml --git-https  -p $1
sleep 5s
./gojira/gojira.sh run 'for _plugin in /kong/custom_plugins/*;do if [ -d "$_plugin" ];then cd "$_plugin" && luarocks make && cd -;fi;done && luarocks install luacov && bin/busted custom_specs/plugins/ -o custom_specs/output-handlers/custom_format.lua -v -c && luacov && bash <(curl -s https://codecov.io/bash)'  -p $1
