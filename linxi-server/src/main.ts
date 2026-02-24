import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Set global prefix for all routes
  app.setGlobalPrefix('v1');

  // Use global validation pipe
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));
  
  // 强制监听 0.0.0.0 以支持 Docker 端口映射
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
