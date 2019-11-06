# Simple Bosh Release

## What on earth is this?

This is a very simple bosh release for a static webpage hosted by `apache2` server. It has only one job and only one package. This is as simple as it gets. You can only deploy it on bosh-lite, so you won't need to generate the deployment manifest and deal with complex parameter substitution and merging stubs and templates.

If you want to grasp the very basic things about `bosh` then read on - we will be building the simplest release in the world step by step, explaining the concepts, starting from scratch.

## What are you talkin' about?

If you are unfamiliar with `bosh` and its basic terminology and want to dig deeper, [this](http://bosh.io/docs) may be a good place to start.

`bosh` is the cloud operator's swiss army knife - it is a tool that handles a software project's release, deployment and lifecycle management. It defines a `release` that is comprised of `jobs`, `packages` and `sources`. A `bosh release` is self contained and fully reproducible accross environments. The release depends on a `stemcell` that is an OS image that will be run on each VM (or container) that bosh creates. The `stemcell` encapsulates all external dependencies of a `bosh release`.

## Let's build it!

### Install Boshlite

You can install Bosh lite on your local machine following this [guide](https://bosh.io/docs/bosh-lite/). I suggest you to add the following lines to your .bash_profile so you don't have to initialize these variables any time you start a new terminal.

```
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`
```

### Generate a release scaffold

At this point we have dealt with the boring stuff and can get started. First we need to create an empty bosh release.
Luckily the bosh client can do this for us

```bash
$ mkdir simple-bosh-release
$ cd simple-bosh-release
$ bosh init-release
```

This will create the following file structure

```bash
$ find .
./
./config
./config/blobs.yml
./config/final.yml
./jobs
./packages
./src
```

Here are the most important of these:

- src: this is the source code for the packages
- packages: these are the instructions on how to compile the source into binaries
- jobs: these are the scripts and configuration files required to run the packages

### Add the sources

Our release will need to run the apache http server so we will have to place the `apache2` sources in the `src/` folder.
There is no restriction on the format of the sources, because the release also contains the packaging scripts that are responsible to transform these sources into runnable software. We are going to provide the `apache2` sources as a `.tar.gz` and `.tar.bz2` archives.

```bash
mkdir src/apache2
cd src/apache2
wget http://apache.cbox.biz/httpd/httpd-2.4.39.tar.gz
wget http://mirror.nohup.it/apache/apr/apr-1.7.0.tar.gz
wget http://mirror.nohup.it/apache/apr/apr-util-1.6.1.tar.gz
wget https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz
wget https://github.com/libexpat/libexpat/releases/download/R_2_2_5/expat-2.2.5.tar.bz2
```

### Add the package

Now we have the sources, but these will have to be compiled before we can run the actual server. So we need to add a new package:

```bash
$ cd ../..
$ bosh generate-package apache2
$ find packages
packages/
packages/apache2
packages/apache2/packaging
packages/apache2/spec
```

We have to fill in the `spec` file like this:

```yaml
---
name: apache2

files:
    - apache2/httpd-2.4.39.tar.gz
    - apache2/apr-1.7.0.tar.gz
    - apache2/apr-util-1.6.1.tar.gz
    - apache2/pcre-8.43.tar.gz
    - apache2/expat-2.2.5.tar.bz2
```

It simply specifies what files should go in this package. We only need the archived sources of `apache2`

And let's fill in the `packaging` script itself:

```bash
set -e

echo "Extracting apache httpd server ..."
tar xzf apache2/httpd-2.4.39.tar.gz

echo "Extracting apache httpd server dependencies..."
mkdir -p httpd-2.4.39/srclib/apr
mkdir -p httpd-2.4.39/srclib/apr-util
tar xzf apache2/apr-1.7.0.tar.gz -C httpd-2.4.39/srclib/apr --strip 1
tar xzf apache2/apr-util-1.6.1.tar.gz -C httpd-2.4.39/srclib/apr-util --strip 1
tar xzf apache2/pcre-8.43.tar.gz
tar xjf apache2/expat-2.2.5.tar.bz2
cp expat-2.2.5/lib/expat_external.h httpd-2.4.39/srclib/apr-util/include
cp expat-2.2.5/lib/expat.h httpd-2.4.39/srclib/apr-util/include

echo "Building apache httpd dependencies ..."
cd pcre-8.43
./configure --prefix=${BOSH_INSTALL_TARGET} --disable-cpp
make
make install
cd ../expat-2.2.5
./configure --prefix=${BOSH_INSTALL_TARGET}
make
make install

echo "Building apache httpd ..."
cd ../httpd-2.4.39
./configure --prefix=${BOSH_INSTALL_TARGET} --enable-so --with-included-apr \
    --with-included-apr-util --with-pcre=${BOSH_INSTALL_TARGET}/bin/pcre-config \
    --with-expat=${BOSH_INSTALL_TARGET}
make
make install
```

It extracts the sources, configures and compiles, giving a custom install location - the `$BOSH_INSTALL_TARGET`. This is preset by bosh and it is some path on the filesystem of the VM (or container) being provisioned. For our package it will most likely be `/var/vcap/packages/apache2`

### Add the job

At this point we have the apache httpd server available as a package, which means that bosh knows where to get the sources from and how to compile it, but we still haven't run it, and a server that is not running is generally no good.

Thing that run are usually described as `jobs` in bosh terms. So if we want to run the server we will have to defne a job that knows how to configure and run it.

First let's generate an empty one:

```bash
$ bosh generate-job webapp
$ find jobs
jobs/
jobs/webapp
jobs/webapp/spec
jobs/webapp/monit
jobs/webapp/templates
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

```yaml
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

It tells monit what pid to watch for and it also points to the `webapp_ctl` script that we created for lifecycle management of the server.

### Describe your deployment

That's all there is to it! But it is just a release - a bunch of blueprints that tell bosh where to get what, how to compile it and how to run what it compiles. But in order to run any software we need resources like computers, networks and the like.
We also need to tell bosh how many instances of which jobs to run. All these aspects comprise a `bosh deployment`. A bosh deployment is described in (SURPRISE!) a bosh deployment manifest - a yml descriptor giving bosh all the necessary information to breathe life into a bosh release.

Lets take a look at some key parts of the deployment descriptor `deployments/manifest.yml`.

Bosh should know what releases will be involved in the deployment we are defining:

```yaml
name: simple-bosh-release

releases:
- name: simple-bosh-release
  version: latest
```

We're keeping it simple and depend on only one release, but in real life this is rarely so. Another very important thing is declaring what jobs we intend to run in this deployment. This is done via a mapping between release jobs and instance groups:

```yaml
 instance_groups:
- name: webapp
  azs: [z1, z2, z3]
  instances: 1
  jobs:
  - name: webapp
    release: simple-bosh-release
    properties:
      webapp:
        admin: foo@bar.com
        servername: 10.244.1.2
  stemcell: default
  vm_type: default
  networks:
    - name: webapp-network
      static_ips:
        - 10.244.1.2
```

We want one instance of the webapp job we just defined. This job will be run on a VM and it will be on a static ip in a network called `webapp-network`. Because any software need to run on some machine in some network, right?

But wait, where does this `webapp-network` come from? Well, that we need to define ourselves in a cloud config descriptor `deployments/cloud-config.yml`, so let's do it. Here is how a network is defined:

```yaml
networks:
- name: webapp-network
  subnets:
  - azs:
    - z1
    - z2
    - z3
    dns:
    - 8.8.8.8
    gateway: 10.244.1.1
    range: 10.244.1.0/24
    static:
    - 10.244.1.2
  type: manual
```

Now that's scary! Well, not as much - it's more verbose than complex. What we are doing is the following:
- we declare there is one network called `webapp-network` and it has type `manual`. This means that we will define all subnets by hand.
- we define a subnet. The subnet that we are defining has a network mask of 255.255.255.0 or 24 bits. This leaves only 256 addresses as follows (for example):
  - 10.244.1.0 - this is the network address
  - 10.244.1.1 - this is normally used as the gateway
  - 10.244.1.2 to 10.244.1.254 - those are ip addresses that bosh can use for something
  - 10.244.1.255 - this is a broadcast address
In the subnet we are using 10.244.1.1 as the gateway and we tell bosh that we want one static ip (10.244.1.2). We assigned this static ip to the job, because we want it to be available on the same address on every start. Some of the IPs that are not listed as static will be used also during package compilation - BOSH will spin up a VM with a dynamic IP allocated from the specified range and compile the packages on those VMs.

Actually the compilation worker vms are also configured in the cloud config file:

```yaml
compilation:
  az: z1
  network: webapp-network
  reuse_compilation_vms: true
  vm_type: default
  workers: 5
```

We need one worker that is on the same network that we defined for our app - hence the need for two subnets in our network definition. So one subnet goes to the job and one subnet goes to the compilation worker. Actually this pattern is not enforced - you are free to use one big subnet for both the jobs and the compilation workers.

Note: You can find the complete deployment descriptor and cloud config for this example respectively [here](deployments/manifest.yml) and [here](deployments/cloud-config.yml) . Take a look at them and place them under a directory called `deployments` in the release root.

And that's it - we defined a deployment. Let's go play with it.

## Pull the trigger

### Upload stemcell

First we need to give bosh the stemcell that we specified in the deployment manifest. This [bosh docs](http://bosh.io/docs/uploading-stemcells.html) do a great job explaining this

```bash
bosh upload-stemcell --sha1 632b2fd291daa6f597ff6697139db22fb554204c https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-xenial-go_agent?v=315.13
```

### Create & upload a development release

Next we need to create a dev release and upload it to the director:

```bash
$ bosh create-release --force
$ bosh upload-release
```

You will be prompted for the name of the release. You should provide `simple-bosh-release` as the name in order to match up with what we pointed to in the [deployment manifest](deployments/manifest.yml)

### Update cloud config
Before we finally deploy our release we will have to update the cloud config to reflect the needs of our deployment descriptor:

```bash
$ bosh update-cloud-config deployments/cloud-config.yml
```

### Deploy

Aaaand, action:

```bash
$ bosh -d simple-bosh-release deploy deployments/manifest.yml
```
Make sure you can ping the 10.244.1.2 address otherwise add the route rule to redirect traffic to 10.244.1.2 to the Virtual machine ip (suppose it is 192.168.50.6). Depending what OS run on your development machine you can add the following route rule.

```bash
sudo route add -net 10.244.0.0/16     192.168.50.6 # Mac OS X
sudo ip route add   10.244.0.0/16 via 192.168.50.6 # Linux (using iproute2 suite)
sudo route add -net 10.244.0.0/16 gw  192.168.50.6 # Linux (using DEPRECATED route command)
route add           10.244.0.0/16     192.168.50.6 # Windows
```

After some time hopefully the deployment should succeed. And you will be able to access our server on the static ip we allocated:

```bash
$ curl 10.244.1.2
<html><body><h1>Hello, world!</h1></body></html>
```

Hooray! But wait, this is boring - so much effort for one more of these 'Hello, world!' things.

## Customize the app

### Tweak some property

Let's customize the message that we serve. Remember, we parametrized that. We only need to add one line to the deployment manifest (release remains untouched):

```yaml
properties:
  webapp:
    greeting:   Luke, he is your father!
    admin:      foo@bar.com
    servername: 10.244.1.2
```

### Redeploy

Now that we changed the deployment we have to redeploy if we want it to take effect:

```bash
$ bosh -d simple-bosh-release deploy deployments/manifest.yml
```

Bosh will detect the changes that you made to the manifest and will ask your permission to redeploy:

```
Properties
webapp
  + greeting: Luke, he is your father!

Please review all changes carefully
```

## That's it

That's all from this tutorial. I hope you find it helpful. You may want to check out the [bosh docs](http://bosh.io/docs/basic-workflow.html) that cover the basic workflow. Have fun!
