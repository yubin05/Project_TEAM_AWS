import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import db from '../models/database';
import { Review, Booking } from '../types';
import logger from '../utils/logger';

export function createReview(req: Request, res: Response): void {
  try {
    const { hotel_id, booking_id, rating, title, content, images = [] } = req.body;
    const userId = req.user!.userId;

    if (!hotel_id || !booking_id || !rating || !title || !content) {
      res.status(400).json({ success: false, message: '필수 정보를 모두 입력해주세요.' });
      return;
    }

    if (rating < 1 || rating > 5) {
      res.status(400).json({ success: false, message: '평점은 1~5 사이여야 합니다.' });
      return;
    }

    const booking = db.prepare('SELECT * FROM bookings WHERE id = ? AND user_id = ? AND hotel_id = ?')
      .get(booking_id, userId, hotel_id) as Booking | undefined;

    if (!booking) {
      res.status(403).json({ success: false, message: '해당 예약에 대한 리뷰를 작성할 권한이 없습니다.' });
      return;
    }

    if (booking.status !== 'completed' && booking.status !== 'confirmed') {
      res.status(400).json({ success: false, message: '체크아웃 후 리뷰를 작성할 수 있습니다.' });
      return;
    }

    const existingReview = db.prepare('SELECT id FROM reviews WHERE booking_id = ?').get(booking_id);
    if (existingReview) {
      res.status(409).json({ success: false, message: '이미 리뷰를 작성했습니다.' });
      return;
    }

    const reviewId = uuidv4();
    db.prepare(`
      INSERT INTO reviews (id, user_id, hotel_id, booking_id, rating, title, content, images)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(reviewId, userId, hotel_id, booking_id, rating, title, content, JSON.stringify(images));

    // Update hotel rating
    const avgResult = db.prepare('SELECT AVG(rating) as avg_rating, COUNT(*) as count FROM reviews WHERE hotel_id = ?')
      .get(hotel_id) as { avg_rating: number; count: number };

    db.prepare('UPDATE hotels SET rating = ?, review_count = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(Math.round(avgResult.avg_rating * 10) / 10, avgResult.count, hotel_id);

    res.status(201).json({
      success: true,
      message: '리뷰가 등록되었습니다.',
      data: { id: reviewId }
    });
  } catch (error) {
    logger.error('Create review error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getHotelReviews(req: Request, res: Response): void {
  try {
    const { hotelId } = req.params;
    const { page = 1, limit = 10, sort_by = 'recent' } = req.query;

    let orderBy = 'r.created_at DESC';
    if (sort_by === 'rating_high') orderBy = 'r.rating DESC, r.created_at DESC';
    if (sort_by === 'rating_low') orderBy = 'r.rating ASC, r.created_at DESC';

    const reviews = db.prepare(`
      SELECT r.*, u.name as user_name, u.profile_image as user_avatar
      FROM reviews r JOIN users u ON r.user_id = u.id
      WHERE r.hotel_id = ?
      ORDER BY ${orderBy}
      LIMIT ? OFFSET ?
    `).all(hotelId, Number(limit), (Number(page) - 1) * Number(limit)) as (Review & { user_name: string; user_avatar: string })[];

    const stats = db.prepare(`
      SELECT
        COUNT(*) as total,
        AVG(rating) as average,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as five_star,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as four_star,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as three_star,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as two_star,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as one_star
      FROM reviews WHERE hotel_id = ?
    `).get(hotelId) as { total: number; average: number; five_star: number; four_star: number; three_star: number; two_star: number; one_star: number };

    res.json({
      success: true,
      data: {
        reviews: reviews.map(r => ({
          ...r,
          images: JSON.parse(r.images || '[]')
        })),
        stats: {
          ...stats,
          average: Math.round((stats.average || 0) * 10) / 10
        },
        pagination: {
          total: stats.total,
          page: Number(page),
          limit: Number(limit),
          total_pages: Math.ceil(stats.total / Number(limit))
        }
      }
    });
  } catch (error) {
    logger.error('Get reviews error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function deleteReview(req: Request, res: Response): void {
  try {
    const { id } = req.params;
    const userId = req.user!.userId;

    const review = db.prepare('SELECT * FROM reviews WHERE id = ?').get(id) as Review | undefined;
    if (!review) {
      res.status(404).json({ success: false, message: '리뷰를 찾을 수 없습니다.' });
      return;
    }

    if (review.user_id !== userId && req.user!.role !== 'admin') {
      res.status(403).json({ success: false, message: '권한이 없습니다.' });
      return;
    }

    db.prepare('DELETE FROM reviews WHERE id = ?').run(id);

    // Recalculate hotel rating
    const avgResult = db.prepare('SELECT AVG(rating) as avg_rating, COUNT(*) as count FROM reviews WHERE hotel_id = ?')
      .get(review.hotel_id) as { avg_rating: number; count: number };

    db.prepare('UPDATE hotels SET rating = ?, review_count = ? WHERE id = ?')
      .run(avgResult.avg_rating ? Math.round(avgResult.avg_rating * 10) / 10 : 0, avgResult.count, review.hotel_id);

    res.json({ success: true, message: '리뷰가 삭제되었습니다.' });
  } catch (error) {
    logger.error('Delete review error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function toggleWishlist(req: Request, res: Response): void {
  try {
    const { hotelId } = req.params;
    const userId = req.user!.userId;

    const existing = db.prepare('SELECT id FROM wishlists WHERE user_id = ? AND hotel_id = ?').get(userId, hotelId);

    if (existing) {
      db.prepare('DELETE FROM wishlists WHERE user_id = ? AND hotel_id = ?').run(userId, hotelId);
      res.json({ success: true, message: '위시리스트에서 제거되었습니다.', data: { wishlisted: false } });
    } else {
      const wishlistId = uuidv4();
      db.prepare('INSERT INTO wishlists (id, user_id, hotel_id) VALUES (?, ?, ?)').run(wishlistId, userId, hotelId);
      res.json({ success: true, message: '위시리스트에 추가되었습니다.', data: { wishlisted: true } });
    }
  } catch (error) {
    logger.error('Toggle wishlist error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getWishlist(req: Request, res: Response): void {
  try {
    const userId = req.user!.userId;

    const hotels = db.prepare(`
      SELECT h.*, MIN(r.price_per_night * (1 - r.discount_rate / 100)) as min_price
      FROM wishlists w
      JOIN hotels h ON w.hotel_id = h.id
      LEFT JOIN rooms r ON h.id = r.hotel_id AND r.is_available = 1
      WHERE w.user_id = ?
      GROUP BY h.id
      ORDER BY w.created_at DESC
    `).all(userId) as (any)[];

    res.json({
      success: true,
      data: hotels.map(h => ({
        ...h,
        amenities: JSON.parse(h.amenities || '[]'),
        images: JSON.parse(h.images || '[]'),
        is_active: Boolean(h.is_active)
      }))
    });
  } catch (error) {
    logger.error('Get wishlist error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
