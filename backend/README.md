# Bahibo Backend

Backend NestJS pour l'application ecommerce Bahibo.

## Stack

- NestJS
- Prisma
- PostgreSQL
- Redis plus tard
- Cloudinary ou S3 plus tard

## Demarrage

```bash
cd backend
npm install
copy .env.example .env
npm run start:dev
```

## Endpoints de depart

- `GET /api/v1/health`
- `GET /api/v1/categories`
- `GET /api/v1/products`
- `GET /api/v1/products/:id`
- `GET /api/v1/notifications`

## Prochaines etapes

- Ajouter Redis pour cache et queues
- Ajouter payments et notifications push
- Ajouter Redis pour cache et queues

## Modules deja poses

- `health`
- `categories`
- `products`
- `notifications`
- `prisma`
- `auth`
- `cart`
- `orders`
- `shipments`
