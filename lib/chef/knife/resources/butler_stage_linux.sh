repo=$1

mkdir /tmp/butler/data_bags
mkdir /tmp/butler/kitchen/cache
cp -r "/tmp/butler/cookbooks/$repo/test/fixtures/data_bags/*" "/tmp/butler/data_bags/"
cp -r "/tmp/butler/cookbooks/$repo/test/integration/default/encrypted_data_bag_secret" /var/chef
touch /tmp/butler/validation_key
cp "/tmp/butler/cookbooks/$repo/test/environments/*" /tmp/butler/environments/
