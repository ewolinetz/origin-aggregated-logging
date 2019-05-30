FROM rhscl/nodejs-10-rhel7 AS builder

ENV KIBANA_VERSION=6.8.0 \
    KIBANA_DOWNLOAD_URI=https://artifacts.elastic.co/downloads/kibana/

RUN KIBANA_PACKAGE=kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz && \
    curl -s ${KIBANA_DOWNLOAD_URI}${KIBANA_PACKAGE} -o /tmp/${KIBANA_PACKAGE} && \
    tar -C /tmp -xzf /tmp/${KIBANA_PACKAGE} --exclude 'node'

FROM rhscl/nodejs-10-rhel7

MAINTAINER OpenShift Development <dev@lists.openshift.redhat.com>

EXPOSE 5601

ENV ELASTICSEARCH_URL=https://elasticsearch:9200 \
    HOME=/opt/app-root/src  \
    KIBANA_CONF_DIR=${HOME}/config \
    KIBANA_VERSION=6.8.0 \
    NODE_ENV=production \
    RELEASE_STREAM=prod \
    container=oci \
    NODE_ENV=production


ARG LOCAL_REPO

USER 0

COPY --from=builder /tmp/kibana-${KIBANA_VERSION}-linux-x86_64/* ${HOME}/
ADD probe/ /usr/share/kibana/probe/
ADD kibana.yml ${KIBANA_CONF_DIR}/
ADD run.sh utils ${HOME}/
RUN bin/kibana --optimize

WORKDIR ${HOME}
CMD ["./run.sh"]

LABEL \
        io.k8s.description="Kibana container for querying Elasticsearch for aggregated logs" \
        com.redhat.component="logging-kibana6-container" \
        vendor="Red Hat" \
        name="openshift4/ose-logging-kibana6" \
        License="GPLv2+" \
        io.k8s.display-name="Kibana" \
        version="v4.2.0" \
        architecture="x86_64" \
        release="0.0.0.1" \
        io.openshift.expose-services="5601:http" \
        io.openshift.tags="logging,elk,kibana"
