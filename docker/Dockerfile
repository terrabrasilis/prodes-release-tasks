from osgeo/gdal:ubuntu-small-3.6.3

LABEL "br.inpe.dpi"="INPE/DPI-TerraBrasilis" \
br.inpe.dpi.terrabrasilis="script-tasks" \
author="Andre Carvalho" \
author.email="andre.carvalho@inpe.br" \
description="Used to run external scripts from a mounted volume."
#-------------Application Specific Stuff ----------------------------------------------------

# remove the docker-clean content to avoid the apt-get error
RUN echo "" > /etc/apt/apt.conf.d/docker-clean \
    && apt-get -o Acquire::ForceIPv4=true update \
    && export DEBIAN_FRONTEND=noninteractive \
    &&  apt-get install -y \
    tzdata \
    zip \
    jq \
    grass-core \
    postgresql-client \
    python3-psycopg2 \
    python3-six \
    && ln -fs /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin

WORKDIR /scripts

CMD ["bash" "start.sh"]