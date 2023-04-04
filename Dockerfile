FROM python:3-alpine

USER root

#WORKDIR /code

# change to alpine edge repository in order to get netcdf-fortran to install right
RUN rm /etc/apk/repositories
RUN touch /etc/apk/repositories
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories


# install necessary programs/libraries
ARG REQUIRE="sudo bash build-base gcc g++ valgrind musl-dev linux-headers subversion gdal gdal-dev tcl tk imagemagick gfortran netcdf make unzip git cmake wget openjpeg perl libffi-dev libffi netcdf netcdf-fortran netcdf-fortran-dev"

RUN apk update && apk upgrade && apk add --no-cache ${REQUIRE}

# MPICH
# Build Options:
# See installation guide of target MPICH version
# Ex: http://www.mpich.org/static/downloads/3.2/mpich-3.2-installguide.pdf
# These options are passed to the steps below
# version 3.4+ fail with a make error
ARG MPICH_VERSION="3.2"
ARG MPICH_CONFIGURE_OPTIONS="FFLAGS=-fallow-argument-mismatch --enable-fast=all,O3 --enable-shared"
ARG MPICH_MAKE_OPTIONS="-j4"

# Download, build, and install MPICH
RUN mkdir /tmp/mpich-src
WORKDIR /tmp/mpich-src
RUN wget http://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz \
      && tar xfz mpich-${MPICH_VERSION}.tar.gz

WORKDIR /tmp/mpich-src/mpich-${MPICH_VERSION}
RUN ./configure ${MPICH_CONFIGURE_OPTIONS}
RUN make ${MPICH_MAKE_OPTIONS}
RUN make install
RUN rm -rf /tmp/mpich-src

ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"


#### TEST MPICH INSTALLATION ####
#RUN mkdir /tmp/mpich-test
#WORKDIR /tmp/mpich-test
#COPY mpich-test .
#RUN sh test.sh
#RUN rm -rf /tmp/mpich-test


#### CLEAN UP ####
WORKDIR /
#RUN rm -rf /tmp/*



# grib2
ARG GRIB2_VERSION="3.0.2"
ENV CC gcc
ENV FC gfortran

RUN mkdir /grib2
WORKDIR /grib2

RUN wget https://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz.v${GRIB2_VERSION} \
        && tar xfz wgrib2.tgz.v${GRIB2_VERSION} \
        && cd grib2/ \
        && make
RUN cp /grib2/grib2/wgrib2/wgrib2 /usr/bin



# eccodes
ARG ECCODES_VERSION="2.22.1"

RUN mkdir /eccodes
WORKDIR /eccodes
RUN wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-${ECCODES_VERSION}-Source.tar.gz
RUN tar xfz eccodes-${ECCODES_VERSION}-Source.tar.gz \
        && mkdir build \
        && cd build \
        && mkdir /usr/src/eccodes \
        && cmake -DCMAKE_INSTALL_PREFIX=/usr/src/eccodes -DENABLE_JPG=ON ../eccodes-${ECCODES_VERSION}-Source
WORKDIR /eccodes/build
RUN make
#RUN ctest
RUN make install
RUN cp -r /usr/src/eccodes/bin/* /usr/bin

ENV ECCODES_DIR /usr/src/eccodes
ENV ECCODES_DEFINITION_PATH /usr/src/eccodes/share/eccodes/definitions

RUN pip3 install eccodes
RUN python3 -m eccodes selfcheck



# hysplit
ENV HYSPLIT_VERSION="5.1.0"
ARG HYSPLIT_PASSWORD=

RUN mkdir /hysplit
WORKDIR /hysplit
RUN svn --username guest --password ${HYSPLIT_PASSWORD} export https://svn.arl.noaa.gov:8443/svn/hysplit/tags/hysplit.v${HYSPLIT_VERSION}
RUN cd hysplit.v${HYSPLIT_VERSION}
WORKDIR hysplit.v${HYSPLIT_VERSION}
RUN cp Makefile.inc.gfortran Makefile.inc

# add fortran flag
RUN sed -i 's/^\(FFLAGS=.*\)/\1 -std=legacy /g' Makefile.inc

# add C flag
RUN sed -i 's/^\(CFLAGS=.*\)/\1 -fcommon /g' Makefile.inc
RUN sed -i 's/\(\.\/configure\)/\1 CFLAGS=\"\$(CFLAGS)\" /g'  Makefile

RUN make
#RUN make install
#RUN rm -fr source_bulids/



