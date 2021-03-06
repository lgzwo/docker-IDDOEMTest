FROM ubuntu:16.04 AS base

FROM base AS builder

COPY requirements.txt /requirements.txt

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends \
        python-dev \
        apt-transport-https \
        wget \
        libpcap-dev \
        tesseract-ocr \
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
        libpq-dev \
        openjdk-8-jre-headless \
        && rm -rf /var/lib/apt/lists/*


RUN wget --no-check-certificate -qO get-pip.py https://bootstrap.pypa.io/get-pip.py \
  && python get-pip.py \
  && pip install -U pip \
  && pip install --no-cache-dir --default-timeout=100 --target=/dist-packages -r requirements.txt

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

ENV ANDROID_HOME /android-sdk
ENV PATH $ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH

RUN \
  wget --no-check-certificate -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip \
  && unzip -q sdk-tools-linux-4333796.zip -d $ANDROID_HOME \
  && yes | sdkmanager --no_https --install 'build-tools;26.0.2' 'platform-tools' \
  && rm sdk-tools-linux-4333796.zip

ARG CHROME_DRIVER_VERSION="latest"
RUN CD_VERSION=$(if [ ${CHROME_DRIVER_VERSION:-latest} = "latest" ]; then echo $(wget -qO- https://chromedriver.storage.googleapis.com/LATEST_RELEASE); else echo $CHROME_DRIVER_VERSION; fi) \
  && echo "Using chromedriver version: "$CD_VERSION \
  && wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CD_VERSION/chromedriver_linux64.zip \
  && rm -rf /opt/selenium/chromedriver \
  && unzip /tmp/chromedriver_linux64.zip -d /opt/selenium \
  && rm /tmp/chromedriver_linux64.zip


FROM base

ENV PYTHONIOENCODING utf-8
ENV ANDROID_HOME /android-sdk
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH

COPY --from=builder /opencv/usr /
COPY --from=builder $ANDROID_HOME/platform-tools $ANDROID_HOME/platform-tools
COPY --from=builder $ANDROID_HOME/build-tools $ANDROID_HOME/build-tools
COPY --from=builder /opt/selenium/chromedriver /opt/selenium/chromedriver

RUN set -eux; \
  apt-get update \
  && apt-get install -yqq --no-install-recommends \
        lsof \
        wget \
	xz-utils \
        tzdata \
        openjdk-8-jre-headless \
        python \
        libpcap-dev \
        libjpeg-dev \
        tesseract-ocr \
        python-qt4 \
        gosu \
        p7zip-full \
        locales \
  && apt-get clean \
  && wget --no-check-certificate -q -O \
        /usr/share/tesseract-ocr/tessdata/chi_sim.traineddata \
        https://github.com/tesseract-ocr/tessdata/blob/3.04.00/chi_sim.traineddata \
  && ln -s /usr/bin/7za /usr/local/bin/7za \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /dist-packages /usr/local/lib/python2.7/dist-packages

ARG CHROME_VERSION="google-chrome-stable"
RUN wget --no-check-certificate -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub|apt-key add - \
  && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install ${CHROME_VERSION:-google-chrome-stable} \
  && rm /etc/apt/sources.list.d/google-chrome.list \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN chmod 755 /opt/selenium/chromedriver \
  && ln -fs /opt/selenium/chromedriver /usr/bin/chromedriver

RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo 'Asia/Shanghai' >/etc/timezone

# Set the locale
RUN sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG zh_CN.UTF-8
ENV LC_ALL zh_CN.UTF-8

RUN mkdir -p -m 0750 /data/share/.android
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY IDDOEMTest /scripts

RUN cd /tmp \
  && wget --progress=dot:mega --no-check-certificate \
     https://nodejs.org/dist/v6.11.2/node-v6.11.2-linux-x64.tar.xz \
  && tar -xJf node-v*.tar.xz --strip-components 1 -C /usr/local \
  && rm node-v*.tar.xz

WORKDIR /scripts

RUN npm i && npm run cp && npm cache clean && rm -rf ~/.node-gyp

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
