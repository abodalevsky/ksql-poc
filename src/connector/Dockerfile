# Confluent connect worker with installed 
# JDBC connector (sink)
#
# Example how to configure HTTPS:
# https://github.com/confluentinc/cp-demo/blob/6.1.1-post/Dockerfile

FROM confluentinc/cp-kafka-connect-base:6.0.0

ENV CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components"

# Install JDBC Connector
# https://www.confluent.io/hub/confluentinc/kafka-connect-jdbc
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.1.1

# example of docker file
# https://github.com/confluentinc/cp-docker-images/issues/877#issuecomment-734737902
