import mysql from 'mysql2/promise';

const dbConfig = {
  host:     process.env.DB_HOST,
  port:     Number(process.env.DB_PORT) || 3306,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
};

// 로그인이 최종 성공한 직후 호출됨 (이 시점에는 Cognito sub이 확정된 상태).
// UserMigration으로 막 생성된 계정이라면 옛 users.id(예: bcrypt 가입 당시 발급된 UUID)와
// 새 sub이 다르므로, users.id 및 연관 테이블의 user_id를 모두 새 sub으로 옮겨
// 예약/리뷰/위시리스트 데이터 연결이 끊기지 않도록 한다.
// 신규 가입자(처음부터 id = sub)는 대상이 없어 그대로 통과한다.
export const handler = async (event) => {
  const newSub = event.request.userAttributes.sub;
  const email  = event.request.userAttributes.email;

  const conn = await mysql.createConnection(dbConfig);
  try {
    const [rows] = await conn.execute(
      'SELECT id FROM auth_db.users WHERE email = ? AND id <> ? LIMIT 1',
      [email, newSub]
    );
    const oldUser = rows[0];
    if (!oldUser) {
      return event;
    }
    const oldId = oldUser.id;

    await conn.beginTransaction();
    try {
      await conn.execute('UPDATE auth_db.users      SET id      = ? WHERE id      = ?', [newSub, oldId]);
      await conn.execute('UPDATE booking_db.bookings  SET user_id = ? WHERE user_id = ?', [newSub, oldId]);
      await conn.execute('UPDATE review_db.reviews    SET user_id = ? WHERE user_id = ?', [newSub, oldId]);
      await conn.execute('UPDATE hotel_db.wishlists   SET user_id = ? WHERE user_id = ?', [newSub, oldId]);
      await conn.commit();
      console.log('User rekeyed to Cognito sub', { email, oldId, newSub });
    } catch (err) {
      await conn.rollback();
      console.error('Rekey failed, rolled back', { email, oldId, newSub, err });
      throw err;
    }

    return event;
  } finally {
    await conn.end();
  }
};
