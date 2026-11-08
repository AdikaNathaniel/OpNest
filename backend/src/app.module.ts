import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { Opportunity } from './opportunities/opportunity.entity';
import { OpportunitiesModule } from './opportunities/opportunities.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const database = config.get<string>(
          'DATABASE_PATH',
          'data/opnest.sqlite',
        );
        // SQLite won't create the folder for its database file.
        mkdirSync(dirname(database), { recursive: true });
        return {
          type: 'better-sqlite3',
          database,
          entities: [Opportunity],
          synchronize: true,
        };
      },
    }),
    OpportunitiesModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
