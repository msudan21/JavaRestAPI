# Generated by IBM TransformationAdvisor
# Fri Jun 25 10:45:20 UTC 2021


FROM adoptopenjdk/openjdk8-openj9:latest AS build-stage

RUN apt-get update && \
    apt-get install -y maven unzip

COPY . /project
WORKDIR /project

#RUN mvn -X initialize process-resources verify => to get dependencies from maven
#RUN mvn clean package	
#RUN mvn --version
RUN mvn clean package

RUN mkdir -p /config/apps && \
    mkdir -p /sharedlibs && \
    cp ./src/main/liberty/config/server.xml /config && \
    cp ./target/*.*ar /config/apps/ && \
    if [ ! -z "$(ls ./src/main/liberty/lib)" ]; then \
        cp ./src/main/liberty/lib/* /sharedlibs; \
    fi

FROM openliberty/open-liberty:kernel-slim-java8-openj9-ubi

ARG TLS=true


RUN mkdir -p /opt/ol/wlp/usr/shared/config/lib/global
COPY --chown=1001:0 --from=build-stage /config/ /config/
COPY --chown=1001:0 --from=build-stage /sharedlibs/ /opt/ol/wlp/usr/shared/config/lib/global

# This script will add the requested XML snippets to enable Liberty features and grow image to be fit-for-purpose using featureUtility.
# Only available in 'kernel-slim'. The 'full' tag already includes all features for convenience.
RUN features.sh

# Add interim fixes (optional)
# COPY --chown=1001:0  interim-fixes /opt/ol/fixes/

# This script will add the requested server configurations, apply any interim fixes and populate caches to optimize runtime
RUN configure.sh

# Upgrade to production license if URL to JAR provided
ARG LICENSE_JAR_URL
RUN \
   if [ $LICENSE_JAR_URL ]; then \
     wget $LICENSE_JAR_URL -O /tmp/license.jar \
     && java -jar /tmp/license.jar -acceptLicense /opt/ibm \
     && rm /tmp/license.jar; \
   fi
