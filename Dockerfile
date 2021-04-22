# This image is mainly used for development and testing

FROM python:3.9 as base

RUN apt-get update && apt-get install -y build-essential libde265-dev

RUN git clone https://github.com/strukturag/libheif.git libheif \
    && cd libheif \
    && ./autogen.sh \
    && ./configure \
    && make -j4 \
    && make install \
    && ldconfig

WORKDIR /app
# explicit requirements because runtime does not need ALL dependencies
COPY requirements-pip.txt .
COPY requirements.txt .
RUN pip3 install -r requirements-pip.txt
RUN pip3 install -r requirements.txt

FROM base as common
RUN apt-get update && apt-get install -y dos2unix
RUN mkdir Photos
COPY requirements*.txt ./
COPY scripts/install_deps scripts/install_deps
RUN dos2unix scripts/install_deps
RUN scripts/install_deps
COPY . .
RUN dos2unix scripts/*
ENV TZ="America/Los_Angeles"

FROM common as test

RUN scripts/test
RUN scripts/lint

FROM common as build

RUN scripts/build

FROM python:3.9-alpine as runtime

RUN apk add --no-cache libffi-dev libheif-dev libde265-dev build-base zlib-dev jpeg-dev

COPY --from=build /app/dist/* /tmp
RUN pip3 install /tmp/*.whl

# copy from test to ensure test stage runs before runtime stage in buildx
COPY --from=test /app/.coverage .
