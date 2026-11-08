import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';
import type { ParsedLink, StudyLevel } from '../scraper/opportunity-parser';

@Entity('opportunities')
export class Opportunity {
  @PrimaryGeneratedColumn()
  id!: number;

  @Index({ unique: true })
  @Column()
  fingerprint!: string;

  @Column()
  title!: string;

  @Column({ type: 'varchar', nullable: true })
  country!: string | null;

  /** ISO date (YYYY-MM-DD). */
  @Column({ type: 'varchar', nullable: true })
  deadline!: string | null;

  @Column({ type: 'text', nullable: true })
  deadlineText!: string | null;

  @Column({ type: 'simple-json' })
  levels!: StudyLevel[];

  @Column({ type: 'text' })
  summary!: string;

  @Column({ type: 'text' })
  description!: string;

  @Column({ type: 'simple-json' })
  emails!: string[];

  @Column({ type: 'simple-json' })
  links!: ParsedLink[];

  @Column()
  sourceUrl!: string;

  @Column()
  position!: number;

  @CreateDateColumn()
  firstSeenAt!: Date;

  @Column()
  lastSeenAt!: Date;

  /** Set when the listing disappears from the IPO page. */
  @Column({ type: 'datetime', nullable: true })
  removedAt!: Date | null;

  /** Set once the email alert has gone out; null means still pending. */
  @Column({ type: 'datetime', nullable: true })
  notifiedAt!: Date | null;
}
