import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { HealthModule } from './modules/health/health.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { ProductsModule } from './modules/products/products.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { PrismaModule } from './modules/prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { CartModule } from './modules/cart/cart.module';
import { OrdersModule } from './modules/orders/orders.module';
import { ShipmentsModule } from './modules/shipments/shipments.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    HealthModule,
    PrismaModule,
    AuthModule,
    CategoriesModule,
    ProductsModule,
    NotificationsModule,
    CartModule,
    OrdersModule,
    ShipmentsModule,
  ],
})
export class AppModule {}
