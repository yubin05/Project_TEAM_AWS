import mysql from 'mysql2/promise';
import bcrypt from 'bcryptjs';

const dbConfig = {
  host:     process.env.DB_HOST,
  port:     Number(process.env.DB_PORT) || 3306,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: 'auth_db',
};

// 기존 auth_db.users(bcrypt 해시 비밀번호)에 있던 사용자가 Cognito로 처음 로그인/비밀번호
// 찾기를 시도할 때 호출됨. 검증에 성공하면 동일한 속성으로 Cognito 계정을 생성하도록 응답한다.
// (생성된 Cognito 계정의 sub은 옛 users.id와 다르므로, 데이터 재연결은 PostAuthentication에서 처리)
export const handler = async (event) => {
  const { triggerSource, userName, request } = event;
  const email = userName;

  const conn = await mysql.createConnection(dbConfig);
  try {
    const [rows] = await conn.execute(
      'SELECT email, password, name, role FROM users WHERE email = ?',
      [email]
    );
    const user = rows[0];
    if (!user) {
      throw new Error('User does not exist');
    }

    if (triggerSource === 'UserMigration_Authentication') {
      const valid = await bcrypt.compare(request.password, user.password);
      if (!valid) {
        throw new Error('Invalid credentials');
      }
    }
    // UserMigration_ForgotPassword: 비밀번호 검증 없이 계정 존재만 확인하고 마이그레이션
    // (이후 Cognito의 비밀번호 재설정 플로우로 새 비밀번호를 설정하게 됨)

    event.response.userAttributes = {
      email:          user.email,
      email_verified: 'true',
      name:           user.name,
      'custom:role':  user.role,
    };
    event.response.finalUserStatus = 'CONFIRMED';
    event.response.messageAction   = 'SUPPRESS';

    return event;
  } finally {
    await conn.end();
  }
};
