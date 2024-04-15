FROM ubuntu:22.04

RUN apt-get update && \
	apt-get install -q=2 -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" --no-install-recommends \
	ssh \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN adduser app --home /app --gecos ",,," --disabled-password --system --group

