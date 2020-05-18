# S3 Gem Host
This gem provides rake tasks for publishing and managing Ruby gems hosted on Amazon S3.

## Installation

Add this gem to your gem's Gemfile:
```ruby
# Gemfile
gem 's3_gem_host'
```

Require this bundler/gem_tasks (recommended) and this gem in your Rakefile
```ruby
# Rakefile

require 'bundler/gem_tasks' # Recommended
require 's3_gem_host'
```

Run `rake -T` and you should see this Gem's tasks available for use.
```
➜ rake -T
rake build                      # Build your-gem-x.x.x.gem into the pkg directory
rake clean                      # Remove any temporary products
rake clobber                    # Remove any generated files
rake install                    # Build and install your-gem-x.x.x.gem into system gems
rake install:local              # Build and install your-gem-x.x.x.gem into system gems without network access
rake release[remote]            # Create tag vx.x.x and build and push s3_gem_host-1.0.0.gem to rubygems.org
rake s3_gem_host:push           # Publish a newly built gem version to S3
rake s3_gem_host:yank[version]  # Remove a previously published gem version from S3
rake spec                       # Run RSpec code examples
```

## Configuration

Set the following environment variables (such as when using this gem in your CI/CD pipeline):
* `S3_GEM_HOST_AWS_ACCESS_KEY_ID`: The AWS Access Key ID to use to write to your S3 bucket
* `S3_GEM_HOST_AWS_SECRET_ACCESS_KEY`: The AWS Secret Access Key to use to write to your S3 bucket
* `S3_GEM_HOST_BUCKET`: The S3 bucket where you want to host your gems. This must be an existing S3 bucket. You
should create a new S3 bucket for hosting your gems. Multiple gems may be hosted in the same bucket.
* `S3_GEM_HOST_AWS_REGION`: The AWS region where your S3 bucket is hosted; defaults to 'us-east-1'

## Usage

1. Create an S3 bucket to be your "gem server".
* Each gem you publish will maintain its own source via a root directory in this bucket.

2. You will need to provide https access to your S3 bucket to use it as a Bundler gem source as Bundler does not
support S3 sources natively. An easy way is to use a CloudFront distribution, which you can secure via http basic auth
using a Lambda Function. See [Wiki](https://github.com/webandtech/s3_gem_host/wiki) for instructions.

3. Your gem publishing pipleline should look something like this:
    1. `bundle exec rake release:guard_clean` # from bundler/gem_tasks: check for any uncommitted files
    2. `bundle exec rake build` # from bundler/gem_tasks: build your new gem file
    3. `bundle exec rake release:source_control_push` # from bundler/gem_tasks: tag and push the new version to source control
    4. `bundle exec rake s3_gem_host:push` # from this gem: push your gem to S3
      * You will receive an error if you are missing any of the required ENV variables - see [Configuration](#configuration)
      
4. Use your gem via the `source` option. The root directory of the source is your gem name, i.e.
```ruby
# Gemfile

gem 'your-private-gem', source: 'https://username:password@yours3bucket/your-private-gem'
```

### Yanking a Gem
You can unpublish a gem from S3 using the `s3_gem_host:yank` Rake task. For example:
* `bundle exec rake s3_gem_host:yank[2.10.1]` will remove your gem version 2.10.1 from the S3 bucket and associated
index.

## How it works

1. The rake task `s3_gem_host:push` pulls down the current contents of your S3 bucket into a cache dir,
starting at `/{gem_name}`
2. Your newly built gem is copied into the cache dir
3. An index is created using the `gem generate_index` command
4. All files are pushed back up to S3

## Using your S3 Gem Host

See the [Wiki](https://github.com/webandtech/s3_gem_host/wiki).