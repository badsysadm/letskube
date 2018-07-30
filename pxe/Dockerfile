FROM debian
RUN apt-get update && apt-get install wget rsync cpio xorriso -y
COPY run.sh .
COPY preseed.final .
COPY extra/roles.sh .
#RUN ls -lah | grep roles
CMD ["/bin/bash", "run.sh"]
