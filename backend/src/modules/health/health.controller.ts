import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return {
      success: true,
      service: 'bahibo-backend',
      status: 'up',
      timestamp: new Date().toISOString(),
    };
  }
}
