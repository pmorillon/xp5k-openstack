# xp5k-openstack

## Usage

### From a grid5000 frontend

#### Initial setup

* Clone the repository :

```Shell
git clone https://github.com/pmorillon/xp5k-openstack.git
```

__Notes__ : Openstack delpoyment is quite long, it would be safer to continue into a [screen](https://www.gnu.org/software/screen/manual/screen.html) environment.

* Setup environment :

```Shell
cd xp5k-openstack
source setup_frontend.sh
gem install bundler
bundle install
```

__Notes__ : use `rehash` command if you use `zsh` in order to update _$PATH_ (if `bundle`or `rake`commands are not found).

#### Begin an experiment

* Setup environment :

```
cd xp5k-openstack
source setup_frontend.sh
```

* Configure experiment. Create a file `xp.conf` :

```Ruby
site            'rennes'
walltime        '4:00:00'

public_key      "/home/pmorillo/.ssh/id_rsa.pub"
gateway         "#{ENV['USER']}@frontend.#{self[:site]}.grid5000.fr"
```

__Notes__ : Ensure that you can connect to other frontends through SSH without password.

* Start experiment :

```Shell
rake run
```

__Notes__ : ☕️ ☕️ (estimated time: 20-30 minutes)

* Connect to the controller through SSH :

```Shell
rake shell host=controller
```

* Play with openstack

```Shell
source openstack-openrc.sh
glance image-list
+--------------------------------------+----------------------+
| ID                                   | Name                 |
+--------------------------------------+----------------------+
| a73a553e-6ea2-47dc-af84-6880f5b584b5 | Cirros               |
| a55aa773-050a-404e-9aca-a1519bb6ec65 | Debian Jessie 64-bit |
+--------------------------------------+----------------------+
neutron subnet-list
+--------------------------------------+----------------+----------------+---------------------------------------------------+
| id                                   | name           | cidr           | allocation_pools                                  |
+--------------------------------------+----------------+----------------+---------------------------------------------------+
| a642ba2b-d69c-4124-ad2c-95e3b935736f | private-subnet | 192.168.1.0/24 | {"start": "192.168.1.10", "end": "192.168.1.100"} |
| 23524d61-fc31-4354-81af-ed042301e1e3 | public-subnet  | 10.156.0.0/14  | {"start": "10.158.0.10", "end": "10.158.0.100"}   |
+--------------------------------------+----------------+----------------+---------------------------------------------------+
```

### From an external network

In progress...

## How it works

This installation method of Openstack on Grid'5000 offer to the user common tasks to :
* Reserve resources and manage a [OAR](https://oar.imag.fr) job.
* Deploy nodes with [Kadeploy](http://kadeploy3.gforge.inria.fr).
* Install a [Puppet](https://puppetlabs.com/puppet/what-is-puppet) server.
* Manage [Puppet modules](https://github.com/openstack/puppet-openstack-integration) maintained by Openstack.

### Rake

[Rake](http://rake.rubyforge.org) is a simple ruby build program with capabilities similar to make. Tasks are defined in a `Rakefile` and can be listed with command :

```
rake -T
```

### XP5K

[XP5K](https://github.com/pmorillon/xp5k) is a small Ruby library to help Grid'5000 users to script their experiments using the Grid'5000 API :
* Submit one or several jobs, get the status, remove jobs, no needs to know the job ID.
* Create Roles (list of nodes dedicated for a specific role, ex : _puppetserver_, _controller_, _computes_), no needs to know the hostname of allocated resources.
* Create one or several deployment on nodes defined by a job, by roles.
* Extend the Rake DSL to :
  * create roles,
  * launch parallel SSH commands on a list of nodes or roles through a SSH gateway (the gateway allow you to launch experiments from your personal computer).
* Read an experiment configuration file `xp.conf` to customize your experiment instance.
* Manage a file `.xp_cache` containing the context of an experiment instance (jobs, roles, ...)

### Main tasks

Main tasks are defined in the `Rakefile` and on `tasks/*.rb` files.

```
rake cmd                        # Launch command in parallel, need cmd=<command> and host=<role|FQDN>
rake grid5000:clean             # Clean all OAR jobs
rake grid5000:deploy            # Submit Kadeploy environment deployment
rake grid5000:jobs              # Submit OAR jobs
rake grid5000:status            # Get OAR jobs status
rake puppet:agent:install       # Install Puppet agent package on all nodes
rake puppet:agent:run           # Puppet Puppet agent on node host=<role|FQDN>
rake puppet:hiera:generate      # Generate hiera database
rake puppet:modules:get         # Download external openstack Puppet modules
rake puppet:modules:remove      # Delete external Puppet modules
rake puppet:modules:upload      # Upload Puppet modules and hiera database
rake puppet:server:bootstrap    # bootstrap Puppet server
rake run                        # Start Openstack deployment
rake shell                      # ssh on host, need host=<role|FQDN>
```

The `run` task is a flow of tasks that prepare the experiment and launch at the end the main task of a scenario `scenario:main` (explained in the section below).

### Scenarios

Scenarios are placed in `./scenarios` directory. The default scenario is `liberty_starter_kit`. To use another scenario, update the `xp.conf` file with :

```
scenario 'scenario_name'
```

A scenario must be at least composed by :
* A `./Puppetfile` file, that contain a list of external Puppet modules used.
* A `./puppet/modules` directory for Puppet modules dedicated to the scenario.
* A `./puppet/hiera` directory, with :

```
├── generated (empty directory)
└── templates
    ├── common.yaml
    └── nodes
        └── puppetserver.yaml
```

`common.yaml`:

```
---
classes:
- xp
- xp::locales
```

`puppetserver.yaml` :

```
---
classes:
- xp::puppet::server
puppet::server::autosign:
- host1
```

* A `./tasks/scenario.rb` file with at least :

```Ruby
# Scenario dedicated Rake task
#

# Define OAR job (required)
#
xp.define_job(@job_def)


# Define Kadeploy deployment (required)
#
xp.define_deployment(@deployment_def)


namespace :scenario do

  # Required task
  desc 'Main task called at the end of `run` task'
  task :main do

  end

end
```
