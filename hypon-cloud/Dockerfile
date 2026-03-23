ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache mosquitto-clients

# Copy data for add-on
COPY run.sh /
COPY scripts/ /scripts/

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]