file_name=$(ls *.rockspec)

prefix='host-interpolate-by-header-'
suffix='-1.rockspec'

version=${file_name#"$prefix"}
version=${version%"$suffix"}

new_version=$1
new_version=${new_version#"v"}

commit_access_token=$2

sed -i.bak "s/$version/$new_version/g" $file_name && rm *.bak

new_file_name="$prefix$new_version$suffix"

git config user.name Dream11botpub
git config user.email Dream11botpub@github.com

git mv $file_name $new_file_name
git remote set-url origin https://Dream11botpub:${commit_access_token}@github.com/dream11/kong-host-interpolate-by-header.git
git add .
git commit -m "chore: bump version from $version to $new_version"
git push
