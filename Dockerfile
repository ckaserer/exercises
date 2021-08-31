FROM node:alpine

WORKDIR /app

COPY ./package.json /app/package.json

RUN npm install

RUN apk update; apk add wget   

COPY README.md /app/README.md
COPY . /app

RUN sh -c 'nohup npm start &' \
    # && sleep 5 \
    && mkdir content/static \
    && cd content/static \
    && touch exercises.tgz \
    && wget -mkE localhost:8080; \
       mv localhost:8080 exercises \
    && rm exercises.tgz \
    && tar -czvf exercises.tgz exercises/* 

CMD ["/bin/sh", "-c", "npm start"]