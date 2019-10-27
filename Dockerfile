FROM ubuntu:19.10
RUN mkdir -p app/kube-logger
COPY ./kube-collector /app/kube-logger
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
