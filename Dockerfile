###### compute node
# runs slurmd, sshd and is able to execute jobs via mpi
FROM qnib/fd20
MAINTAINER "Christian Kniep <christian@qnib.org>"

##### USER
# Set (very simple) password for root
RUN echo "root:root"|chpasswd
ADD root/ssh /root/.ssh
RUN chmod 600 /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/id_rsa
RUN chmod 644 /root/.ssh/id_rsa.pub
RUN chown -R root:root /root/*

## supervisord
RUN yum install -y supervisor
RUN mkdir -p /var/log/supervisor
RUN sed -i -e 's/nodaemon=false/nodaemon=true/' /etc/supervisord.conf

### SSHD
RUN yum install -y openssh-server
RUN mkdir -p /var/run/sshd
RUN sshd-keygen
RUN sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
ADD root/ssh /root/.ssh/
ADD etc/supervisord.d/sshd.ini /etc/supervisord.d/sshd.ini

# Diamond
RUN yum install -y python-configobj lm_sensors
ADD rpms /tmp/rpms
RUN yum install -y /tmp/rpms/python-pysensors-0.0.2-1.noarch.rpm
RUN yum install -y /tmp/rpms/python-diamond-3.4.292-1.noarch.rpm
RUN rm -rf /etc/diamond
ADD etc/diamond /etc/diamond
RUN mkdir -p /var/log/diamond
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini

# carboniface
RUN yum install -y python-docopt /tmp/rpms/python-carboniface-1.0.3-1.x86_64.rpm

# whisper
RUN 	yum install -y python-carbon git-core
RUN     mkdir -p /var/lib/carbon/{whisper,lists}
RUN 	chown carbon -R /var/lib/carbon/whisper/
ADD     ./etc/carbon/c0.conf /etc/carbon/
ADD     ./etc/init.d/carbon-cache /etc/init.d/
ADD     ./etc/carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf
ADD     ./etc/supervisord.d/carbon.ini /etc/supervisord.d/

# rsyslog
RUN yum install -y syslog-ng
ADD etc/syslog-ng/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
ADD etc/supervisord.d/syslog-ng.ini /etc/supervisord.d/

### SETUP
ADD root/bin /root/bin
ADD etc/supervisord.d/setup.ini /etc/supervisord.d/setup.ini

### Helper script
ADD root/supervisor_daemonize.sh /root/supervisor_daemonize.sh

# graphite-web
RUN 	yum install -y nginx python-django python-django-tagging pyparsing pycairo python-gunicorn pytz
RUN 	useradd www-data
RUN 	mkdir -p /var/lib/graphite-web/log/webapp
ADD     ./etc/nginx/nginx.conf /etc/nginx/nginx.conf
WORKDIR /usr/share
RUN 	git clone https://github.com/graphite-project/graphite-web.git
ADD     ./local_settings.py /usr/share/graphite-web/webapp/graphite/
ADD     ./initial_data.json /usr/share/graphite-web/webapp/initial_data.json
WORKDIR /usr/share/graphite-web/webapp/
RUN 	python manage.py syncdb --noinput
RUN 	chown www-data:www-data -R /var/lib/graphite-web/
ADD     etc/supervisord.d/nginx.ini /etc/supervisord.d/
ADD 	etc/supervisord.d/graphite-web.ini /etc/supervisord.d/
# tidy up
RUN 	rm -f /usr/share/graphite-web/webapp/initial_data.json
RUN 	rm -rf /tmp/rpms

# We do not care about the known_hosts-file and all the security
####### Highly unsecure... !1!! ###########
RUN echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config


CMD /bin/supervisord -c /etc/supervisord.conf
