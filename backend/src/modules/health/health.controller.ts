import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return {
      success: true,
      service: 'BANAY-backend',
      status: 'up',
      timestamp: new Date().toISOString(),
    };
  }
}


