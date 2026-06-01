FROM alphaminetech/pearl-miner:1.7.5-beta

# Override entrypoint with restart wrapper + GPU keepalive
COPY wrapper.sh /usr/local/bin/wrapper.sh
RUN chmod +x /usr/local/bin/wrapper.sh

ENTRYPOINT ["/usr/local/bin/wrapper.sh"]
