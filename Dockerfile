###### compute node
# runs slurmd, sshd and is able to execute jobs via mpi
FROM qnib/terminal
MAINTAINER "Christian Kniep <christian@qnib.org>"

##### USER
# Set (very simple) password for root
RUN echo "root:root"|chpasswd
ADD root/ssh /root/.ssh
RUN chmod 600 /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/id_rsa
RUN chmod 644 /root/.ssh/id_rsa.pub
RUN chown -R root:root /root/*

### SSHD
RUN yum install -y openssh-server
RUN mkdir -p /var/run/sshd
RUN sshd-keygen
RUN sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
ADD root/ssh /root/.ssh/
ADD etc/supervisord.d/sshd.ini /etc/supervisord.d/sshd.ini

# We do not care about the known_hosts-file and all the security
####### Highly unsecure... !1!! ###########
RUN echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config
RUN echo "        AddressFamily inet" >> /etc/ssh/ssh_config

# carboniface
ADD rpms/python-carboniface-1.0.3-1.x86_64.rpm /tmp/rpms/
RUN yum install -y python-docopt /tmp/rpms/python-carboniface-1.0.3-1.x86_64.rpm

# whisper
RUN 	yum install -y python-carbon git-core
RUN     mkdir -p /var/lib/carbon/{whisper,lists}
RUN 	chown carbon -R /var/lib/carbon/whisper/
ADD     ./etc/supervisord.d/carbon.ini /etc/supervisord.d/

# graphite-web
RUN 	yum install -y nginx python-django python-django-tagging pyparsing pycairo python-gunicorn pytz
RUN 	useradd www-data
RUN 	mkdir -p /var/lib/graphite-web/log/webapp
ADD     ./etc/nginx/nginx.conf /etc/nginx/nginx.conf
WORKDIR /usr/share
RUN 	git clone https://github.com/graphite-project/graphite-web.git

#### Config
## graphite web
ADD     ./local_settings.py /usr/share/graphite-web/webapp/graphite/
ADD     ./initial_data.json /usr/share/graphite-web/webapp/initial_data.json
WORKDIR /usr/share/graphite-web/webapp/
RUN 	python manage.py syncdb --noinput
RUN 	chown www-data:www-data -R /var/lib/graphite-web/
ADD     etc/supervisord.d/nginx.ini /etc/supervisord.d/
ADD 	etc/supervisord.d/graphite-web.ini /etc/supervisord.d/

## Carbon config
ADD     ./etc/carbon/c0.conf /etc/carbon/
ADD     ./etc/carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf

# tidy up
RUN 	rm -f /usr/share/graphite-web/webapp/initial_data.json
RUN 	rm -rf /tmp/rpms



CMD /bin/supervisord -c /etc/supervisord.conf
