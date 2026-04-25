FROM node:20-slim

# Instalăm utilitare pentru SQLite
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiem fișierele de dependințe
COPY package*.json ./

# Instalăm dependințele
RUN npm install

# Copiem restul codului
COPY . .

# Expunem portul pe care rulează serverul tău
EXPOSE 8080

# Pornim aplicația
CMD ["npm", "run", "dev"]