FROM alpine:latest as downloader

RUN apk --no-cache add curl wget unzip
ENV ES_VERSION=14.1.0

RUN curl -sSL \
  https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-elasticsearch/versions/${ES_VERSION}/confluentinc-kafka-connect-elasticsearch-${ES_VERSION}.zip \
  -o /tmp/es.zip

RUN unzip /tmp/es.zip -d /tmp/elasticsearch

FROM confluentinc/cp-kafka-connect:7.6.1

USER root

# Create plugin directory
RUN mkdir -p /kafka/connect/plugins && \
    chown -R appuser:appuser /kafka/connect

USER appuser

# Install Confluent HTTP Sink via Confluent Hub
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-http:1.7.11

# Install Debezium MySQL manually (not available on Confluent Hub)
ENV DEBEZIUM_VERSION=3.3.1.Final

RUN curl -sSL https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.7.0.Final/debezium-connector-mysql-2.7.0.Final-plugin.tar.gz \
    | tar -xz -C /kafka/connect/plugins/

COPY --from=downloader --chown=appuser:appuser /tmp/elasticsearch /kafka/connect/plugins/elasticsearch

# Copy hub-installed connectors into plugin path
RUN cp -r /usr/share/confluent-hub-components/* /kafka/connect/plugins/

# Final permissions
RUN chown -R appuser:appuser /kafka/connect/plugins

