import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';

import { LoggingModule } from './common/logging/logging.module';
import { AuthThrottlerGuard } from './common/security/auth-throttler.guard';
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
    // Generous global ceiling per client IP; auth routes override it with
    // much tighter limits (see AuthController). Requires nginx to forward
    // X-Forwarded-For and `trust proxy` in main.ts, otherwise every client
    // is seen as 127.0.0.1.
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 300 }],
    }),
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
  providers: [{ provide: APP_GUARD, useClass: AuthThrottlerGuard }],
})
export class AppModule {}
