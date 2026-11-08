import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MailModule } from '../mail/mail.module';
import { ScraperService } from '../scraper/scraper.service';
import { OpportunitiesController } from './opportunities.controller';
import { OpportunitiesService } from './opportunities.service';
import { Opportunity } from './opportunity.entity';
import { SyncService } from './sync.service';

@Module({
  imports: [TypeOrmModule.forFeature([Opportunity]), MailModule],
  controllers: [OpportunitiesController],
  providers: [OpportunitiesService, SyncService, ScraperService],
})
export class OpportunitiesModule {}
