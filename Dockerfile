ARG IMAGE=irishealth-community:2026.2.0AI.162.0
FROM $IMAGE

USER root
COPY --chown=51773:51773 objectscript/cls /home/irisowner/src/
COPY --chown=51773:51773 iris.script /home/irisowner/iris.script
USER irisowner

RUN iris start IRIS quietly && \
    iris session IRIS -U USER < /home/irisowner/iris.script && \
    iris stop IRIS quietly
