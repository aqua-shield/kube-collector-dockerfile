FROM ubuntu:18.04 as intermediate
ARG SSH_PUBLIC_KEY
RUN apt-get update
RUN apt-get install -y python3 python3-pip git ssh
# Authorize SSH Host
RUN mkdir -p /root/.ssh && \
 chmod 700 /root/.ssh && \
 ssh-keyscan -T 60 bitbucket.com >> /root/.ssh/known_hosts
# Add the keys and set permissions
RUN echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa && \
 echo "$SSH_PUBLIC_KEY" > /root/.ssh/id_rsa.pub
RUN chmod 600 /root/.ssh/id_rsa && \
 chmod 600 /root/.ssh/id_rsa.pub
RUN mkdir /app
ARG CACHEBUST=1
RUN GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone --branch kube_logger https://yuvalsteuer:1234qwerHuckci1*@bitbucket.org:/scalock/qa_scripts.git app

FROM ubuntu:19.10
RUN mkdir app
RUN mkdir app/kube-logger
COPY --from=intermediate /app/kube-logger /app/kube-logger
RUN apt update
RUN apt install -y python3 python3-pip libevent-dev
WORKDIR /app/kube-logger
RUN pip3 install --upgrade pip
RUN pip3 install setuptools
RUN pip3 install wheel 
RUN pip3 install setuptools_scm
RUN pip3 install -r requirements.txt
EXPOSE 8081
RUN apt remove -y binutils
RUN echo "1" | apt remove -y util-linux --allow-remove-essential
RUN rm -rf /usr/local/lib/python3.7/dist-packages/gevent/tests
CMD python3 logger_web/__init__.py


