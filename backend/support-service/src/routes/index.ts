import { Router, Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import jwt from 'jsonwebtoken';
import pool from '../models/pool';
import { config } from '../config';

const router = Router();

function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const auth = req.headers['authorization'];
  if (!auth || !auth.startsWith('Bearer ')) {
    res.status(401).json({ success: false, message: '인증이 필요합니다.' });
    return;
  }
  try {
    const payload = jwt.verify(auth.slice(7), config.jwt.secret) as any;
    (req as any).user = payload;
    next();
  } catch {
    res.status(401).json({ success: false, message: '유효하지 않은 토큰입니다.' });
  }
}

function adminMiddleware(req: Request, res: Response, next: NextFunction): void {
  authMiddleware(req, res, () => {
    const user = (req as any).user;
    if (user?.role !== 'admin' && user?.role !== 'host') {
      res.status(403).json({ success: false, message: '권한이 없습니다.' });
      return;
    }
    next();
  });
}

// ── 문의 ───────────────────────────────────────────────────────────────────────

router.post('/inquiries', authMiddleware, async (req: Request, res: Response) => {
  const user = (req as any).user;
  const { type = 'general', title, content, booking_id } = req.body;

  if (!title?.trim() || !content?.trim()) {
    res.status(400).json({ success: false, message: '제목과 내용을 입력해주세요.' });
    return;
  }

  const id = uuidv4();
  await pool.execute(
    'INSERT INTO inquiries (id, user_id, user_email, type, title, content, booking_id) VALUES (?,?,?,?,?,?,?)',
    [id, user.id || user.userId, user.email, type, title.trim(), content.trim(), booking_id || null]
  );

  res.status(201).json({ success: true, message: '문의가 접수되었습니다.', data: { id } });
});

router.get('/inquiries', authMiddleware, async (req: Request, res: Response) => {
  const user = (req as any).user;
  const [rows] = await pool.execute(
    'SELECT id, type, title, content, status, answer, answered_at, created_at FROM inquiries WHERE user_id = ? ORDER BY created_at DESC',
    [user.id || user.userId]
  );
  res.json({ success: true, data: rows });
});

router.delete('/inquiries/:id', authMiddleware, async (req: Request, res: Response) => {
  const user = (req as any).user;
  const [rows]: any = await pool.execute(
    'SELECT id FROM inquiries WHERE id = ? AND user_id = ?',
    [req.params.id, user.id || user.userId]
  );
  if ((rows as any[]).length === 0) {
    res.status(404).json({ success: false, message: '문의를 찾을 수 없습니다.' });
    return;
  }
  await pool.execute('DELETE FROM inquiries WHERE id = ?', [req.params.id]);
  res.json({ success: true, message: '문의가 삭제되었습니다.' });
});

// ── 관리자 문의 관리 ─────────────────────────────────────────────────────────────

router.get('/admin/inquiries', adminMiddleware, async (_req: Request, res: Response) => {
  const [rows] = await pool.execute(
    'SELECT * FROM inquiries ORDER BY status ASC, created_at DESC'
  );
  res.json({ success: true, data: rows });
});

router.put('/admin/inquiries/:id/answer', adminMiddleware, async (req: Request, res: Response) => {
  const { answer } = req.body;
  if (!answer?.trim()) {
    res.status(400).json({ success: false, message: '답변 내용을 입력해주세요.' });
    return;
  }
  const [result]: any = await pool.execute(
    'UPDATE inquiries SET answer = ?, status = "answered", answered_at = NOW() WHERE id = ?',
    [answer.trim(), req.params.id]
  );
  if ((result as any).affectedRows === 0) {
    res.status(404).json({ success: false, message: '문의를 찾을 수 없습니다.' });
    return;
  }
  res.json({ success: true, message: '답변이 등록되었습니다.' });
});

// ── 공지사항 ──────────────────────────────────────────────────────────────────

router.get('/notices', async (_req: Request, res: Response) => {
  const [rows] = await pool.execute(
    'SELECT id, title, badge, is_pinned, created_at FROM notices ORDER BY is_pinned DESC, created_at DESC'
  );
  res.json({ success: true, data: rows });
});

export default router;
