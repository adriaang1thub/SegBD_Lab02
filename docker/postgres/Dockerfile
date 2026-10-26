FROM postgres:15
# pgaudit desde el repositorio oficial PGDG (ya configurado en la imagen)
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-15-pgaudit \
 && rm -rf /var/lib/apt/lists/*
COPY entry.sh /usr/local/bin/entry.sh
RUN chmod 755 /usr/local/bin/entry.sh
ENTRYPOINT ["entry.sh"]
CMD ["postgres"]
