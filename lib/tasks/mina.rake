require 'mina/deploy'
require 'mina/bundler'

set :rails_env, 'production'
set :bundle_prefix, -> { %{RAILS_ENV="#{fetch(:rails_env)}" #{fetch(:bundle_bin)} exec} }
set :rake, -> { "#{fetch(:bundle_prefix)} rake" }
set :rails, -> { "#{fetch(:bundle_prefix)} rails" }
set :compiled_asset_path, 'public/dist'
set :asset_dirs, [ 'app/coffeescripts/', 'public/images/', 'app/stylesheets/',
                   'app/jsx/', 'app/frontend_build/']
# , 'public/javascripts/', 'public/fonts/'
#                   ]

set :shared_dirs, fetch(:shared_dirs, []).push('log', 'tmp/cache', fetch(:compiled_asset_path))

namespace :mina_canvas do
  desc 'Precompiles assets (skips if nothing has changed since the last release).'
  task :compile_assets do
    if fetch(:force_asset_precompile)
      comment %{Precompiling asset files}
      command %{#{fetch(:rake)} canvas:compile_assets}
    else
      command check_for_changes_script(
                  at: fetch(:asset_dirs),
                  skip: %{echo "-----> Skipping asset precompilation"},
                  changed: %{echo "-----> Precompiling asset files" }
              ), quiet: true
    end
    #{echo_cmd "#{fetch(:rake)} canvas:compile_assets"}
  end
end

def check_for_changes_script(options)
  diffs = options[:at].map do |path|
    %{diff -qrN "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
  end.join(' && ')


  %{
    echo $(#{diffs})
    if #{diffs}
    then
      #{options[:skip]}
    else
      #{options[:changed]}
    fi
  }
end

# Macro used later by :rails, :rake, etc
make_run_task = lambda { |name, example|
  task name, [:arguments] do |_, args|
    set :execution_mode, :exec

    arguments = args[:arguments]
    unless arguments
      puts %{You need to provide arguments. Try: mina "#{name}[#{example}]"}
      exit 1
    end
    in_path "#{fetch(:current_path)}" do
      command %(#{fetch(name)} #{arguments})
    end
  end
}

