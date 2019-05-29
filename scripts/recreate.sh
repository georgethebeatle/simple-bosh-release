set -e -x

bosh -d simple-bosh-release delete-deployment
bosh delete-release simple-bosh-release
bosh -n create-release --force
bosh -n upload-release
bosh -d simple-bosh-release deploy deployments/manifest.yml
