FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Копирование .env.local если существует
COPY .env.local* ./

EXPOSE 3000

CMD ["npm", "run", "dev"]

