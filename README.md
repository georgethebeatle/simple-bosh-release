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
`bosh` is the cloud operator's swiss army knife - it is a tool that handles a software project's release, deployment and lifecycle management. It defines a `release` that is comprised of `jobs`, `packages` and `sources`. A `bosh release` is self contained and fully reproducible accross environments. The release depends on a `stemcell` that is an OS image that will be run on each VM (or container) that bosh creates. The `stemcell` encapsulates all external dependencies of a `bosh release`. 

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
$ vagrant ssh
```

bosh is pre-installed on this box, so run the following:

```
$ bosh target
Current target is https://127.0.0.1:25555 (Bosh Lite Director)
```

That's it - we have bosh, read on...

### Install some prerequisite software on the box
Apart from bosh this is a surprisingly skinny VM, so we will need to install some tools:

```
$ sudo apt-get update && sudo apt-get install -y vim git curl
```

### Generate a release scaffold

At this point we have dealt with the boring stuff and can get started. First we need to create an empty bosh release.
Luckily the bosh client can do this for us

```
$ bosh init release simple-bosh-release
```

This will create the following file structure

```
$ find simple-bosh-release
bosh-sample-release/
bosh-sample-release/blobs
bosh-sample-release/src
bosh-sample-release/config
bosh-sample-release/config/blobs.yml
bosh-sample-release/jobs
bosh-sample-release/packages
```

Here are the most important of these:

- src: this is the source code for the packages
- packages: these are the instructions on how to compile the source into binaries
- jobs: these are the scripts and configuration files required to run the packages

### Add the sources

Our release will need to run the apache http server so we will have to place the `apache2` sources in the `src/` folder.
There is no restriction on the format of the sources, because the release also contains the packaging scripts that are responsible to transform these sources into runnable software. We are going to provide the `apache2` sources as a `.tar.gz` archive.

```
mkdir src/apache2
cd src/apache2
wget http://apache.cbox.biz//httpd/httpd-2.2.29.tar.gz
```

### Add the package

Now we hace the sources, but these will have to be compiled before we can run the actual server. So we need to add a new package:

```
$ bosh generate package apache2
create  packages/apache2
create  packages/apache2/packaging
create  packages/apache2/pre_packaging
create  packages/apache2/spec
```

We have to fill in the `spec` file like this:

```
---
name: apache2

files:
  - apache2/httpd-2.2.29.tar.gz

```

It simply specifies what files should go in this package. We only need the archived sources of `apache2`

And let's fill in the `packaging` script itself:

```
set -e

echo "Extracting apache httpd..."
tar xzf apache2/httpd-2.2.29.tar.gz

echo "Building apache httpd..."
(
    cd httpd-2.2.29
    ./configure \
    --prefix=${BOSH_INSTALL_TARGET} \
    --enable-so
    make
    make install
)

```

It extracts the sources, configures and compiles, giving a custom install location - the `$BOSH_INSTALL_TARGET`. This is preset by bosh and it is some path on the filesystem of the VM (or container) being provisioned. For our package it will most likely be `/var/vcap/packages/apache2`

### Add the job

At this point we have the apache httpd server available as a package, which means that bosh knows where to get the sources from and how to compile it, but we still haven't run it, and a server that is not running is generally no good.

Thing that run are usually described as `jobs` in bosh terms. So if we want to run the server we will have to defne a job that knows how to configure and run it. 

First let's generate an empty one:

```
$ bosh generate job webapp
create  jobs/webapp
create  jobs/webapp/templates
create  jobs/webapp/spec
create  jobs/webapp/monit
```

Every job has:
- some `properties` through which it can be customized
- some `templates` - these are simple `erb` templates that bosh instantiates with the job properties 
- a `spec` that lists the used packages, the `templates` and the `properties`

Our webapp job will be simply the apache `httpd` server serving some static content from some local `DocumentRoot`. So we will need the following templates: 
- `webapp_ctl.erb` - for starting and stopping the server
- `httpd.conf.erb` - for configuring the server 
- `index.html.erb` - for the html content that the server is going to serve

We may want to define properties for the port on which the server is going to listen for requests, the email of the webmaster, the server address and the content of the welcome html page.

So we may end up with a `spec` like this:

```
---
name: webapp

templates:
  webapp_ctl.erb: bin/webapp_ctl
  httpd.conf.erb: config/httpd.conf
  index.html.erb: htdocs/index.html

packages:
  - apache2

properties:
  webapp.port:
    description: TCP port webapp server listen on
    default: 80
  webapp.admin:
    description: Email address of server administrator
    default: webmaster@example.com
  webapp.servername:
    description: Name of the virtual server
    default: 127.0.0.1
  webapp.greeting:
    description: Message that will be displayed by the deployed app
    default: Hello, world!

```

We are declaring that we will be using the `apache2` package and we are listing all our templates providing the paths where bosh will place them after instantiating. These paths are relative to the jobs dir on the system being installed. Usually this is `/var/vcap/jobs/webapp`.

For tha sake of clarity I won't paste the actual content of the templates in this README. You can find them [here](jobs/webapp/templates). Have a look at them and copy them in your `jobs/webapp/templates` folder.

Bosh is using [monit](https://mmonit.com/monit) for monitoring the processes it runs. So the last bit we need to provide is a monit config file for the job.

It looks like this

```
check process webapp
  with pidfile /var/vcap/sys/run/webapp/httpd.pid
  start program "/var/vcap/jobs/webapp/bin/webapp_ctl start" with timeout 60 seconds
  stop program "/var/vcap/jobs/webapp/bin/webapp_ctl stop" with timeout 60 seconds
  group vcap

```

It tells monit what pid to watch for and it also points to the `webapp_ctl` script taht we created for lifecycle management of the server.

### Describe your deployment

## Pull the trigger

### Upload stemcell
### Create & upload a development release
### Deploy

## Customize the app

### Tweak some property
### Redeploy
