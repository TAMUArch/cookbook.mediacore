include_recipe "mediacore::packages"

[ node[:mediacore][:dir],
  node[:mediacore][:venv],
  node[:mediacore][:log_location]
].each do |dir|
  directory dir do
    action :create
    owner node[:mediacore][:user]
    group node[:mediacore][:group]
    mode "0775"
  end
end

git node[:mediacore][:dir] do
  repo node[:mediacore][:git_repo]
  reference "v#{node[:mediacore][:version]}"
  user node[:mediacore][:user]
  group node[:mediacore][:group]
  notifies :run,"execute[mediacore_setup]",:delayed
end

python_virtualenv node[:mediacore][:venv] do
  owner node[:mediacore][:user]
  group node[:mediacore][:group]
  options "--distribute --no-site-packages"
  action :create
end

python_pip "uwsgi" do
  action :install
end

case node[:mediacore][:db_type]
when "postgresql"
  include_recipe "postgresql::server"
  python_pip "psycopg2" do
    action :install
    virtualenv node[:mediacore][:venv]
  end
end
  
execute "mediacore_setup" do
  user node[:mediacore][:user]
  cwd node[:mediacore][:dir]
  command "#{node[:mediacore][:venv]}/bin/python setup.py develop"
  action :nothing
  notifies :run, "execute[application_migration]", :delayed
end

execute "application_migration" do
  user node[:mediacore][:user]
  cwd node[:mediacore][:dir]
  command "#{node[:mediacore][:venv]}/bin/paster setup-app deployment.ini"
  action :nothing
end

template "#{node[:mediacore][:dir]}/deployment.ini" do
  action :create
  owner node[:mediacore][:user]
  group node[:mediacore][:group]
  source "deployment.ini.erb"
end

template "#{node[:mediacore][:dir]}/uwsgi.ini" do
  action :create
  owner node[:mediacore][:user]
  group node[:mediacore][:group]
  variables(
    :socket => node[:mediacore][:uwsgi][:socket],
    :master => "true",
    :processes => "5",
    :home => node[:mediacore][:venv],
    :daemonize => "#{node[:mediacore][:log_location]}/mediacore_uwsgi.log"
  )
end
include_recipe "supervisor"
include_recipe "mediacore::web_server"

supervisor_service "mediacore" do
  command "uwsgi --emperor \"#{node[:mediacore][:dir]}/uwsgi.ini\" --die-on-term --uid #{node[:mediacore][:user]} --gid #{node[:mediacore][:group]} --logto #{node[:mediacore][:log_location]}/mediacore.log"
  user node[:mediacore][:user]
  numprocs 1
  autostart true
  autorestart true
  exitcodes [ 0, 2 ]
  stopsignal "TERM"
  directory node[:mediacore][:dir]
end
