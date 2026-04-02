import {
  OrderStatus,
  Prisma,
  PrismaClient,
  ShipmentStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('bahibo123', 10);

  const customer = await prisma.user.upsert({
    where: { phoneE164: '+261341234567' },
    update: {
      displayName: 'Client Demo',
      passwordHash,
      avatarUrl: 'https://i.pravatar.cc/240?img=15',
      isVerified: true,
      role: UserRole.CUSTOMER,
    },
    create: {
      phoneE164: '+261341234567',
      displayName: 'Client Demo',
      passwordHash,
      avatarUrl: 'https://i.pravatar.cc/240?img=15',
      isVerified: true,
      role: UserRole.CUSTOMER,
      cart: {
        create: {},
      },
    },
    include: {
      cart: true,
    },
  });

  const sellerUsers = await Promise.all([
    prisma.user.upsert({
      where: { phoneE164: '+261340000111' },
      update: {
        displayName: 'Jojol Store',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=18',
        isVerified: true,
        role: UserRole.SELLER,
      },
      create: {
        phoneE164: '+261340000111',
        displayName: 'Jojol Store',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=18',
        isVerified: true,
        role: UserRole.SELLER,
        cart: {
          create: {},
        },
      },
    }),
    prisma.user.upsert({
      where: { phoneE164: '+261340000222' },
      update: {
        displayName: 'Elanga Store',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=52',
        isVerified: true,
        role: UserRole.SELLER,
      },
      create: {
        phoneE164: '+261340000222',
        displayName: 'Elanga Store',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=52',
        isVerified: true,
        role: UserRole.SELLER,
        cart: {
          create: {},
        },
      },
    }),
    prisma.user.upsert({
      where: { phoneE164: '+261340000333' },
      update: {
        displayName: 'NalaK',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=47',
        isVerified: true,
        role: UserRole.SELLER,
      },
      create: {
        phoneE164: '+261340000333',
        displayName: 'NalaK',
        passwordHash,
        avatarUrl: 'https://i.pravatar.cc/240?img=47',
        isVerified: true,
        role: UserRole.SELLER,
        cart: {
          create: {},
        },
      },
    }),
  ]);

  const sellerProfiles = await Promise.all([
    prisma.sellerProfile.upsert({
      where: { userId: sellerUsers[0].id },
      update: {
        studioName: 'Jojol Store',
        description: 'Boutique high-tech et smartphones premium.',
        city: 'Antananarivo',
        country: 'Madagascar',
      },
      create: {
        userId: sellerUsers[0].id,
        studioName: 'Jojol Store',
        description: 'Boutique high-tech et smartphones premium.',
        city: 'Antananarivo',
        country: 'Madagascar',
      },
    }),
    prisma.sellerProfile.upsert({
      where: { userId: sellerUsers[1].id },
      update: {
        studioName: 'Elanga Store',
        description: 'Mode et accessoires soigneusement selectionnes.',
        city: 'Toamasina',
        country: 'Madagascar',
      },
      create: {
        userId: sellerUsers[1].id,
        studioName: 'Elanga Store',
        description: 'Mode et accessoires soigneusement selectionnes.',
        city: 'Toamasina',
        country: 'Madagascar',
      },
    }),
    prisma.sellerProfile.upsert({
      where: { userId: sellerUsers[2].id },
      update: {
        studioName: 'NalaK',
        description: 'Parfums, beaute et cadeaux premium.',
        city: 'Fianarantsoa',
        country: 'Madagascar',
      },
      create: {
        userId: sellerUsers[2].id,
        studioName: 'NalaK',
        description: 'Parfums, beaute et cadeaux premium.',
        city: 'Fianarantsoa',
        country: 'Madagascar',
      },
    }),
  ]);

  const categories = await Promise.all([
    prisma.category.upsert({
      where: { slug: 'smartphones' },
      update: { name: 'Smartphones', icon: '📱' },
      create: { slug: 'smartphones', name: 'Smartphones', icon: '📱' },
    }),
    prisma.category.upsert({
      where: { slug: 'fashion' },
      update: { name: 'Mode', icon: '👜' },
      create: { slug: 'fashion', name: 'Mode', icon: '👜' },
    }),
    prisma.category.upsert({
      where: { slug: 'beauty' },
      update: { name: 'Beaute', icon: '🌸' },
      create: { slug: 'beauty', name: 'Beaute', icon: '🌸' },
    }),
    prisma.category.upsert({
      where: { slug: 'home' },
      update: { name: 'Maison', icon: '🪑' },
      create: { slug: 'home', name: 'Maison', icon: '🪑' },
    }),
  ]);

  const products = await Promise.all([
    prisma.product.upsert({
      where: { id: 'prod-seed-iphone' },
      update: {
        title: 'iPhone 13 Pro Max',
        description: 'Smartphone premium avec excellent appareil photo.',
        imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800',
        priceAmount: new Prisma.Decimal('3150000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[0].id,
        categoryId: categories[0].id,
      },
      create: {
        id: 'prod-seed-iphone',
        title: 'iPhone 13 Pro Max',
        description: 'Smartphone premium avec excellent appareil photo.',
        imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800',
        priceAmount: new Prisma.Decimal('3150000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[0].id,
        categoryId: categories[0].id,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-seed-bag' },
      update: {
        title: 'Sac a main cuir premium',
        description: 'Mode feminine avec finition cuir elegante.',
        imageUrl: 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800',
        priceAmount: new Prisma.Decimal('280000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[1].id,
        categoryId: categories[1].id,
      },
      create: {
        id: 'prod-seed-bag',
        title: 'Sac a main cuir premium',
        description: 'Mode feminine avec finition cuir elegante.',
        imageUrl: 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800',
        priceAmount: new Prisma.Decimal('280000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[1].id,
        categoryId: categories[1].id,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-seed-perfume' },
      update: {
        title: 'Coffret parfum prestige',
        description: 'Selection premium pour cadeaux et occasions speciales.',
        imageUrl: 'https://images.unsplash.com/photo-1541643600914-78b084683601?w=800',
        priceAmount: new Prisma.Decimal('190000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[2].id,
        categoryId: categories[2].id,
      },
      create: {
        id: 'prod-seed-perfume',
        title: 'Coffret parfum prestige',
        description: 'Selection premium pour cadeaux et occasions speciales.',
        imageUrl: 'https://images.unsplash.com/photo-1541643600914-78b084683601?w=800',
        priceAmount: new Prisma.Decimal('190000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[2].id,
        categoryId: categories[2].id,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-seed-chair' },
      update: {
        title: 'Chaise design minimaliste',
        description: 'Assise confortable pour salon ou bureau moderne.',
        imageUrl: 'https://images.unsplash.com/photo-1519947486511-46149fa0a254?w=800',
        priceAmount: new Prisma.Decimal('145000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[1].id,
        categoryId: categories[3].id,
      },
      create: {
        id: 'prod-seed-chair',
        title: 'Chaise design minimaliste',
        description: 'Assise confortable pour salon ou bureau moderne.',
        imageUrl: 'https://images.unsplash.com/photo-1519947486511-46149fa0a254?w=800',
        priceAmount: new Prisma.Decimal('145000.00'),
        currencyCode: 'MGA',
        isAvailable: true,
        sellerProfileId: sellerProfiles[1].id,
        categoryId: categories[3].id,
      },
    }),
  ]);

  const cart = customer.cart ??
      (await prisma.cart.create({
        data: {
          userId: customer.id,
        },
      }));

  await prisma.cartItem.upsert({
    where: {
      cartId_productId: {
        cartId: cart.id,
        productId: products[1].id,
      },
    },
    update: {
      quantity: 1,
    },
    create: {
      cartId: cart.id,
      productId: products[1].id,
      quantity: 1,
    },
  });

  await prisma.order.upsert({
    where: { orderNumber: 'BHB-SEED-001' },
    update: {
      status: OrderStatus.DELIVERED,
      subtotalAmount: new Prisma.Decimal('190000.00'),
      deliveryAmount: new Prisma.Decimal('15000.00'),
      totalAmount: new Prisma.Decimal('205000.00'),
      buyerUserId: customer.id,
      sellerProfileId: sellerProfiles[2].id,
    },
    create: {
      orderNumber: 'BHB-SEED-001',
      status: OrderStatus.DELIVERED,
      subtotalAmount: new Prisma.Decimal('190000.00'),
      deliveryAmount: new Prisma.Decimal('15000.00'),
      totalAmount: new Prisma.Decimal('205000.00'),
      buyerUserId: customer.id,
      sellerProfileId: sellerProfiles[2].id,
      items: {
        create: [
          {
            productId: products[2].id,
            quantity: 1,
            unitPriceAmount: new Prisma.Decimal('190000.00'),
            totalPriceAmount: new Prisma.Decimal('190000.00'),
          },
        ],
      },
      shipment: {
        create: {
          carrierName: 'Bahibo Express',
          trackingNumber: 'BHB-TRACK-001',
          shipmentStatus: ShipmentStatus.DELIVERED,
          shippedAt: new Date('2026-04-01T10:00:00.000Z'),
          deliveredAt: new Date('2026-04-03T16:30:00.000Z'),
        },
      },
    },
  });
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });