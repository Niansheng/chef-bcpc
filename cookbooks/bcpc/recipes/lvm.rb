#
# Cookbook Name:: bcpc
# Recipe:: lvm
#
# Copyright 2015, Bloomberg Finance L.P.
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

if node['bcpc']['nova']['ephemeral']
  package 'lvm2' do
    action :upgrade
  end

  # LVM watches its configuration file and will reload automatically
  template '/etc/lvm/lvm.conf' do
    source 'lvm.conf.erb'
    owner  'root'
    group  'root'
    mode   00644
    variables(
      :lvm_whitelist => node['bcpc']['nova']['ephemeral_disks'].map { |dev| "\"a|^#{dev}$|\", " }.join
    )
  end

  bash "setup-lvm-pv" do
    user "root"
    code <<-EOH
      pvcreate #{ node['bcpc']['nova']['ephemeral_disks'].join(' ') }
    EOH
    not_if "pvdisplay | grep '/dev'"
  end

  bash "setup-lvm-lv" do
    user "root"
    code <<-EOH
      vgcreate nova_disk  #{ node['bcpc']['nova']['ephemeral_disks'].join(' ') }
    EOH
    not_if "vgdisplay nova_disk"
  end

  # LVM creates backups of metadata at each operation, clean old ones up
  cron 'lvm-archive-cleanup' do
    command '/usr/bin/find /etc/lvm/archive/ -type f -ctime +7 -delete'
    hour '3'
    minute '0'
  end
end
