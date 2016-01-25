#
# Cookbook Name:: bcpc
# Recipe:: system
#
# Copyright 2013, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "bcpc::default"

# FOR NEUTRON WIP
# hack to ensure bridge sysctl items can be set
bash 'modprobe-bridge' do
  code 'modprobe bridge'
end

template "/etc/sysctl.d/70-bcpc.conf" do
    source "sysctl-70-bcpc.conf.erb"
    owner "root"
    group "root"
    mode 00644
    variables(
        :additional_reserved_ports => node['bcpc']['system']['additional_reserved_ports'],
        :parameters                => node['bcpc']['system']['parameters']
    )
    notifies :run, "execute[reload-sysctl]", :immediately
end

execute "reload-sysctl" do
    action :nothing
    command "sysctl -p /etc/sysctl.d/70-bcpc.conf"
end

bash "set-deadline-io-scheduler" do
    user "root"
    code <<-EOH
        for i in /sys/block/sd?; do
            echo deadline > $i/queue/scheduler
        done
        echo GRUB_CMDLINE_LINUX_DEFAULT=\\\"\\$GRUB_CMDLINE_LINUX_DEFAULT elevator=deadline\\\" >> /etc/default/grub
        update-grub
    EOH
    not_if "grep 'elevator=deadline' /etc/default/grub"
end

ruby_block "swap-toggle" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/fstab")
    if node['bcpc']['enabled']['swap'] then
      rc.search_file_replace(
        /^#([A-Z].*|\/.*)swap(.*)/,
        '\\1swap\\2'
      )
      rc.write_file
      system 'swapon -a'
    else
      system 'swapoff -a'
      rc.search_file_replace(
        /^([A-Z].*|\/.*)swap(.*)/,
        '#\\1swap\\2'
      )
      rc.write_file
    end
  end
end
