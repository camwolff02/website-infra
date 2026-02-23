FROM node:20-alpine

WORKDIR /app
RUN npm i -g serve

# Copy your static files (or your build output) into the image
COPY . .

EXPOSE 3000
CMD ["serve", "-s", ".", "-l", "3000"]
