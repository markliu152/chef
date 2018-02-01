#
# Cookbook Name:: zabbix2
# Recipe:: default
#
# Copyright 2014, Adam Balali
#
# All rights reserved - Do Not Redistribute
#
case node["platform"]
  when "redhat"
    remote_file node['zabbix']['file_path'] do
      source "#{node['zabbix']['zabbix_repo']}"
      not_if "rpm -qa | grep 'zabbix-release'"
      notifies :install, "rpm_package[zabbix-release]", :immediately
      retries 5 # We may be redirected to a FTP URL, CHEF-1031.
    end

    rpm_package "zabbix-release" do
      source node['zabbix']['file_path']
      only_if { ::File.exists?(node['zabbix']['file_path']) }
      action :nothing
    end

    file "zabbix-release-cleanup" do
      path node['zabbix']['file_path']
      action :delete
    end

    ruby_block 'copy Zabbix-Agent to the target directory' do
      block do
        arch = node[:kernel][:machine] == 'x86_64' ? 'win64' : 'win32'

        FileUtils.cd("#{cache_path}/zabbix/bin") do
          source = Dir["#{arch}"].detect { |file| File.directory? file }
          target = node['zabbix']['zabbix_agent']['install_target']

          Chef::Log.info "Checking for Zabbix-Agent in #{source}"

          if source
            FileUtils.mkdir_p target

            FileUtils.cd(source) do
              Chef::Log.info "Attempting to copy file from #{FileUtils.pwd}"

              FileUtils.cp_r('.', target)
            end
          end
        end
      end
      not_if { ::File.exists?(node['zabbix']['zabbix_agent']['install_target']) }
    end
  else
    Chef::Log.info "#{node['platform']} is not supported yet."
end

package 'zabbix-agent' if platform_family?("centos", "rhel")

template node['zabbix']['zabbix_agent']['config_path'] do
  source "#{node['zabbix']['zabbix_agent']['config_template']}"
  mode '0640'
  variables({
                :server_ip => "#{node['zabbix']['server_ip']}"
            })
end

  execute 'start zabbix-agent' do
    cwd node['zabbix']['zabbix_agent']['install_target']
    command "zabbix_agentd.exe --config #{node['zabbix']['zabbix_agent']['config_path']} --start"
    only_if { ::File.exist?("#{node['zabbix']['zabbix_agent']['install_target']}/zabbix_agentd.exe") }
  end
else
  service node['zabbix']['zabbix_agent']['name'] do
    action [:enable, :start]
  end
end
