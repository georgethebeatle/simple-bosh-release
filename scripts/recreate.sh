set -e -x

bosh -n delete deployment webapp-warden
bosh -n delete release simple-bosh-release
bosh -n create release --force
bosh -n upload release
bosh deployment deployments/warden.yml
bosh -n deploy
