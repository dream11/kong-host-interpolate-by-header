rockspec_file_name=$(ls *.rockspec)
luarocks upload $rockspec_file_name --api-key=${{ secrets.LUAROCKS_KEY }}