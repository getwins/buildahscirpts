#!/usr/bin/bash

ctr1=$(buildah from quay.io/generic/centos6)

buildah run "$ctr1" -- rpm --rebuilddb
buildah run "$ctr1" -- yum install createrepo  -y
buildah run "$ctr1" -- yum install -y https://repo.zabbix.com/zabbix/4.0/rhel/6/x86_64/zabbix-release-4.0-1.el6.noarch.rpm
buildah config --volume /var/www/html  "$ctr1"

buildah run "$ctr1" -- /bin/bash -c '
cat <<EOF >/bin/mkrepo.sh
#!/bin/bash

# sync centos base repository
mkdir -p /var/www/html/repos/centos/6/os/x86_64
mkdir -p /var/www/html/repos/centos/6/extras/x86_64
mkdir -p /var/www/html/repos/centos/6/updates/x86_64
mkdir -p /var/www/html/repos/centos/6/centosplus/x86_64

reposync  --repoid=base --norepopath --download_path=/var/www/html/repos/centos/6/os/x86_64 --downloadcomps --download-metadata
reposync  --repoid=extras --norepopath --download_path=/var/www/html/repos/centos/6/extras/x86_64 --downloadcomps --download-metadata
reposync  --repoid=updates --norepopath --download_path=/var/www/html/repos/centos/6/updates/x86_64 --downloadcomps --download-metadata
reposync  --repoid=centosplus --norepopath --download_path=/var/www/html/repos/centos/6/centosplus/x86_64 --downloadcomps --download-metadata

createrepo --update -g comps.xml /var/www/html/repos/centos/6/extras/x86_64 
createrepo --update /var/www/html/repos/centos/6/extras/x86_64 
createrepo --update /var/www/html/repos/centos/6/extras/x86_64 
createrepo --update /var/www/html/repos/centos/6/extras/x86_64 

cp -u /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS* /var/www/html/repos/centos/

# sync zabbix repository
mkdir -p /var/www/html/repos/zabbix/zabbix/4.0/rhel/6/x86_64
mkdir -p /var/www/html/repos/zabbix/non-supported/rhel/6/x86_64
# for rhel6 releasever
cd /var/www/html/repos/zabbix/zabbix/4.0/rhel/
if [ ! -e 6Server ]; then
	ln -s 6 6Server
fi
cd /var/www/html/repos/zabbix/non-supported/rhel/
if [ ! -e 6Server ]; then
	ln -s 6 6Server
fi

reposync  --repoid=zabbix --norepopath --download_path=/var/www/html/repos/zabbix/zabbix/4.0/rhel/6/x86_64 --downloadcomps --download-metadata
reposync  --repoid=zabbix-non-supported --norepopath --download_path=/var/www/html/repos/zabbix/non-supported/rhel/6/x86_64 --downloadcomps --download-metadata

createrepo /var/www/html/repos/zabbix/zabbix/4.0/rhel/6/x86_64 
createrepo /var/www/html/repos/zabbix/non-supported/rhel/6/x86_64

cp -u /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX* /var/www/html/repos/zabbix/
 
EOF'

buildah run "$ctr1" -- chmod +x /bin/mkrepo.sh

buildah config --entrypoint "/bin/mkrepo.sh" "$ctr1"
buildah config --author "Chen Huiping"

buildah commit "$ctr1" "centos6repo"

