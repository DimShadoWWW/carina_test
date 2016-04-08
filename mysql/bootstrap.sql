FROM mysql:latest

COPY bootstrap.sql /docker-entrypoint-initdb.d/
