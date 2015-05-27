# simple-bosh-release

## What on earth is this?

This is a very simple bosh relese for a static webpage hosted by `apache2` server. It has only one job and only one package. 
This is as simple as it gets. You can only deploy it on bosh-lite, so you won't need to generate the deployment manifest and
deal with complex parameter substitution and merging stubs and templates. 

If you want to grasp the very basic things about `bosh`
then read on - we will be building the simplest release in the world step by step, explaining the concepts, starting from scratch.

## What are you talkin' about?

If you are unfamiliar with `bosh` and its basic terminology and want to dig deeper, [this](http://bosh.io/docs/about.html) may be a good place to start.

**TL;DR**
`bosh` is the cloud operator's swiss army knife - it is a tool that handles a software project's release, deployment and lifecycle management. It defines a `release` that is comprised of `jobs`, `packages` and `sources`. A `bosh release` is self contained and fully reproducible accross environments.

## Let's build it!

### Install vagrant

We are going to spin up a virtual machine and do all the steps in it, so we will need [vagrant](https://www.vagrantup.com/) installed. You need to follow the inistructions for your platform on their [site](https://www.vagrantup.com/)

### Spin up your very own bosh-lite
If we are to learn how to operate a tool for managing clouds aren't we going to need some expensive account on amazon on google or some other cloud provider? Not at all! Because we have `bosh-lite`.

`bosh-lite` is a pre-built `vagrant` environment that has the central `bosh director` installed and what's more - it is preconfigured to launch containers on the vary same vagrant box - so we are getting the-cloud-in-a-box more or less. 

So lets spin the thing up:

```
git clone https://github.com/cloudfoundry/bosh-lite.git
cd bosh-lite
vagrant up
```

The first spinup may take a while because `vagrant` will download an OS image from the internet. After the VM is ready
ssh into it like this:

```
vagrant ssh
```

bosh is pre-installed on this box, so run the following:

```
bosh target
```

and you should see this:

```
Current target is https://127.0.0.1:25555 (Bosh Lite Director)
```

That's it - we have bosh, read on...

### Install some prerequisite software on the box
Apart from bosh this is a surprisingly skinny VM, so we will need to install some tools:

```
sudo apt-get update && sudo apt-get install -y vim git curl
```

### Generate a release scaffold
### Add the package
### Add the job
### Describe your deployment

## Pull the trigger

### Upload stemcell
### Create & upload a development release
### Deploy

## Customize the app

### Tweak some property
### Redeploy
