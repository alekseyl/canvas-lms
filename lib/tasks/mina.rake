require 'mina/deploy'
require 'mina/bundler'

set :compiled_asset_path, 'public/dist'
set :shared_dirs, fetch(:shared_dirs, []).push('log', 'tmp/cache', fetch(:compiled_asset_path))

set :rails_env, 'production'
set :bundle_prefix, -> { %{RAILS_ENV="#{fetch(:rails_env)}" #{fetch(:bundle_bin)} exec} }
set :rake, -> { "#{fetch(:bundle_prefix)} rake" }
set :rails, -> { "#{fetch(:bundle_prefix)} rails" }


set :asset_dirs, %w( app/coffeescripts/ public/images/ app/stylesheets/ config/locales/
                     app/jsx/ public/javascripts/ app/client_apps app/views/jst config/build.js.erb )

# на локейлы не будем обращать если будет потребность пересобрать локейлы для JS надо форсить,
# а то будем собирать все время
set :separated_assets_dirs, {
                              css: { dirs: %w(app/stylesheets/), env: 'COMPILE_ASSETS_CSS' },
                              # Не получится таким макаром с оптимизировать npm, он не соберет ассеты при таком раскладе.
                              # npm: { dirs: %w(bower.json package.json .bowerrc ),
                              #        env: 'COMPILE_ASSETS_NPM_INSTALL'  },
                              gulp: {
                                  dirs: %w( public/images/ public/fonts/ ),
                                  env: 'COMPILE_ASSETS_GULP_APART_FROM_JS'
                                  # галп будет проверяться по совокупности с js но это надо проверить так как
                                  # он опирается на оптимизированные ассеты а они не включены в шаред пути и в реп, т.е. после деплоя пропадут
                              },
                              js: { dirs: %w( package.json
                                              .bowerrc
                                              client_apps
                                              config/build.js.erb
                                              app/jsx
                                              public/javascripts
                                              app/coffeescripts
                                              frontend_build
                                              app/views/jst ),
                                    env: 'COMPILE_ASSETS_COMPILE_JS' }
                          }

# COMPILE_ASSETS_COMPILE_JS
# , , 'public/fonts/'
# I18n.load_path.unshift(*WillPaginate::I18n.load_path)
# I18n.load_path += Dir[Rails.root.join('gems', 'plugins', '*', 'config', 'locales', '*.{rb,yml}')]
# I18n.load_path += Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')]
#  images + fonts => gulp идет последним,
#                  ]


set :shared_dirs, fetch(:shared_dirs, []).push('log', 'tmp/cache', fetch(:compiled_asset_path))

namespace :mina_canvas do
  desc 'Precompiles assets (skips if nothing has changed since the last release).'
  task :compile_assets do
    if fetch(:force_asset_precompile)
      comment %{Precompiling asset files}
      command %{#{fetch(:rake)} canvas:compile_assets}
    else
      fetch(:separated_assets_dirs).each_value do | dirs_env|
        command check_for_changes_script(
                    at: dirs_env[:dirs],
                    skip: %{echo "-----> Skipping #{dirs_env[:env]} in assets compilation"
                            export #{dirs_env[:env]}=0 },
                    #
                    changed: %{ #{dirs_env[:dirs].map do |path|
                      %{diff -qrN "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
                    end.inspect }
                    echo "-----> Precompiling asset will use #{dirs_env[:env]} ( #{dirs_env[:dirs].inspect} )"}
                )
        # , quiet: true

      end
      command %{#{fetch(:rake)} canvas:compile_assets}
    end
  end
end

# diff -qrN --no-dereference --exclude="node_modules" --exclude="tmp" --exclude="dist" /client_apps/
# diff -rqN --no-dereference --exclude="compiled" --exclude="bower" --exclude="client_apps" --exclude="translations" --exclude="jsx" --exclude="jst"

def check_for_changes_script_separated(options)
  diffs = options[:at].map do |path|
    if path == 'public/javascripts/'
      # это все скомпиленные директории
      %{diff -rqN --no-dereference
            --exclude="compiled"
            --exclude="client_apps"
            --exclude="translations"
            --exclude="jsx"
            --exclude="jst"
            "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
    elsif path == 'app/coffeescripts'
      %{diff -rqN --no-dereference
            --exclude="node_modules"
            --exclude="tmp"
            --exclude="dist"
            "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
    elsif path == 'client_apps'
      %{diff -rqN --no-dereference --exclude='main.coffee' "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
    else
      %{diff -qrN --no-dereference "#{fetch(:current_path)}/#{path}" "./#{path}" 2>/dev/null}
    end

  end.join(' && ')

  %{
    if #{diffs}
    then
      #{options[:skip]}
    else
      #{options[:changed]}
    fi
  }
end


