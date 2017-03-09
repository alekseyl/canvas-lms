require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'  # for rbenv support. (https://rbenv.org)
require 'mina/rvm'    # for rvm support. (https://rvm.io)
require 'mina/puma'

load File.expand_path("../../lib/tasks/mina.rake", __FILE__)

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :application_name, 'canvas-letovo'
set :domain, '185.158.152.139'
set :deploy_to, '/home/ubuntu/app/canvas-letovo'
set :repository, 'git@github.com:alekseyl/canvas-lms.git'
set :branch, 'stable'
set :user, 'ubuntu'

# Optional settings:
#   set :user, 'foobar'          # Username in the server to SSH to.
#   set :port, '30000'           # SSH port number.
#   set :forward_agent, true     # SSH forward_agent.

# shared dirs and files will be symlinked into the app-folder by the 'deploy:link_shared_paths' step.
# set :shared_dirs, fetch(:shared_dirs, []).push('somedir')
# set :shared_files, fetch(:shared_files, []).push('config/database.yml', 'config/secrets.yml')
set :shared_dirs, fetch(:shared_dirs, []).push('public/uploads', 'log', 'node-modules')
set :shared_files, fetch(:shared_files, []).push('config/database.yml', 'config/security.yml', 'Gemfile.lock')
# ,
#                                                  'app/coffeescripts/ember/screenreader_gradebook/main.coffee')

# This task is the environment that is loaded for all remote run commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .ruby-version or .rbenv-version to your repository.
  # invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  invoke :'rvm:use', 'ruby-2.3.3@canvas-letovo'
  invoke :'env'
end

task :env do
  command %{
    echo "-----> Loading environment"
    #{echo_cmd %[source ~/.bash_profile]}
   }
end

task :env_assets_min do
  command %{
    echo "-----> Minimizing assets compilation settings"
    export COMPILE_ASSETS_API_DOCS=0
    export COMPILE_ASSETS_STYLEGUIDE=0
    #{echo_cmd %[source ~/.bash_profile]}
  }
  ENV["COMPILE_ASSETS_NPM_INSTALL"] != "0"
  ENV["COMPILE_ASSETS_CSS"] != "0"
  ENV["COMPILE_ASSETS_BUILD_JS"] != "0"

end


# Put any custom commands you need to run at setup
# All paths in `shared_dirs` and `shared_paths` will be created on their own.
task :setup do
  command %[mkdir -p "#{fetch(:shared_path)}/log"]
  command %[chmod g+rx,u+rwx "#{fetch(:shared_path)}/log"]

  command %[mkdir -p "#{fetch(:shared_path)}/config"]
  command %[chmod g+rx,u+rwx "#{fetch(:shared_path)}/config"]

  command %[touch "#{fetch(:shared_path)}/Gemfile.lock"]
  command %[touch "#{fetch(:shared_path)}/config/database.yml"]
  command %[touch "#{fetch(:shared_path)}/config/security.yml"]
  command  %[echo "-----> Be sure to edit '#{fetch(:shared_path)}/config/database.yml' and 'security.yml'."]


  # Puma needs a place to store its pid file and socket file.
  command %(mkdir -p "#{fetch(:shared_path)}/tmp/sockets")
  command %(chmod g+rx,u+rwx "#{fetch(:shared_path)}/tmp/sockets")
  command %(mkdir -p "#{fetch(:shared_path)}/tmp/pids")
  command %(chmod g+rx,u+rwx "#{fetch(:shared_path)}/tmp/pids")

  if fetch(:repository)
    repo_host = fetch(:repository).split(%r{@|://}).last.split(%r{:|\/}).first
    repo_port = /:([0-9]+)/.match(fetch(:repository)) && /:([0-9]+)/.match(fetch(:repository))[1] || '22'

    command %[
      if ! ssh-keygen -H  -F #{repo_host} &>/dev/null; then
        ssh-keyscan -t rsa -p #{repo_port} -H #{repo_host} >> ~/.ssh/known_hosts
      fi
    ]
  end

  # Gemfile.lock отуствует а bundle:install все равно первый вызов делает с ключом --deployement
  # что требует наличия Gemfile.lock поэтому первый вызов надо сделать отдельно без него
  set(:bundle_options, -> { %{--without #{fetch(:bundle_withouts)} --path "#{fetch(:bundle_path)}"} } )
  invoke :'git:clone'
  invoke :'deploy:link_shared_paths'
  invoke :'bundle:install'
end

desc "first bundle install."
task :bundle_first do
  deploy do
    set(:bundle_options, -> { %{--without #{fetch(:bundle_withouts)} --path "#{fetch(:bundle_path)}"} } )
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
  end
end

desc "Deploys the current version to the server."
task :deploy do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  # invoke :'git:ensure_pushed'
  deploy do
    set(:bundle_options, -> { %{--without #{fetch(:bundle_withouts)} --path "#{fetch(:bundle_path)}"} } )
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'mina_canvas:compile_assets'
    invoke :'deploy:cleanup'

    on :launch do

    end
  end

  # you can use `run :local` to run tasks on local machine before of after the deploy scripts
  # run(:local){ say 'done' }
end

task :deploy_fast do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  # invoke :'git:ensure_pushed'
  deploy do
    set(:bundle_options, -> { %{--without #{fetch(:bundle_withouts)} --path "#{fetch(:bundle_path)}"} } )
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'mina_canvas:compile_assets'
    invoke :'deploy:cleanup'

    on :launch do

    end
  end

  # you can use `run :local` to run tasks on local machine before of after the deploy scripts
  # run(:local){ say 'done' }
end

task :puma_start do
  on :launch do
    invoke :'puma:restart'
  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - https://github.com/mina-deploy/mina/tree/master/docs
#puma -q -d -e production -S /home/ubuntu/puma/sockets/puma.state -b 'unix:///home/ubuntu/puma/sockets/puma.sock' --control 'unix:///home/ubuntu/puma/sockets/pumactl.sock'
