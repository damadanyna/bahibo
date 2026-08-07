import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';

import { LoggingModule } from './common/logging/logging.module';
import { HealthModule } from './modules/health/health.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { ProductsModule } from './modules/products/products.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { PrismaModule } from './modules/prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { CartModule } from './modules/cart/cart.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { FeatureFlagsModule } from './modules/feature-flags/feature-flags.module';
import { OrdersModule } from './modules/orders/orders.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { PushNotificationsModule } from './modules/push-notifications/push-notifications.module';
import { SearchModule } from './modules/search/search.module';
import { ShipmentsModule } from './modules/shipments/shipments.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ScheduleModule.forRoot(),
    LoggingModule,
    HealthModule,
    PrismaModule,
    AuthModule,
    ProfilesModule,
    PushNotificationsModule,
    ConversationsModule,
    SearchModule,
    CategoriesModule,
    ProductsModule,
    NotificationsModule,
    FeatureFlagsModule,
    DashboardModule,
    CartModule,
    OrdersModule,
    ShipmentsModule,
  ],
})
export class AppModule {}
