FROM ubuntu:16.04 AS base

FROM base AS builder

RUN apt-get update && \
  apt-get install -yqq --no-install-recommends \
  python-dev \
  apt-transport-https \
  wget \
  libpcap-dev \
  tesseract-ocr \
  default-jdk \
  build-essential \
  cmake \
  unzip \
  yasm \
  pkg-config \
  libswscale-dev \
  libtbb2 \
  libtbb-dev \
  libjpeg-dev \
  libpng-dev \
  libtiff-dev \
  libjasper-dev \
  libavformat-dev \
  libpq-dev && \
  wget --no-check-certificate -qO get-pip.py https://bootstrap.pypa.io/get-pip.py && \
  python get-pip.py && \
  pip install -U pip && \
  rm -rf /var/lib/apt/lists/*

ARG OPENCV_VERSION="2.4.13.5"
RUN wget --no-check-certificate -q https://github.com/opencv/opencv/archive/$OPENCV_VERSION.zip \
  && unzip -q $OPENCV_VERSION.zip \
  && mkdir /opencv \
  && mkdir /opencv-$OPENCV_VERSION/cmake_binary \
  && cd /opencv-$OPENCV_VERSION/cmake_binary \
  && cmake -DWITH_QT=OFF \
         -DWITH_OPENGL=ON \
         -DFORCE_VTK=OFF \
         -DWITH_TBB=ON \
         -DWITH_GDAL=ON \
         -DWITH_XINE=ON \
         -DBUILD_EXAMPLES=OFF \
         -DENABLE_PRECOMPILED_HEADERS=OFF .. \
  && make DESTDIR=/opencv install \
  && rm /$OPENCV_VERSION.zip \
  && rm -r /opencv-$OPENCV_VERSION

COPY requirements.txt /

RUN pip install --target=/dist-packages -r requirements.txt

FROM base

COPY --from=builder /opencv/usr /

RUN \
	apt-get update && \
	apt-get install -yqq --no-install-recommends \
	lsof \
	apt-transport-https \
	wget \
	unzip \
	tzdata \
	python-dev \
	libpcap-dev \
	tesseract-ocr \
	p7zip-full && \
	mkdir -p /root/Downloads && \
	ln -s /usr/bin/7za /usr/local/bin/7za && \
	rm -rf /var/lib/apt/lists/*

COPY --from=builder /dist-packages /usr/local/lib/python2.7/dist-packages
COPY --from=builder /usr/lib/jvm/default-java /usr/lib/jvm/default-java

ARG NODE_VERSION="10"
ARG NPM_VERSION="6"
RUN \
  echo "deb https://deb.nodesource.com/node_"$NODE_VERSION".x stretch main" > /etc/apt/sources.list.d/nodesource.list && \
  wget --no-check-certificate -qO nodesource.gpg https://deb.nodesource.com/gpgkey/nodesource.gpg.key && \
  apt-key add nodesource.gpg && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
  wget --no-check-certificate -qO pubkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg && \
  apt-key add pubkey.gpg && \
  apt-get update && \
  apt-get install -yqq nodejs yarn && \
  npm i -g npm@^$NPM_VERSION && \
  rm -rf /var/lib/apt/lists/*

ENV PYTHONIOENCODING utf-8
ENV ANDROID_HOME /android-sdk
ENV JAVA_HOME /usr/lib/jvm/default-java
ENV PATH $ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH

RUN \
  wget --no-check-certificate -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip \
  && unzip -q sdk-tools-linux-4333796.zip -d $ANDROID_HOME \
  && yes | sdkmanager --install 'build-tools;26.0.2' 'platform-tools' \
  && rm sdk-tools-linux-4333796.zip

ARG CHROME_VERSION="google-chrome-stable"
RUN wget --no-check-certificate -qO linux_signing_key https://dl-ssl.google.com/linux/linux_signing_key.pub && \
  apt-key add linux_signing_key && \
  echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
  apt-get update -qqy && \
  apt-get -qqy install ${CHROME_VERSION:-google-chrome-stable} && \
  rm /etc/apt/sources.list.d/google-chrome.list && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ARG CHROME_DRIVER_VERSION="latest"
RUN CD_VERSION=$(if [ ${CHROME_DRIVER_VERSION:-latest} = "latest" ]; then echo $(wget -qO- https://chromedriver.storage.googleapis.com/LATEST_RELEASE); else echo $CHROME_DRIVER_VERSION; fi) \
  && echo "Using chromedriver version: "$CD_VERSION \
  && wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CD_VERSION/chromedriver_linux64.zip \
  && rm -rf /opt/selenium/chromedriver \
  && unzip /tmp/chromedriver_linux64.zip -d /opt/selenium \
  && rm /tmp/chromedriver_linux64.zip \
  && mv /opt/selenium/chromedriver /opt/selenium/chromedriver-$CD_VERSION \
  && chmod 755 /opt/selenium/chromedriver-$CD_VERSION \
  && ln -fs /opt/selenium/chromedriver-$CD_VERSION /usr/bin/chromedriver

RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo 'Asia/Shanghai' >/etc/timezone

WORKDIR /scripts