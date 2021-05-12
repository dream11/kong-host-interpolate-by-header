# cd /kong-plugin
busted /kong-plugin/spec -c
luacov
cp luacov.report.out /kong-plugin
