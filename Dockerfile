FROM node:6-alpine

WORKDIR /app

COPY ./package.json /app/package.json

RUN npm install

RUN apk update; apk add wget   

COPY . /app

ARG SOURCE=fundamentals 
RUN sh -c 'nohup npm start &' \
    && mkdir content/static \
    && cd content/static \
    && touch ${SOURCE}-exercises.tgz \
    && wget -mkE localhost:8080 \
    && mv localhost:8080 ${SOURCE}-exercises \
    && rm ${SOURCE}-exercises.tgz \
    && tar -czvf ${SOURCE}-exercises.tgz ${SOURCE}-exercises/* 

CMD ["/bin/sh", "-c", "npm start"]