import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import db from '../models/database';
import { generateToken } from '../middleware/auth';
import { User } from '../types';

export async function register(req: Request, res: Response): Promise<void> {
  try {
    const { email, password, name, phone, role = 'user' } = req.body;

    if (!email || !password || !name) {
      res.status(400).json({ success: false, message: '이메일, 비밀번호, 이름은 필수입니다.' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ success: false, message: '비밀번호는 6자 이상이어야 합니다.' });
      return;
    }

    const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existingUser) {
      res.status(409).json({ success: false, message: '이미 사용 중인 이메일입니다.' });
      return;
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = uuidv4();

    db.prepare(`
      INSERT INTO users (id, email, password, name, phone, role)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(userId, email, hashedPassword, name, phone || null, role === 'host' ? 'host' : 'user');

    const token = generateToken({ userId, email, role });

    res.status(201).json({
      success: true,
      message: '회원가입이 완료되었습니다.',
      data: { token, user: { id: userId, email, name, role } }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ success: false, message: '이메일과 비밀번호를 입력해주세요.' });
      return;
    }

    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email) as User | undefined;
    if (!user) {
      res.status(401).json({ success: false, message: '이메일 또는 비밀번호가 잘못되었습니다.' });
      return;
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      res.status(401).json({ success: false, message: '이메일 또는 비밀번호가 잘못되었습니다.' });
      return;
    }

    const token = generateToken({ userId: user.id, email: user.email, role: user.role });

    res.json({
      success: true,
      message: '로그인 성공',
      data: {
        token,
        user: { id: user.id, email: user.email, name: user.name, role: user.role, profile_image: user.profile_image }
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getProfile(req: Request, res: Response): void {
  try {
    const user = db.prepare('SELECT id, email, name, phone, profile_image, role, created_at FROM users WHERE id = ?')
      .get(req.user!.userId) as Omit<User, 'password'> | undefined;

    if (!user) {
      res.status(404).json({ success: false, message: '사용자를 찾을 수 없습니다.' });
      return;
    }

    res.json({ success: true, data: user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function updateProfile(req: Request, res: Response): Promise<void> {
  try {
    const { name, phone } = req.body;
    const userId = req.user!.userId;

    db.prepare('UPDATE users SET name = ?, phone = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(name, phone, userId);

    res.json({ success: true, message: '프로필이 업데이트되었습니다.' });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function changePassword(req: Request, res: Response): Promise<void> {
  try {
    const { current_password, new_password } = req.body;
    const userId = req.user!.userId;

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as User | undefined;
    if (!user) {
      res.status(404).json({ success: false, message: '사용자를 찾을 수 없습니다.' });
      return;
    }

    const isValid = await bcrypt.compare(current_password, user.password);
    if (!isValid) {
      res.status(401).json({ success: false, message: '현재 비밀번호가 잘못되었습니다.' });
      return;
    }

    if (new_password.length < 6) {
      res.status(400).json({ success: false, message: '새 비밀번호는 6자 이상이어야 합니다.' });
      return;
    }

    const hashed = await bcrypt.hash(new_password, 10);
    db.prepare('UPDATE users SET password = ?, updated_at = datetime(\'now\') WHERE id = ?').run(hashed, userId);

    res.json({ success: true, message: '비밀번호가 변경되었습니다.' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
