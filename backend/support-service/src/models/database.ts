import pool from './pool';
import logger from '../utils/logger';

export async function initializeDatabase(): Promise<void> {
  const conn = await pool.getConnection();
  try {
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS inquiries (
        id          VARCHAR(36)  PRIMARY KEY,
        user_id     VARCHAR(36)  NOT NULL,
        user_email  VARCHAR(255) NOT NULL,
        type        ENUM('general','refund','change','complaint','etc') NOT NULL DEFAULT 'general',
        title       VARCHAR(200) NOT NULL,
        content     TEXT         NOT NULL,
        booking_id  VARCHAR(36),
        status      ENUM('pending','answered','closed') NOT NULL DEFAULT 'pending',
        answer      TEXT,
        answered_at DATETIME,
        created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id),
        INDEX idx_status (status)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await conn.execute(`
      CREATE TABLE IF NOT EXISTS notices (
        id         VARCHAR(36)  PRIMARY KEY,
        title      VARCHAR(200) NOT NULL,
        content    TEXT         NOT NULL,
        badge      VARCHAR(20)  NOT NULL DEFAULT '공지',
        is_pinned  TINYINT(1)   NOT NULL DEFAULT 0,
        created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    const [rows]: any = await conn.execute('SELECT COUNT(*) AS cnt FROM notices');
    if (rows[0].cnt === 0) {
      const { v4: uuidv4 } = require('uuid');
      await conn.execute(
        'INSERT INTO notices (id, title, content, badge, is_pinned) VALUES (?,?,?,?,?)',
        [uuidv4(), 'Sponge Trip 서비스 오픈 안내', 'Sponge Trip 서비스가 정식 오픈했습니다. 이용해주셔서 감사합니다.', '공지', 1]
      );
      await conn.execute(
        'INSERT INTO notices (id, title, content, badge) VALUES (?,?,?,?)',
        [uuidv4(), '정기 서버 점검 안내 (매주 화요일 새벽 2~4시)', '서비스 안정화를 위해 매주 화요일 새벽 2시~4시 정기 점검을 진행합니다.', '점검']
      );
      await conn.execute(
        'INSERT INTO notices (id, title, content, badge) VALUES (?,?,?,?)',
        [uuidv4(), '여름 성수기 특가 프로모션 안내', '6~8월 여름 성수기 특가 프로모션을 진행합니다. 다양한 혜택을 누려보세요.', '이벤트']
      );
    }

    logger.info('support_db initialized');
  } finally {
    conn.release();
  }
}
